import Foundation
import LaminaAutomation

/// `lamina`'s entry point, apart from `main.swift` so tests can run it with their own transport and output.
public enum Lamina {
    public struct Console: Sendable {
        public var standardOutput: @Sendable (String) -> Void
        public var standardError: @Sendable (String) -> Void
        public init(standardOutput: @escaping @Sendable (String) -> Void, standardError: @escaping @Sendable (String) -> Void) {
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
        public static let system = Console(
            standardOutput: { FileHandle.standardOutput.write(Data(($0.hasSuffix("\n") ? $0 : $0 + "\n").utf8)) },
            standardError: { FileHandle.standardError.write(Data(($0.hasSuffix("\n") ? $0 : $0 + "\n").utf8)) })
    }

    /// Exit statuses.
    public static let succeeded: Int32 = 0, failed: Int32 = 1, usage: Int32 = 2, unreachable: Int32 = 3

    /// Runs one command line and returns the exit status. `transport` makes the Apple Event transport by default.
    public static func run(_ arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment,
                           console: Console = .system, transport: ((Invocation) -> CommandTransport)? = nil) -> Int32 {
        let invocation: Invocation
        do { invocation = try Invocation.parse(arguments) }
        catch let error as AutomationError { return report(error, json: arguments.contains("--json"), console: console) }
        catch { return failed }

        switch invocation.action {
        case .version:
            console.standardOutput("lamina \(version)")
            return succeeded
        case .help(let name):
            if let name {
                guard let spec = CommandCatalog.command(name) else {
                    return report(AutomationError(.unknownCommand, "Unknown command \(name). See lamina --help."), json: invocation.json, console: console)
                }
                console.standardOutput(Help.command(spec))
            } else {
                console.standardOutput(Help.overview)
            }
            return succeeded
        case .run(let name, let values):
            guard let spec = CommandCatalog.command(name) else { return usage }
            let channel = transport?(invocation) ?? AppleEventTransport(target: target(invocation, environment), timeout: invocation.timeout)
            do {
                let output = try CommandClient(transport: channel).run(spec, values)
                console.standardOutput(invocation.json ? output.result.encodedString(pretty: true) : TextOutput.render(output.result))
                return succeeded
            } catch let error as AutomationError {
                return report(error, json: invocation.json, console: console)
            } catch {
                return report(AutomationError(.failed, error.localizedDescription), json: invocation.json, console: console)
            }
        }
    }

    static func target(_ invocation: Invocation, _ environment: [String: String]) -> AppTarget {
        AppTarget.resolve(pid: invocation.pid, app: invocation.app, dev: invocation.dev, environment: environment,
                          executable: Bundle.main.executableURL)
    }

    /// The version of the app bundle lamina ships in, or "development" for a `swift build` copy.
    static var version: String {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return "development" }
        let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app", let bundle = Bundle(url: app),
              let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String else { return "development" }
        return "\(short) (\(bundle.bundleIdentifier ?? AppIdentity.releaseBundleID))"
    }

    @discardableResult
    static func report(_ error: AutomationError, json: Bool, console: Console) -> Int32 {
        if json { console.standardOutput(JSONValue.object(["error": error.json]).encodedString(pretty: true)) }
        else { console.standardError("lamina: \(error.message)") }
        switch error.code {
        case .invalidArguments, .unknownCommand: return usage
        case .transport: return unreachable
        default: return failed
        }
    }
}
