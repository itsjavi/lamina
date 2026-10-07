import Foundation

/// Numbers as the inspectors show them. Any finite value can reach them (a project written by hand, a typed
/// entry), and `Int(_:)` traps on one past its range, so whole numbers too big for it fall back to an exponent.
nonisolated enum NumberLabel {
    /// Rounded to a whole number.
    static func whole(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if let whole = Int(exactly: value.rounded()) { return String(whole) }
        return String(format: "%.6g", value)
    }

    /// No trailing zeros on a whole number, two decimals otherwise.
    static func upToTwoDecimals(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return abs(value - value.rounded()) < 0.005 ? whole(value) : String(format: "%.2f", value)
    }
}
