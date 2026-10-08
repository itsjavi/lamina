import Foundation

/// Why a command didn't run. The code is stable and machine-readable; the message is for people.
public struct AutomationError: Error, Sendable, Equatable, CustomStringConvertible {
    public enum Code: String, Sendable, CaseIterable {
        /// A parameter is missing, unknown, of the wrong type or out of range.
        case invalidArguments = "invalid_arguments"
        case unknownCommand = "unknown_command"
        /// No document or layer has that id.
        case notFound = "not_found"
        /// An id prefix matches more than one document or layer.
        case ambiguous
        /// The person is in the middle of an edit (typing text, a transform, an open dialog…) or the app is busy.
        case busy
        /// The document changed since the revision the caller expected.
        case conflict
        /// The command can't apply here: a filter on a folder, nothing to undo, a layer with no pixels…
        case unavailable
        /// The command started but failed (a render or encode error).
        case failed
        /// The request's protocol version is newer than this app understands.
        case unsupportedVersion = "unsupported_version"
        /// `lamina` couldn't reach the app (not running, permission denied, timed out).
        case transport
    }

    public let code: Code
    public let message: String

    public init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }

    public var description: String { message }

    public var json: JSONValue { ["code": .string(code.rawValue), "message": .string(message)] }

    public static func invalid(_ message: String) -> Self { Self(.invalidArguments, message) }
}
