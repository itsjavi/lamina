import Foundation

/// The app `lamina` drives. The bundle ids live here and nowhere else in Swift, so renaming the app changes one place
/// (scripts/build-app.sh has its own copy for signing).
public enum AppIdentity {
    public static let releaseBundleID = "com.itsjavi.lamina"
    public static let devBundleID = releaseBundleID + ".dev"
    public static let displayName = "Lamina"
}

/// How a request reaches the running app: one Apple Event of this class and id, its direct parameter a UTF-8 JSON
/// request, answered by a reply event whose direct parameter is the JSON reply. Apple Events need no open port and
/// no extra entitlement for the sandboxed receiver; macOS asks the person once per calling app (Automation privacy).
public enum AutomationEvent {
    /// 'Lmna' and 'Exec'. Mixed case: all-lowercase codes are Apple's.
    public static let eventClass: UInt32 = fourCharCode("Lmna")
    public static let eventID: UInt32 = fourCharCode("Exec")

    static func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}

/// The JSON that travels in the event: `{"v": 1, "command": "…", "arguments": {…}}` in, and
/// `{"ok": true, "result": {…}}` or `{"ok": false, "error": {"code": "…", "message": "…"}}` back.
public enum AutomationMessage {
    public static let version = 1

    public static func request(command: String, arguments: JSONValue) -> JSONValue {
        ["v": JSONValue(version), "command": .string(command), "arguments": arguments]
    }

    public static func reply(_ outcome: Result<JSONValue, AutomationError>) -> JSONValue {
        switch outcome {
        case .success(let result): ["ok": true, "result": result]
        case .failure(let error): ["ok": false, "error": error.json]
        }
    }

    /// Reads a reply back into the result or the error it carries.
    public static func outcome(of reply: JSONValue) -> Result<JSONValue, AutomationError> {
        if reply["ok"]?.boolValue == true, let result = reply["result"] { return .success(result) }
        let code = reply["error"]?["code"]?.stringValue.flatMap(AutomationError.Code.init(rawValue:)) ?? .failed
        let message = reply["error"]?["message"]?.stringValue ?? "The app sent a reply lamina doesn't understand."
        return .failure(AutomationError(code, message))
    }
}
