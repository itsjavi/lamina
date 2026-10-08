import Foundation
import LaminaAutomation

/// `lamina mcp`: a Model Context Protocol server over stdio whose tools are the command catalog (`MCPTools`), run
/// through the same `CommandClient` as the command line.
///
/// It speaks MCP 2026-07-28, which is stateless: each request carries its protocol version and the client's
/// capabilities in `_meta`, results say who answered (`serverInfo` in `_meta`) and carry `resultType`, and
/// `server/discover` describes the server. Hosts still on 2025-11-25 or earlier open with `initialize` instead and
/// get that era's results (no `resultType`, `ttlMs` or `cacheScope`). Logging goes only to stderr.
public final class MCPServer: @unchecked Sendable {
    /// Versions served statelessly, per request.
    public static let modernVersions = ["2026-07-28"]
    /// Versions served after an `initialize` handshake.
    public static let legacyVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
    /// How long clients may cache the tool list and discovery: it only changes with lamina itself.
    static let cacheMilliseconds = 3_600_000

    let client: CommandClient
    let serverInfo: JSONValue
    let progressInterval: TimeInterval
    let log: @Sendable (String) -> Void
    private let lock = NSLock()
    private var cancelled: Set<JSONValue> = []

    public init(client: CommandClient, version: String, progressInterval: TimeInterval = 2,
                log: @escaping @Sendable (String) -> Void) {
        self.client = client
        self.serverInfo = ["name": "lamina", "title": .string("\(AppIdentity.displayName) (lamina)"), "version": .string(version)]
        self.progressInterval = progressInterval
        self.log = log
    }

    // MARK: stdio

    /// Reads newline-delimited JSON-RPC messages from `input` until it closes, writing replies to `output`, one per
    /// line. Tool calls run alongside each other, so a long export doesn't hold up a listing or a cancellation.
    public func serve(input: FileHandle, output: FileHandle) {
        let writer = LineWriter(output)
        let calls = DispatchGroup()
        let queue = DispatchQueue(label: "lamina.mcp.calls", attributes: .concurrent)
        var buffer = Data()
        func dispatch(_ line: Data) {
            guard !line.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }) else { return }
            let message = try? JSONValue.decode(line)
            if message?["method"] == "tools/call", message?["id"] != nil {
                calls.enter()
                queue.async { self.receive(line, send: writer.write); calls.leave() }
            } else {
                receive(line, send: writer.write)
            }
        }
        while true {
            let chunk = input.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                dispatch(buffer[buffer.startIndex..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
        if !buffer.isEmpty { dispatch(buffer) }
        calls.wait()
    }

    // MARK: Messages

    /// Handles one message, calling `send` for each message to write back: progress notifications while a tool runs,
    /// then the response. Returns when it's answered.
    public func receive(_ line: Data, send: @escaping @Sendable (JSONValue) -> Void) {
        guard let message = try? JSONValue.decode(line) else {
            send(Self.error(id: .null, code: -32700, message: "Parse error: not JSON."))
            return
        }
        handle(message, send: send)
    }

    public func handle(_ message: JSONValue, send: @escaping @Sendable (JSONValue) -> Void) {
        guard case .object(let object) = message, object["jsonrpc"] == "2.0" else {
            send(Self.error(id: message["id"] ?? .null, code: -32600, message: "Invalid Request: not a JSON-RPC 2.0 message."))
            return
        }
        // Responses from the client would answer requests; this server sends none.
        guard let method = object["method"]?.stringValue else { return }
        let params = object["params"]?.objectValue ?? [:]
        guard let id = object["id"], id.stringValue != nil || id.doubleValue != nil else {
            notification(method, params)
            return
        }
        let started = Date()
        do {
            let era = try self.era(of: params, method: method)
            let result = try respond(to: method, params: params, era: era, id: id, send: send)
            if lock.withLock({ cancelled.remove(id) != nil }) { return }
            send(["jsonrpc": "2.0", "id": id, "result": result])
            let failure = result["isError"] == true ? ": " + (result["content"]?[0]?["text"]?.stringValue ?? "failed") : ""
            log("\(method)\(Self.toolName(params)) (\(era)) in \(String(format: "%.1f", Date().timeIntervalSince(started))) s\(failure)")
        } catch let error as RPCError {
            send(Self.error(id: id, code: error.code, message: error.message, data: error.data))
            log("\(method)\(Self.toolName(params)): \(error.message)")
        } catch {
            send(Self.error(id: id, code: -32603, message: "Internal error: \(error.localizedDescription)"))
        }
    }

    /// How a request is served: stateless with its version (2026-07-28 on), or as the legacy session `initialize`
    /// opened (requests without the modern `_meta`).
    enum Era: CustomStringConvertible {
        case modern(String)
        case legacy
        var description: String {
            switch self {
            case .modern(let version): version
            case .legacy: "legacy session"
            }
        }
    }

    func era(of params: [String: JSONValue], method: String) throws -> Era {
        if method == "initialize" { return .legacy }
        if let version = params["_meta"]?["io.modelcontextprotocol/protocolVersion"]?.stringValue {
            guard Self.modernVersions.contains(version) else {
                throw RPCError(code: -32022, message: "Unsupported protocol version \(version).",
                               data: ["supported": .array(Self.modernVersions.map { .string($0) }), "requested": .string(version)])
            }
            return .modern(version)
        }
        if method == "server/discover" {
            throw RPCError(code: -32602, message: "server/discover needs _meta[\"io.modelcontextprotocol/protocolVersion\"].")
        }
        return .legacy
    }

    func respond(to method: String, params: [String: JSONValue], era: Era, id: JSONValue,
                 send: @escaping @Sendable (JSONValue) -> Void) throws -> JSONValue {
        switch method {
        case "initialize":
            let requested = params["protocolVersion"]?.stringValue ?? ""
            return [
                "protocolVersion": .string(Self.legacyVersions.contains(requested) ? requested : Self.legacyVersions[0]),
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": serverInfo,
                "instructions": .string(MCPTools.instructions),
            ]
        case "server/discover":
            return finish([
                "supportedVersions": .array(Self.modernVersions.map { .string($0) }),
                "capabilities": ["tools": ["listChanged": false]],
                "instructions": .string(MCPTools.instructions),
            ], era, cacheable: true)
        case "tools/list":
            return finish(["tools": .array(MCPTools.all)], era, cacheable: true)
        case "tools/call":
            return try call(params, era: era, id: id, send: send)
        case "ping":
            return finish([:], era)
        default:
            throw RPCError(code: -32601, message: "Method not found: \(method).")
        }
    }

    /// A tool call: the command's result as `structuredContent` (and as JSON text), a preview's image as an image
    /// block, and a command that fails — refused, invalid arguments, the app not running — as an `isError` result the
    /// model can read.
    func call(_ params: [String: JSONValue], era: Era, id: JSONValue, send: @escaping @Sendable (JSONValue) -> Void) throws -> JSONValue {
        let name = params["name"]?.stringValue ?? ""
        guard let spec = CommandCatalog.commands.first(where: { $0.toolName == name }) else {
            throw RPCError(code: -32602, message: "Unknown tool: \(name).")
        }
        guard let arguments = (params["arguments"] ?? [:]).objectValue else {
            throw RPCError(code: -32602, message: "The arguments of \(name) must be an object.")
        }
        let outcome: Result<CommandClient.Output, AutomationError> = withProgress(params["_meta"]?["progressToken"], spec, send) {
            do {
                if let fileOutput = spec.fileOutput, let path = arguments[fileOutput.parameter]?.stringValue,
                   !path.hasPrefix("/"), !path.hasPrefix("~") {
                    throw AutomationError.invalid("\(fileOutput.parameter) must be an absolute path.")
                }
                return .success(try client.run(spec, arguments))
            } catch let error as AutomationError {
                return .failure(error)
            } catch {
                return .failure(AutomationError(.failed, error.localizedDescription))
            }
        }
        switch outcome {
        case .success(let output):
            var content: [JSONValue] = [["type": "text", "text": .string(output.result.encodedString())]]
            if spec.fileOutput?.showsImage == true, let file = output.file {
                content.append(["type": "image", "data": .string(file.data.base64EncodedString()), "mimeType": .string(file.mimeType)])
            }
            return finish(["content": .array(content), "structuredContent": output.result, "isError": false], era)
        case .failure(let error):
            return finish(["content": [["type": "text", "text": .string("\(error.message) [\(error.code.rawValue)]")]], "isError": true], era)
        }
    }

    /// Runs `body`, sending `notifications/progress` while it waits when the request asked for them: one at the
    /// start, one every `progressInterval` seconds, and a last one with the total when it's done. The app answers
    /// each command in one piece, so the steps count seconds waited, not work done.
    func withProgress<T>(_ token: JSONValue?, _ spec: CommandSpec, _ send: @escaping @Sendable (JSONValue) -> Void, _ body: () -> T) -> T {
        guard let token, token.stringValue != nil || token.doubleValue != nil else { return body() }
        let state = ProgressState()
        func notify(_ progress: Int, total: Int? = nil, _ message: String) {
            var params: [String: JSONValue] = ["progressToken": token, "progress": JSONValue(progress), "message": .string(message)]
            if let total { params["total"] = JSONValue(total) }
            send(["jsonrpc": "2.0", "method": "notifications/progress", "params": .object(params)])
        }
        notify(0, "Sent \(spec.name) to \(AppIdentity.displayName).")
        // Ticks happen under the lock and stop once `finished` is set, so none arrives after the last notification
        // (or the response that follows it).
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + progressInterval, repeating: progressInterval)
        let interval = progressInterval
        timer.setEventHandler {
            state.lock.withLock {
                guard !state.finished else { return }
                state.ticks += 1
                let seconds = Int((Double(state.ticks) * interval).rounded())
                send(["jsonrpc": "2.0", "method": "notifications/progress", "params": [
                    "progressToken": token, "progress": JSONValue(state.ticks),
                    "message": .string("Waiting for \(AppIdentity.displayName) to finish \(spec.name) (\(seconds) s)."),
                ]])
            }
        }
        timer.resume()
        let result = body()
        let done = state.lock.withLock { () -> Int in
            state.finished = true
            return state.ticks + 1
        }
        timer.cancel()
        notify(done, total: done, "Done.")
        return result
    }

    private final class ProgressState: @unchecked Sendable {
        let lock = NSLock()
        var ticks = 0
        var finished = false
    }

    func notification(_ method: String, _ params: [String: JSONValue]) {
        switch method {
        case "notifications/cancelled":
            // The app can't stop a command midway; the reply is dropped instead, as the spec asks.
            if let id = params["requestId"] { lock.withLock { _ = cancelled.insert(id) } }
        default:
            break // notifications/initialized and anything else need no answer.
        }
    }

    /// Adds what every 2026-07-28 result carries: `resultType`, who answered, and for cacheable results how long
    /// they stay fresh. Legacy results stay as that era had them.
    func finish(_ body: [String: JSONValue], _ era: Era, cacheable: Bool = false) -> JSONValue {
        guard case .modern = era else { return .object(body) }
        var result = body
        result["resultType"] = "complete"
        result["_meta"] = ["io.modelcontextprotocol/serverInfo": serverInfo]
        if cacheable {
            result["ttlMs"] = JSONValue(Self.cacheMilliseconds)
            result["cacheScope"] = "public"
        }
        return .object(result)
    }

    struct RPCError: Error {
        let code: Int
        let message: String
        var data: JSONValue? = nil
    }

    static func error(id: JSONValue, code: Int, message: String, data: JSONValue? = nil) -> JSONValue {
        var error: [String: JSONValue] = ["code": JSONValue(code), "message": .string(message)]
        if let data { error["data"] = data }
        return ["jsonrpc": "2.0", "id": id, "error": .object(error)]
    }

    static func toolName(_ params: [String: JSONValue]) -> String {
        params["name"]?.stringValue.map { " \($0)" } ?? ""
    }
}

/// Writes whole messages, one per line, from any thread.
final class LineWriter: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    init(_ handle: FileHandle) { self.handle = handle }

    func write(_ message: JSONValue) {
        var data = message.encoded()
        data.append(0x0A)
        // A host that went away (EPIPE) just ends the conversation; the read loop sees the input close.
        lock.withLock { try? handle.write(contentsOf: data) }
    }
}
