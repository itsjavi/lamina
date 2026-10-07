import Foundation
import LaminaAutomation

/// `--help` text, made from the command catalog so it lists every command and parameter there is.
public enum Help {
    public static var overview: String {
        let width = (CommandCatalog.commands.map(\.name.count).max() ?? 0) + 2
        let commands = CommandCatalog.commands.map { "  " + $0.name.padding(toLength: width, withPad: " ", startingAt: 0) + $0.summary }
        return """
        lamina: control the running \(AppIdentity.displayName) app from the command line.

        Usage: lamina <command> [options]
               lamina help <command>    (or lamina <command> --help)

        Commands:
        \(commands.joined(separator: "\n"))
          \("mcp".padding(toLength: width, withPad: " ", startingAt: 0))Serve these commands as MCP tools over stdin and stdout (lamina help mcp).

        Options for every command:
          --json             Print the result (or the error) as JSON.
          --dev              Talk to \(AppIdentity.displayName) Dev (\(AppIdentity.devBundleID)).
          --app <bundle-id>  Talk to the app with this bundle id.
          --pid <pid>        Talk to this process, when several copies of the app are running.
          --timeout <secs>   How long to wait for the app's answer (default 300).
          -h, --help         Show help.
          --version          Show lamina's version.

        Environment:
          LAMINA_APP         A bundle id, or dev or release: the app to talk to when no option says.
                             Without either, lamina talks to the app it ships in, else \(AppIdentity.releaseBundleID).

        The app has to be running. lamina sends it Apple Events, so the first command asks macOS's permission for
        the app you run lamina from (Terminal, your editor or agent) to control \(AppIdentity.displayName); it's
        listed, and can be turned off, in System Settings › Privacy & Security › Automation.

        Ids are short unique prefixes from list-documents; longer prefixes and full ids work too. Commands that
        change a document are one undo step each, and are refused while someone is in the middle of an edit in the
        app (typing text, a transform, an open dialog).

        Exit status: 0 done, 1 the app refused or the command failed, 2 bad usage, 3 couldn't reach the app.
        """
    }

    public static var mcp: String {
        let tools = CommandCatalog.commands.map { "  \($0.toolName)" }.joined(separator: "\n")
        return """
        lamina mcp: serve lamina's commands as Model Context Protocol tools over stdin and stdout.

        Usage: lamina mcp [--dev | --app <bundle-id> | --pid <pid>] [--timeout <secs>]

        An MCP host (Claude Code, Codex, Claude's desktop app…) starts it; it isn't meant to be run by hand. Register it:
          claude mcp add lamina -- \(installedPath) mcp
          codex mcp add lamina -- \(installedPath) mcp

        Tools, one per command (lamina help <command> describes each):
        \(tools)

        Protocol: MCP \(MCPServer.modernVersions.joined(separator: ", ")) (stateless, server/discover), and
        \(MCPServer.legacyVersions.joined(separator: ", ")) for hosts that still open with initialize.
        stdout carries only MCP messages; lamina logs to stderr. The app has to be running when a tool is called.
        """
    }

    /// Where the release app keeps lamina, for examples.
    static let installedPath = "/Applications/\(AppIdentity.displayName).app/Contents/Helpers/lamina"

    public static func command(_ spec: CommandSpec) -> String {
        let usage = spec.parameters.map { parameter in
            let flag = parameter.flag + (isFlag(parameter) ? "" : " <\(placeholder(parameter))>")
            return parameter.isRequired ? flag : "[\(flag)]"
        }
        let width = (spec.parameters.map { $0.flag.count + placeholder($0).count + 3 }.max() ?? 0) + 2
        let options = spec.parameters.map { parameter -> String in
            let label = (parameter.flag + (isFlag(parameter) ? "" : " <\(placeholder(parameter))>"))
                .padding(toLength: width, withPad: " ", startingAt: 0)
            var notes: [String] = []
            if parameter.isRequired { notes.append("required") }
            switch parameter.type {
            case .integer, .number, .choice: notes.append(parameter.typeDescription)
            default: break
            }
            if let fallback = parameter.defaultValue { notes.append("default \(describe(fallback))") }
            var line = "  \(label)\(parameter.summary)"
            if !notes.isEmpty { line += " (\(notes.joined(separator: "; ")))" }
            if case .settings = parameter.type {
                line += "\n  " + String(repeating: " ", count: width)
                    + "Written as JSON ('{\"radius\": 4}') or key=value pairs ('radius=4,gaussian=true')."
            }
            return line
        }
        let fields: [String]
        if case .object(let list) = spec.result {
            fields = list.map { "  \($0.name): \($0.summary)" }
        } else {
            fields = []
        }
        var text = "lamina \(spec.name): \(spec.summary)\n\nUsage: lamina \(spec.name) \(usage.joined(separator: " "))\n"
        if !spec.details.isEmpty { text += "\n\(spec.details)\n" }
        text += "\nOptions:\n\(options.joined(separator: "\n"))\n"
        if !fields.isEmpty { text += "\nResult (as JSON with --json):\n\(fields.joined(separator: "\n"))\n" }
        text += "\nAlso --json, --dev, --app, --pid and --timeout; see lamina --help.\n"
        return text
    }

    static func isFlag(_ parameter: ParameterSpec) -> Bool {
        if case .boolean = parameter.type { return true }
        return false
    }

    static func placeholder(_ parameter: ParameterSpec) -> String {
        switch parameter.type {
        case .id: "id"
        case .integer, .number: "n"
        case .choice: parameter.name
        case .color: "#rrggbb"
        case .settings: "settings"
        case .path: "file"
        case .string, .boolean: "text"
        }
    }

    static func describe(_ value: JSONValue) -> String {
        switch value {
        case .number(let number): number.rounded() == number && abs(number) < 1e15 ? String(Int(number)) : String(number)
        case .string(let text): text
        case .bool(let flag): flag ? "true" : "false"
        default: value.encodedString()
        }
    }
}
