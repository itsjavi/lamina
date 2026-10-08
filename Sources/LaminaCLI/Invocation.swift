import Foundation
import LaminaAutomation

/// A parsed command line: `lamina [options] <command> [--flag value…]`. Each command's flags come from its
/// parameters in the catalog (`max_size` is `--max-size`); the global options may go anywhere.
public struct Invocation: Equatable {
    public enum Action: Equatable {
        case help(command: String?)
        case version
        case run(command: String, arguments: [String: JSONValue])
        /// `lamina mcp`: serve the commands as MCP tools over stdin and stdout.
        case mcp
    }

    public var action: Action
    public var json = false
    public var dev = false
    public var app: String?
    public var pid: pid_t?
    public var timeout: TimeInterval = 300

    static let globalFlags = ["--json", "--dev", "--app", "--pid", "--timeout", "--help", "-h", "--version"]

    /// Parses `arguments` (without the program name).
    public static func parse(_ arguments: [String]) throws -> Invocation {
        var invocation = Invocation(action: .help(command: nil))
        var command: String?
        var helpRequested = false
        var raw: [(flag: String, value: String?)] = []
        var index = 0
        func value(for flag: String, inline: String?) throws -> String {
            if let inline { return inline }
            index += 1
            guard index < arguments.count else { throw AutomationError.invalid("\(flag) needs a value.") }
            return arguments[index]
        }
        while index < arguments.count {
            let argument = arguments[index]
            let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
            let flag = argument.hasPrefix("-") ? parts[0] : argument
            let inline = argument.hasPrefix("-") && parts.count > 1 ? parts[1] : nil
            switch flag {
            case "--json": invocation.json = true
            case "--dev": invocation.dev = true
            case "--help", "-h": helpRequested = true
            case "--version": invocation.action = .version; return invocation
            case "--app": invocation.app = try value(for: flag, inline: inline)
            case "--pid":
                let text = try value(for: flag, inline: inline)
                guard let pid = pid_t(text), pid > 0 else { throw AutomationError.invalid("--pid takes a process id.") }
                invocation.pid = pid
            case "--timeout":
                let text = try value(for: flag, inline: inline)
                guard let seconds = TimeInterval(text), seconds > 0 else { throw AutomationError.invalid("--timeout takes seconds.") }
                invocation.timeout = seconds
            default:
                if argument.hasPrefix("-") {
                    guard let name = command, let spec = CommandCatalog.command(name) else {
                        throw AutomationError.invalid("Unknown option \(flag)" + (command == nil ? "; name a command first." : "."))
                    }
                    let negated = flag.hasPrefix("--no-") ? "--" + flag.dropFirst(5) : nil
                    if let negated, let parameter = spec.parameters.first(where: { $0.flag == negated }), case .boolean = parameter.type {
                        raw.append((negated, "false"))
                    } else if let parameter = spec.parameters.first(where: { $0.flag == flag }) {
                        if case .boolean = parameter.type { raw.append((flag, inline ?? "true")) }
                        else { raw.append((flag, try value(for: flag, inline: inline))) }
                    } else {
                        throw AutomationError.invalid("\(spec.name) has no option \(flag). See lamina help \(spec.name).")
                    }
                } else if command == nil {
                    command = argument
                } else if command == "help", invocation.action == .help(command: nil) {
                    invocation.action = .help(command: argument)
                } else {
                    throw AutomationError.invalid("Unexpected argument \(argument). Options are written --name value.")
                }
            }
            index += 1
        }
        guard let command else { return invocation }
        if command == "help" { return invocation }
        if command == "mcp" {
            guard raw.isEmpty else { throw AutomationError.invalid("lamina mcp takes only --dev, --app, --pid and --timeout.") }
            invocation.action = helpRequested ? .help(command: "mcp") : .mcp
            return invocation
        }
        guard let spec = CommandCatalog.command(command) else {
            throw AutomationError(.unknownCommand, "Unknown command \(command). See lamina --help.")
        }
        if helpRequested { invocation.action = .help(command: spec.name); return invocation }
        var values: [String: JSONValue] = [:]
        for (flag, text) in raw {
            guard let parameter = spec.parameters.first(where: { $0.flag == flag }) else { continue }
            let value = try Self.value(text ?? "", for: parameter)
            if case .settings = parameter.type, case .object(let earlier)? = values[parameter.name], case .object(let more) = value {
                values[parameter.name] = .object(earlier.merging(more) { _, new in new })
            } else {
                values[parameter.name] = value
            }
        }
        invocation.action = .run(command: spec.name, arguments: values)
        return invocation
    }

    /// A flag's text as the JSON value its parameter takes.
    static func value(_ text: String, for parameter: ParameterSpec) throws -> JSONValue {
        switch parameter.type {
        case .string, .id, .path, .choice, .color: return .string(text)
        case .integer:
            guard let number = Int(text) else { throw AutomationError.invalid("\(parameter.flag) takes a whole number, not \(text).") }
            return JSONValue(number)
        case .number:
            guard let number = Double(text), number.isFinite else { throw AutomationError.invalid("\(parameter.flag) takes a number, not \(text).") }
            return .number(number)
        case .boolean:
            guard let flag = boolean(text) else { throw AutomationError.invalid("\(parameter.flag) takes true or false, not \(text).") }
            return .bool(flag)
        case .settings: return try settings(text, flag: parameter.flag)
        }
    }

    /// Settings written as a JSON object (`{"radius": 4}`) or as `key=value` pairs separated by commas
    /// (`radius=4,gaussian=true`); values that read as numbers or booleans are taken as such.
    static func settings(_ text: String, flag: String) throws -> JSONValue {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("{") {
            guard let value = try? JSONValue.decode(trimmed), value.objectValue != nil else {
                throw AutomationError.invalid("\(flag) isn't a valid JSON object.")
            }
            return value
        }
        var object: [String: JSONValue] = [:]
        for pair in trimmed.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty else {
                throw AutomationError.invalid("\(flag) takes key=value pairs separated by commas, or a JSON object.")
            }
            let key = parts[0].replacingOccurrences(of: "-", with: "_")
            if let flag = boolean(parts[1]), ["true", "false"].contains(parts[1].lowercased()) { object[key] = .bool(flag) }
            else if let number = Double(parts[1]), number.isFinite { object[key] = .number(number) }
            else { object[key] = .string(parts[1]) }
        }
        return .object(object)
    }

    static func boolean(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "true", "yes", "1", "on": true
        case "false", "no", "0", "off": false
        default: nil
        }
    }
}
