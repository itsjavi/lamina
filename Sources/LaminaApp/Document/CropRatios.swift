import Foundation
import Observation

/// The Crop tool's ratio choices, written "W:H".
nonisolated enum CropRatio {
    /// What the picker always offers, in order. "Free" has no ratio; "Original" is the canvas's own.
    static let builtIn = ["Free", "Original", "1:1", "4:3", "3:4", "16:9", "9:16", "9:20", "2.39:1"]

    /// The picker's name for a choice, as familiar editors write them: "Ratio" (free), "Original Ratio", "1:1 (Square)".
    static func title(_ choice: String) -> String {
        switch choice {
        case "Free": "Ratio"
        case "Original": "Original Ratio"
        case "1:1": "1:1 (Square)"
        default: choice
        }
    }
    /// Sides above this make no sensible ratio and only overflow the picker.
    static let largestSide = 10_000.0

    /// `width:height` as the picker lists it, with at most two decimals ("9:20", "2.39:1"); nil unless both are
    /// positive and no larger than `largestSide`.
    static func text(width: Double, height: Double) -> String? {
        func side(_ value: Double) -> String? {
            let rounded = (value * 100).rounded() / 100
            guard rounded.isFinite, rounded > 0, rounded <= largestSide else { return nil }
            return rounded.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
        }
        guard let w = side(width), let h = side(height) else { return nil }
        return "\(w):\(h)"
    }

    /// Width over height for a "W:H" choice; nil for Free, Original, or anything that isn't a ratio.
    static func value(_ text: String) -> CGFloat? {
        let sides = text.split(separator: ":", omittingEmptySubsequences: false)
        guard sides.count == 2, let width = Double(sides[0]), let height = Double(sides[1]),
              width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        return CGFloat(width / height)
    }
}

/// Ratios typed into the Crop tool, newest first, listed after the built-in ones. They belong to the person, not a
/// document: kept across tabs and launches, like the tool switches in `ToolDefaults`.
@MainActor @Observable
final class CustomCropRatios {
    static let shared = CustomCropRatios(defaults: ToolDefaults.isTesting ? nil : .standard)
    /// The oldest drops off past this, so the picker stays short.
    static let limit = 8
    private static let key = "tool.cropRatios"
    private(set) var ratios: [String]
    @ObservationIgnored private let defaults: UserDefaults?

    /// Without `defaults` they last for this run only, as in tests.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        let saved = (defaults?.stringArray(forKey: Self.key) ?? []).filter { CropRatio.value($0) != nil }
        ratios = Array(saved.prefix(Self.limit))
    }

    /// `width:height` as the picker writes it, added at the top of the remembered ones (a built-in ratio is already
    /// there and isn't added); nil when it isn't a ratio.
    @discardableResult
    func add(width: Double, height: Double) -> String? {
        guard let text = CropRatio.text(width: width, height: height) else { return nil }
        guard !CropRatio.builtIn.contains(text) else { return text }
        ratios = Array(([text] + ratios.filter { $0 != text }).prefix(Self.limit))
        defaults?.set(ratios, forKey: Self.key)
        return text
    }
}
