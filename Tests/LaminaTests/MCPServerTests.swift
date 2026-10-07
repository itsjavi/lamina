import Foundation
import Testing
import LaminaAutomation
@testable import LaminaCLI

/// The MCP server against a stub of the app: what `lamina` would send over Apple Events gets canned replies.
struct MCPServerTests {
    static let modern: JSONValue = [
        "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": [:],
        "io.modelcontextprotocol/clientInfo": ["name": "test", "version": "1"],
    ]

    /// Answers like the app: documents for list-documents, a PNG for render-preview, a busy refusal for the rest.
    static func app() -> StubTransport {
        StubTransport { request in
            switch request["command"]?.stringValue {
            case "list-documents":
                return AutomationMessage.reply(.success(["documents": []]))
            case "render-preview":
                return AutomationMessage.reply(.success(["document": "3f2a9c1b", "width": 2, "height": 1, "source_width": 2,
                                                         "source_height": 1, "bytes": 3, "data": .string(Data([1, 2, 3]).base64EncodedString())]))
            default:
                return AutomationMessage.reply(.failure(AutomationError(.busy, "Text is being edited.")))
            }
        }
    }

    final class Outbox: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [JSONValue] = []
        var messages: [JSONValue] { lock.withLock { items } }
        var send: @Sendable (JSONValue) -> Void { { message in self.lock.withLock { self.items.append(message) } } }
    }

    func exchange(_ server: MCPServer, _ request: JSONValue) -> [JSONValue] {
        let outbox = Outbox()
        server.handle(request, send: outbox.send)
        return outbox.messages
    }

    func request(_ id: Int, _ method: String, _ params: [String: JSONValue] = [:], meta: JSONValue? = modern) -> JSONValue {
        var params = params
        if let meta { params["_meta"] = meta }
        return ["jsonrpc": "2.0", "id": JSONValue(id), "method": .string(method), "params": .object(params)]
    }

    func server(_ transport: StubTransport = app()) -> MCPServer {
        MCPServer(client: CommandClient(transport: transport), version: "9.9", progressInterval: 0.1, log: { _ in })
    }

    @Test func discoverDescribesTheServer() throws {
        let reply = try #require(exchange(server(), request(1, "server/discover")).first)
        #expect(reply["id"] == 1)
        let result = try #require(reply["result"])
        #expect(result["resultType"] == "complete")
        #expect(result["supportedVersions"] == ["2026-07-28"])
        #expect(result["capabilities"]?["tools"] != nil)
        #expect(result["_meta"]?["io.modelcontextprotocol/serverInfo"]?["name"] == "lamina")
        #expect(result["_meta"]?["io.modelcontextprotocol/serverInfo"]?["version"] == "9.9")
        #expect(result["ttlMs"]?.intValue ?? 0 > 0 && result["cacheScope"] == "public")
        #expect((result["instructions"]?.stringValue?.count ?? 0) < 2048, "hosts may cut instructions at 2,048 characters")
    }

    @Test func everyCommandIsAToolInCatalogOrder() throws {
        let result = try #require(exchange(server(), request(2, "tools/list"))[0]["result"])
        #expect(result["resultType"] == "complete" && result["ttlMs"] != nil && result["cacheScope"] == "public")
        let tools = try #require(result["tools"]?.arrayValue)
        #expect(tools.map { $0["name"]?.stringValue } == CommandCatalog.commands.map(\.toolName))
        for (tool, spec) in zip(tools, CommandCatalog.commands) {
            #expect(tool["inputSchema"]?["type"] == "object" && tool["inputSchema"]?["$schema"] == "https://json-schema.org/draft/2020-12/schema")
            #expect(tool["outputSchema"]?["type"] == "object" && tool["outputSchema"]?["$schema"] == "https://json-schema.org/draft/2020-12/schema")
            #expect(tool["inputSchema"] == spec.inputSchema, "\(spec.name)'s input schema comes from the catalog")
            #expect(tool["description"]?.stringValue?.hasPrefix(spec.summary) == true)
            #expect(tool["annotations"]?["readOnlyHint"] == .bool(spec.isReadOnly && spec.fileOutput == nil))
        }
        func hints(_ name: String) -> JSONValue? { tools.first { $0["name"]?.stringValue == name }?["annotations"] }
        #expect(hints("list_documents")?["readOnlyHint"] == true && hints("describe_document")?["readOnlyHint"] == true)
        #expect(hints("export_document")?["readOnlyHint"] == false && hints("export_document")?["destructiveHint"] == true)
        #expect(hints("add_adjustment_layer")?["destructiveHint"] == false && hints("apply_filter")?["destructiveHint"] == true)
        #expect(tools.allSatisfy { $0["annotations"]?["openWorldHint"] == false })
        // The same list every time.
        #expect(exchange(server(), request(3, "tools/list"))[0]["result"]?["tools"] == result["tools"])
    }

    @Test func toolsReturnStructuredContentAndImages() throws {
        let transport = Self.app()
        let listed = try #require(exchange(server(transport), request(4, "tools/call", ["name": "list_documents", "arguments": [:]]))[0]["result"])
        #expect(listed["isError"] == false && listed["structuredContent"] == ["documents": []])
        #expect(listed["content"]?[0]?["type"] == "text")
        #expect(try JSONValue.decode(listed["content"]?.arrayValue?.first?["text"]?.stringValue ?? "") == ["documents": []])
        #expect(listed["resultType"] == "complete" && listed["_meta"]?["io.modelcontextprotocol/serverInfo"] != nil)
        #expect(transport.requests.last?["arguments"] == ["layers": true])

        let preview = try #require(exchange(server(transport), request(5, "tools/call", ["name": "render_preview", "arguments": ["document": "3f2a"]]))[0]["result"])
        let blocks = try #require(preview["content"]?.arrayValue)
        #expect(blocks.count == 2 && blocks[1]["type"] == "image" && blocks[1]["mimeType"] == "image/png")
        #expect(blocks[1]["data"]?.stringValue == Data([1, 2, 3]).base64EncodedString())
        #expect(preview["structuredContent"]?["data"] == nil, "bytes travel as the image, not in the structured result")
        let spec = try #require(CommandCatalog.command("render-preview"))
        #expect(spec.result.violations(of: try #require(preview["structuredContent"])).isEmpty)
    }

    @Test func failuresAreToolErrorsTheModelCanRead() throws {
        let transport = Self.app()
        let refused = try #require(exchange(server(transport), request(6, "tools/call", ["name": "undo", "arguments": ["document": "3f2a"]]))[0]["result"])
        #expect(refused["isError"] == true && refused["structuredContent"] == nil)
        #expect(refused["content"]?[0]?["text"] == "Text is being edited. [busy]")
        let count = transport.requests.count
        let invalid = try #require(exchange(server(transport), request(7, "tools/call", ["name": "apply_filter",
            "arguments": ["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": ["radius": 900]]]))[0]["result"])
        #expect(invalid["isError"] == true && invalid["content"]?[0]?["text"]?.stringValue?.contains("settings.radius") == true)
        let relative = try #require(exchange(server(transport), request(8, "tools/call", ["name": "export_document",
            "arguments": ["document": "3f2a", "output": "out.png"]]))[0]["result"])
        #expect(relative["isError"] == true && relative["content"]?[0]?["text"]?.stringValue?.contains("absolute") == true)
        #expect(transport.requests.count == count, "invalid calls never reach the app")
        // An unknown tool is a protocol error.
        let unknown = exchange(server(transport), request(9, "tools/call", ["name": "paint", "arguments": [:]]))[0]
        #expect(unknown["error"]?["code"] == -32602)
    }

    @Test func protocolVersionsAndErrors() throws {
        let unsupported = exchange(server(), request(10, "tools/list", meta: ["io.modelcontextprotocol/protocolVersion": "2099-01-01",
                                                                              "io.modelcontextprotocol/clientCapabilities": [:]]))[0]
        #expect(unsupported["error"]?["code"] == -32022)
        #expect(unsupported["error"]?["data"] == ["supported": ["2026-07-28"], "requested": "2099-01-01"])
        #expect(exchange(server(), request(11, "server/discover", meta: nil))[0]["error"]?["code"] == -32602)
        #expect(exchange(server(), request(12, "resources/list"))[0]["error"]?["code"] == -32601)
        let outbox = Outbox()
        server().receive(Data("{not json".utf8), send: outbox.send)
        #expect(outbox.messages.first?["error"]?["code"] == -32700 && outbox.messages.first?["id"] == .null)
        #expect(exchange(server(), ["jsonrpc": "1.0", "id": 1, "method": "ping"])[0]["error"]?["code"] == -32600)
        #expect(exchange(server(), ["jsonrpc": "2.0", "method": "notifications/initialized"]).isEmpty, "notifications get no reply")
    }

    @Test func hostsOnTheInitializeHandshakeStillConnect() throws {
        let legacy = server()
        let initialize = try #require(exchange(legacy, request(1, "initialize", [
            "protocolVersion": "2025-06-18", "capabilities": [:], "clientInfo": ["name": "codex", "version": "0.160.0"],
        ], meta: nil))[0]["result"])
        #expect(initialize["protocolVersion"] == "2025-06-18")
        #expect(initialize["serverInfo"]?["name"] == "lamina" && initialize["capabilities"]?["tools"] != nil)
        #expect(initialize["instructions"]?.stringValue?.isEmpty == false)
        let unknownVersion = try #require(exchange(legacy, request(2, "initialize", ["protocolVersion": "2024-01-01"], meta: nil))[0]["result"])
        #expect(unknownVersion["protocolVersion"] == "2025-11-25")
        #expect(exchange(legacy, ["jsonrpc": "2.0", "method": "notifications/initialized"]).isEmpty)
        let tools = try #require(exchange(legacy, request(3, "tools/list", meta: nil))[0]["result"])
        #expect(tools["tools"]?.arrayValue?.count == CommandCatalog.commands.count)
        #expect(tools["resultType"] == nil && tools["ttlMs"] == nil && tools["_meta"] == nil, "no 2026-07-28 fields for a 2025 host")
        #expect(exchange(legacy, request(4, "ping", meta: nil))[0]["result"] == [:])
        let call = try #require(exchange(legacy, request(5, "tools/call", ["name": "list_documents"], meta: nil))[0]["result"])
        #expect(call["structuredContent"] == ["documents": []] && call["resultType"] == nil)
    }

    @Test func longCallsReportProgressAndCancelledOnesGetNoReply() throws {
        var params: [String: JSONValue] = ["name": "describe_document", "arguments": ["document": "3f2a"]]
        var meta = try #require(Self.modern.objectValue)
        meta["progressToken"] = "p1"
        params["_meta"] = .object(meta)
        // The app answers only once a progress tick has gone out, however slow the machine.
        let ticked = DispatchSemaphore(value: 0)
        let slowApp = StubTransport { _ in
            _ = ticked.wait(timeout: .now() + 10)
            return AutomationMessage.reply(.failure(AutomationError(.notFound, "No open document has the id 3f2a.")))
        }
        let outbox = Outbox()
        server(slowApp).handle(["jsonrpc": "2.0", "id": 20, "method": "tools/call", "params": .object(params)]) { message in
            outbox.send(message)
            if message["params"]?["progress"] == 1, message["params"]?["total"] == nil { ticked.signal() }
        }
        let messages = outbox.messages
        let progress = messages.filter { $0["method"] == "notifications/progress" }
        #expect(progress.count >= 3, "a start, at least one tick while waiting, and the end: \(progress.count)")
        #expect(progress.allSatisfy { $0["params"]?["progressToken"] == "p1" })
        let steps = progress.compactMap { $0["params"]?["progress"]?.intValue }
        #expect(steps == steps.sorted() && Set(steps).count == steps.count, "progress only increases: \(steps)")
        #expect(progress.last?["params"]?["total"] == progress.last?["params"]?["progress"])
        #expect(messages.last?["id"] == 20 && messages.last?["result"]?["isError"] == true, "the reply comes last")

        // The app answers only after the cancellation arrived; the answer is then dropped.
        let cancelledYet = DispatchSemaphore(value: 0)
        let cancelled = server(StubTransport { _ in
            _ = cancelledYet.wait(timeout: .now() + 10)
            return AutomationMessage.reply(.success(["documents": []]))
        })
        let dropped = Outbox()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            cancelled.handle(self.request(21, "tools/call", ["name": "list_documents", "arguments": [:]]), send: dropped.send)
            done.signal()
        }
        cancelled.handle(["jsonrpc": "2.0", "method": "notifications/cancelled", "params": ["requestId": 21]], send: dropped.send)
        cancelledYet.signal()
        done.wait()
        #expect(dropped.messages.isEmpty)
    }

    /// The whole exchange over pipes, as a host runs it: one JSON message per line in, one per line out, and nothing
    /// else on stdout.
    @Test func servesOverStdio() throws {
        let input = Pipe(), output = Pipe()
        let server = server()
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            server.serve(input: input.fileHandleForReading, output: output.fileHandleForWriting)
            try? output.fileHandleForWriting.close()
            finished.signal()
        }
        let lines = [
            request(1, "server/discover"),
            request(2, "tools/list"),
            request(3, "tools/call", ["name": "list_documents", "arguments": ["layers": false]]),
            request(4, "tools/call", ["name": "undo", "arguments": ["document": "3f2a"]]),
        ].map { $0.encodedString() + "\n" }.joined()
        input.fileHandleForWriting.write(Data(lines.utf8))
        try input.fileHandleForWriting.close()
        #expect(finished.wait(timeout: .now() + 10) == .success, "the server exits when its input closes")
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let replies = try text.split(separator: "\n").map { try JSONValue.decode(String($0)) }
        #expect(replies.count == 4)
        #expect(Set(replies.compactMap { $0["id"]?.intValue }) == [1, 2, 3, 4])
        #expect(replies.allSatisfy { $0["jsonrpc"] == "2.0" && $0["result"]?["resultType"] == "complete" })
        let undo = try #require(replies.first { $0["id"] == 4 })
        #expect(undo["result"]?["isError"] == true)
    }
}
