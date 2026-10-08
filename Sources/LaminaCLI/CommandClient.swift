import Foundation
import LaminaAutomation

/// The client half of a command, shared by the command line and the MCP server: checks the arguments against the
/// catalog, sends what the app needs, and handles what the sandboxed app can't — writing files.
public struct CommandClient: Sendable {
    public let transport: CommandTransport
    /// Relative output paths are resolved against this folder.
    public let directory: URL

    public init(transport: CommandTransport, directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.transport = transport
        self.directory = directory
    }

    public struct Output: Sendable {
        /// The result, as the catalog describes it (`path` in place of the file's bytes).
        public var result: JSONValue
        /// The bytes of a file the command produced, and their type.
        public var file: (data: Data, mimeType: String)?
    }

    public func run(_ spec: CommandSpec, _ arguments: [String: JSONValue]) throws -> Output {
        var arguments = try spec.validate(arguments).values
        // Export picks its format from the file's extension unless told.
        if spec.fileOutput != nil, spec.parameter("format") != nil, arguments["format"] == nil {
            let ext = arguments["output"]?.stringValue.map { URL(fileURLWithPath: $0).pathExtension.lowercased() }
            arguments["format"] = ext == "jpg" || ext == "jpeg" ? "jpeg" : "png"
        }
        let sent = arguments.filter { name, _ in spec.parameter(name)?.isClientSide == false }
        let reply = try transport.send(AutomationMessage.request(command: spec.name, arguments: .object(sent)))
        var result = try AutomationMessage.outcome(of: reply).get()
        guard let fileOutput = spec.fileOutput, case .object(var object) = result else { return Output(result: result) }
        guard let encoded = object.removeValue(forKey: "data")?.stringValue, let data = Data(base64Encoded: encoded) else {
            throw AutomationError(.failed, "The app's reply has no image data.")
        }
        let format = object["format"]?.stringValue ?? "png"
        let mimeType = fileOutput.mimeTypes[format] ?? "application/octet-stream"
        if let path = arguments[fileOutput.parameter]?.stringValue {
            let expanded = (path as NSString).expandingTildeInPath
            let url = (expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : directory.appendingPathComponent(expanded)).standardizedFileURL
            do { try data.write(to: url, options: .atomic) }
            catch { throw AutomationError(.failed, "Couldn't write \(url.path): \(error.localizedDescription)") }
            object["path"] = .string(url.path)
        }
        result = .object(object)
        return Output(result: result, file: (data, mimeType))
    }
}
