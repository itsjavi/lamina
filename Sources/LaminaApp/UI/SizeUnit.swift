import Foundation

/// The units Image Size and New Canvas take a width and height in, and how each turns into pixels: print units at a
/// resolution in pixels per inch, Percent of the size the image has now.
nonisolated enum SizeUnit: String, CaseIterable, Identifiable, Sendable {
    case pixels = "Pixels", percent = "Percent", inches = "Inches", centimeters = "Centimeters", millimeters = "Millimeters"

    var id: String { rawValue }
    /// What the rulers can measure in: a length, so not Percent.
    static let rulerUnits: [SizeUnit] = [.pixels, .inches, .centimeters, .millimeters]
    /// What follows a number in this unit.
    var abbreviation: String {
        switch self {
        case .pixels: "px"
        case .percent: "%"
        case .inches: "in"
        case .centimeters: "cm"
        case .millimeters: "mm"
        }
    }
    /// A length on paper, which takes a resolution to turn into pixels.
    var isPrint: Bool { perInch != nil }
    /// How many of this unit make an inch.
    private var perInch: Double? {
        switch self {
        case .inches: 1
        case .centimeters: 2.54
        case .millimeters: 25.4
        case .pixels, .percent: nil
        }
    }

    /// `value` of this unit in pixels, at `resolution` pixels per inch; Percent is of `original` pixels.
    func pixels(_ value: Double, resolution: Double, original: Double = 1) -> Double {
        switch self {
        case .pixels: value
        case .percent: value / 100 * original
        default: value / (perInch ?? 1) * resolution
        }
    }

    /// `pixels` in this unit, at `resolution` pixels per inch; Percent is of `original` pixels.
    func value(ofPixels pixels: Double, resolution: Double, original: Double = 1) -> Double {
        switch self {
        case .pixels: pixels
        case .percent: pixels / original * 100
        default: pixels / resolution * (perInch ?? 1)
        }
    }

    /// The resolution at which `pixels` print `value` of this unit long: Image Size without resampling.
    func resolution(printing pixels: Double, at value: Double) -> Double {
        pixels / value * (perInch ?? 1)
    }
}
