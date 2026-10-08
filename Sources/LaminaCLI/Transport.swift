import AppKit
import LaminaAutomation

/// Sends one request to the app and returns its reply (both `AutomationMessage` JSON).
public protocol CommandTransport: Sendable {
    func send(_ request: JSONValue) throws -> JSONValue
}

/// Which running app to talk to.
public enum AppTarget: Sendable, Equatable, CustomStringConvertible {
    case bundleID(String)
    case processID(pid_t)

    /// `--pid`, then `--app`/`--dev`, then `LAMINA_APP` (a bundle id, `dev` or `release`), then the app this copy of
    /// lamina ships in (Contents/Helpers/lamina), then the release app.
    public static func resolve(pid: pid_t?, app: String?, dev: Bool, environment: [String: String], executable: URL?) -> AppTarget {
        if let pid { return .processID(pid) }
        if let app { return .bundleID(app) }
        if dev { return .bundleID(AppIdentity.devBundleID) }
        switch environment["LAMINA_APP"] {
        case "dev"?: return .bundleID(AppIdentity.devBundleID)
        case "release"?: return .bundleID(AppIdentity.releaseBundleID)
        case let id? where !id.isEmpty: return .bundleID(id)
        default: break
        }
        if let id = executable.flatMap(enclosingAppBundleID) { return .bundleID(id) }
        return .bundleID(AppIdentity.releaseBundleID)
    }

    /// The bundle id of the app whose Contents/Helpers holds `executable` (through any symlink to it).
    static func enclosingAppBundleID(_ executable: URL) -> String? {
        let helpers = executable.resolvingSymlinksInPath().deletingLastPathComponent()
        let contents = helpers.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard helpers.lastPathComponent == "Helpers", contents.lastPathComponent == "Contents", app.pathExtension == "app" else { return nil }
        return Bundle(url: app)?.bundleIdentifier
    }

    public var description: String {
        switch self {
        case .bundleID(let id): id == AppIdentity.devBundleID ? "\(AppIdentity.displayName) Dev" : id == AppIdentity.releaseBundleID ? AppIdentity.displayName : id
        case .processID(let pid): "process \(pid)"
        }
    }
}

/// The request as an Apple Event to the running app (see `AutomationEvent`), waiting for its reply.
public struct AppleEventTransport: CommandTransport {
    public let target: AppTarget
    public let timeout: TimeInterval

    public init(target: AppTarget, timeout: TimeInterval) {
        self.target = target
        self.timeout = timeout
    }

    public func send(_ request: JSONValue) throws -> JSONValue {
        let address = try addressDescriptor()
        let event = NSAppleEventDescriptor(eventClass: AutomationEvent.eventClass, eventID: AutomationEvent.eventID, targetDescriptor: address,
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: request.encodedString()), forKeyword: keyDirectObject)
        let reply: NSAppleEventDescriptor
        do { reply = try event.sendEvent(options: [.waitForReply], timeout: timeout) }
        catch { throw describe(error as NSError) }
        if let number = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value, number != 0 {
            throw describe(NSError(domain: NSOSStatusErrorDomain, code: Int(number)))
        }
        guard let text = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let value = try? JSONValue.decode(text) else {
            throw AutomationError(.transport, "\(target) sent no reply lamina understands.")
        }
        return value
    }

    /// The process to address. By bundle id, exactly one copy has to be running: with several (a Dev build next to
    /// another), `--pid` picks one.
    private func addressDescriptor() throws -> NSAppleEventDescriptor {
        switch target {
        case .processID(let pid):
            guard NSRunningApplication(processIdentifier: pid) != nil else {
                throw AutomationError(.transport, "No app is running with process id \(pid).")
            }
            return NSAppleEventDescriptor(processIdentifier: pid)
        case .bundleID(let id):
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { !$0.isTerminated }
            guard let app = running.first else {
                throw AutomationError(.transport, "\(target) isn't running (\(id)). Open it, then try again.")
            }
            guard running.count == 1 else {
                let pids = running.map { String($0.processIdentifier) }.joined(separator: ", ")
                throw AutomationError(.transport, "\(running.count) copies of \(target) are running (process ids \(pids)); choose one with --pid.")
            }
            return NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        }
    }

    private func describe(_ error: NSError) -> AutomationError {
        let message: String
        switch error.code {
        case -600: message = "\(target) isn't running."
        case -609: message = "\(target) quit before it answered."
        case -1708: message = "This version of \(target) doesn't take lamina commands. Update it."
        case -1712: message = "\(target) didn't answer within \(Int(timeout)) seconds (--timeout)."
        case -1743, -1744:
            message = "macOS didn't allow this to control \(target). Allow the app you run lamina from (Terminal, your editor or agent) "
                + "in System Settings › Privacy & Security › Automation, then try again."
        default: message = "Couldn't reach \(target) (Apple Event error \(error.code))."
        }
        return AutomationError(.transport, message)
    }
}
