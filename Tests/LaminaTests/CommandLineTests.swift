import Foundation
import Testing
import LaminaAutomation
@testable import LaminaCLI

/// Records requests and answers them with a canned reply, standing in for the running app.
final class StubTransport: CommandTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [JSONValue] = []
    let answer: @Sendable (JSONValue) -> JSONValue

    init(answer: @escaping @Sendable (JSONValue) -> JSONValue) { self.answer = answer }

    var requests: [JSONValue] { lock.withLock { sent } }

    func send(_ request: JSONValue) throws -> JSONValue {
        lock.withLock { sent.append(request) }
        return answer(request)
    }
}

/// Collects what `lamina` prints.
final class Captured: @unchecked Sendable {
    private let lock = NSLock()
    private var out = "", err = ""
    var standardOutput: String { lock.withLock { out } }
    var standardError: String { lock.withLock { err } }
    var console: Lamina.Console {
        Lamina.Console(standardOutput: { text in self.lock.withLock { self.out += text + "\n" } },
                       standardError: { text in self.lock.withLock { self.err += text + "\n" } })
    }
}

struct CommandLineTests {
    @Test func flagsBecomeTheCommandsJSONArguments() throws {
        let invocation = try Invocation.parse(["apply-filter", "--json", "--document", "3F2A", "--layer=9c1b", "--kind", "add-noise",
                                               "--settings", "amount=20,gaussian=true", "--settings", #"{"monochromatic": true}"#, "--dev"])
        #expect(invocation.json && invocation.dev)
        #expect(invocation.action == .run(command: "apply-filter", arguments: [
            "document": "3F2A", "layer": "9c1b", "kind": "add-noise",
            "settings": ["amount": 20, "gaussian": true, "monochromatic": true],
        ]))
        let preview = try Invocation.parse(["--pid", "42", "render-preview", "--document", "3f2a", "--max-size", "512", "--timeout", "5"])
        #expect(preview.pid == 42 && preview.timeout == 5)
        #expect(preview.action == .run(command: "render-preview", arguments: ["document": "3f2a", "max_size": 512]))
        let select = try Invocation.parse(["select-layer", "--document", "3f2a", "--layer", "9c1b", "--mask"])
        #expect(select.action == .run(command: "select-layer", arguments: ["document": "3f2a", "layer": "9c1b", "mask": true]))
        let unmask = try Invocation.parse(["select-layer", "--no-mask", "--document", "3f2a", "--layer", "9c1b"])
        #expect(unmask.action == .run(command: "select-layer", arguments: ["document": "3f2a", "layer": "9c1b", "mask": false]))
        // Negative numbers are values, not flags.
        let lens = try Invocation.parse(["export-document", "--document", "3f2a", "--quality", "0.5", "--output", "-dash.jpg"])
        #expect(lens.action == .run(command: "export-document", arguments: ["document": "3f2a", "quality": 0.5, "output": "-dash.jpg"]))
    }

    @Test func helpAndMistakes() throws {
        #expect(try Invocation.parse([]).action == .help(command: nil))
        #expect(try Invocation.parse(["--help"]).action == .help(command: nil))
        #expect(try Invocation.parse(["help", "undo"]).action == .help(command: "undo"))
        #expect(try Invocation.parse(["undo", "-h"]).action == .help(command: "undo"))
        #expect(try Invocation.parse(["--version"]).action == .version)
        let mcp = try Invocation.parse(["mcp", "--dev", "--timeout", "60"])
        #expect(mcp.action == .mcp && mcp.dev && mcp.timeout == 60)
        #expect(try Invocation.parse(["mcp", "--help"]).action == .help(command: "mcp"))
        #expect(throws: AutomationError.self) { try Invocation.parse(["mcp", "--layer", "x"]) }
        #expect(Help.overview.contains("mcp") && Help.mcp.contains("claude mcp add lamina"))
        #expect(throws: AutomationError.self) { try Invocation.parse(["frobnicate"]) }
        #expect(throws: AutomationError.self) { try Invocation.parse(["undo", "--layer", "x"]) }
        #expect(throws: AutomationError.self) { try Invocation.parse(["undo", "--document"]) }
        #expect(throws: AutomationError.self) { try Invocation.parse(["render-preview", "--document", "3f2a", "--max-size", "big"]) }
        #expect(throws: AutomationError.self) { try Invocation.parse(["undo", "stray"]) }
    }

    @Test func helpDocumentsEveryCommandAndParameter() {
        let overview = Help.overview
        for spec in CommandCatalog.commands {
            #expect(overview.contains(spec.name))
            let text = Help.command(spec)
            for parameter in spec.parameters { #expect(text.contains(parameter.flag), "\(spec.name) documents \(parameter.flag)") }
            for kind in spec.kinds {
                #expect(text.contains(kind.name + ":"))
                for setting in kind.settings { #expect(text.contains(setting.name), "\(spec.name) documents \(kind.name).\(setting.name)") }
            }
        }
    }

    @Test func badArgumentsNeverReachTheApp() throws {
        let stub = StubTransport { _ in AutomationMessage.reply(.success([:])) }
        let client = CommandClient(transport: stub)
        let filter = try #require(CommandCatalog.command("apply-filter"))
        #expect(throws: AutomationError.self) {
            try client.run(filter, ["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": ["radius": 0]])
        }
        #expect(throws: AutomationError.self) { try client.run(filter, ["document": "3f2a", "kind": "gaussian-blur"]) }
        #expect(stub.requests.isEmpty)
    }

    @Test func exportsAreWrittenByLaminaNotTheApp() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
        let stub = StubTransport { request in
            let format = request["arguments"]?["format"]?.stringValue ?? "?"
            return AutomationMessage.reply(.success(["document": "3f2a9c1b", "format": .string(format), "width": 4, "height": 2,
                                                     "bytes": JSONValue(png.count), "data": .string(png.base64EncodedString())]))
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let client = CommandClient(transport: stub, directory: folder)
        let export = try #require(CommandCatalog.command("export-document"))

        let output = try client.run(export, ["document": "3f2a", "output": "out.jpg"])
        let sent = try #require(stub.requests.last)
        #expect(sent["command"] == "export-document")
        #expect(sent["arguments"]?["output"] == nil, "the path stays with lamina")
        #expect(sent["arguments"]?["format"] == "jpeg", "the format follows the extension")
        let path = folder.appendingPathComponent("out.jpg").standardizedFileURL.path
        #expect(output.result["path"]?.stringValue == path)
        #expect(output.result["data"] == nil)
        #expect(output.file?.mimeType == "image/jpeg")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == png)
        #expect(export.result.violations(of: output.result).isEmpty)

        _ = try client.run(export, ["document": "3f2a", "output": "out.bin", "format": "png"])
        #expect(stub.requests.last?["arguments"]?["format"] == "png")
    }

    @Test func printsTextOrJSONAndExitsWithTheRightStatus() throws {
        let stub = StubTransport { request in
            switch request["command"]?.stringValue {
            case "list-documents":
                return AutomationMessage.reply(.success(["documents": [[
                    "id": "3f2a9c1b", "title": "Poster", "path": nil, "front": true, "modified": false, "revision": "a1b2c3d4",
                    "width": 1200, "height": 800, "active_layer": "9c1b2d3e",
                    "layers": [["id": "9c1b2d3e", "name": "Photo", "type": "pixels", "visible": true, "parent": nil, "depth": 0]],
                ]]]))
            default:
                return AutomationMessage.reply(.failure(AutomationError(.busy, "Text is being edited.")))
            }
        }
        let text = Captured()
        #expect(Lamina.run(["list-documents"], console: text.console, transport: { _ in stub }) == Lamina.succeeded)
        #expect(text.standardOutput.contains("3f2a9c1b  Poster  1200×800  front"))
        #expect(text.standardOutput.contains("9c1b2d3e  Photo  (pixels, selected)"))

        let json = Captured()
        #expect(Lamina.run(["list-documents", "--json"], console: json.console, transport: { _ in stub }) == Lamina.succeeded)
        #expect(try JSONValue.decode(json.standardOutput)["documents"]?.arrayValue?.count == 1)

        let refused = Captured()
        #expect(Lamina.run(["undo", "--document", "3f2a"], console: refused.console, transport: { _ in stub }) == Lamina.failed)
        #expect(refused.standardError == "lamina: Text is being edited.\n")
        let refusedJSON = Captured()
        #expect(Lamina.run(["undo", "--document", "3f2a", "--json"], console: refusedJSON.console, transport: { _ in stub }) == Lamina.failed)
        #expect(try JSONValue.decode(refusedJSON.standardOutput)["error"]?["code"] == "busy")

        let usage = Captured()
        #expect(Lamina.run(["undo"], console: usage.console, transport: { _ in stub }) == Lamina.usage)
        #expect(Lamina.run(["--help"], console: usage.console) == Lamina.succeeded)
    }

    @Test func targetsTheRightApp() {
        let none: [String: String] = [:]
        #expect(AppTarget.resolve(pid: 7, app: "x", dev: true, environment: none, executable: nil) == .processID(7))
        #expect(AppTarget.resolve(pid: nil, app: "x.y", dev: true, environment: none, executable: nil) == .bundleID("x.y"))
        #expect(AppTarget.resolve(pid: nil, app: nil, dev: true, environment: ["LAMINA_APP": "release"], executable: nil) == .bundleID(AppIdentity.devBundleID))
        #expect(AppTarget.resolve(pid: nil, app: nil, dev: false, environment: ["LAMINA_APP": "dev"], executable: nil) == .bundleID(AppIdentity.devBundleID))
        #expect(AppTarget.resolve(pid: nil, app: nil, dev: false, environment: none, executable: URL(fileURLWithPath: "/usr/local/bin/lamina"))
            == .bundleID(AppIdentity.releaseBundleID))
    }
}
