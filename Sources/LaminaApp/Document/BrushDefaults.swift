import Foundation
import LaminaCore

/// The brush tools that keep a tip (size, hardness, opacity) of their own. Brush and Spot Healing share one, as do
/// Dodge and Burn, and Blur and Smudge.
nonisolated enum BrushTipFamily: Int, CaseIterable, Sendable {
    case brush, clone, smear, eraser, tone, liquify

    /// The start of its keys in `ToolDefaults`: "brushSize", "brushHardness", "brushOpacity".
    var key: String { ["brush", "clone", "smear", "eraser", "tone", "liquify"][rawValue] }
    /// The family whose tip this one shared in versions that had fewer: Eraser, Dodge and Burn were modes of the
    /// Brush, and Liquify a mode of Smear (Blur and Smudge). Settings from then start this one with that tip.
    var sharedBefore: BrushTipFamily? {
        switch self {
        case .eraser, .tone: .brush
        case .liquify: .smear
        case .brush, .clone, .smear: nil
        }
    }
}

/// The brush tips, the Brush's flow and pressure buttons, Dodge and Burn's range and exposure (and which of the two
/// the slot holds) and the two colors belong to the person too (`ToolDefaults`): a new document starts with them as
/// they were last left, in any document, as Photoshop's do.
nonisolated struct BrushDefaults: Equatable, Sendable {
    struct Tip: Equatable, Sendable {
        var diameter: CGFloat
        var hardness: CGFloat
        var opacity: CGFloat
    }
    /// One tip per `BrushTipFamily`, by its raw value. Clone Stamp, Smear and Liquify start soft.
    var tips = BrushTipFamily.allCases.map { family in
        Tip(diameter: 40, hardness: [.clone, .smear, .liquify].contains(family) ? 0 : 1, opacity: 1)
    }
    var smoothing: CGFloat = 0
    var flow: CGFloat = 1
    var pressureSize = false
    var pressureOpacity = false
    /// The Dodge slot holds Burn rather than Dodge.
    var burns = false
    var toneRange = ToneRange.midtones
    var toneExposure: CGFloat = 0.5
    var foreground = PaletteColor.black
    var background = PaletteColor.white

    subscript(family family: BrushTipFamily) -> Tip {
        get { tips[family.rawValue] }
        set { tips[family.rawValue] = newValue }
    }

    /// How many families have tips saved apart; settings from before they were split say nothing, which is three.
    private static let familiesKey = "brushTipFamilies"

    static func load(from store: (any ToolDefaultsStore)? = ToolDefaults.store) -> BrushDefaults {
        func number(_ key: String, _ fallback: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
            let saved = CGFloat(ToolDefaults.double(key, Double(fallback), in: store))
            return saved.isFinite ? min(range.upperBound, max(range.lowerBound, saved)) : fallback
        }
        var result = BrushDefaults()
        let savedApart = ToolDefaults.int(familiesKey, 3, in: store)
        // In order, so a family that used to share a tip finds that tip already read.
        for family in BrushTipFamily.allCases {
            var fallback = result[family: family]
            if family.rawValue >= savedApart, let shared = family.sharedBefore { fallback = result[family: shared] }
            result[family: family] = Tip(diameter: number(family.key + "Size", fallback.diameter, in: 1...2000),
                                         hardness: number(family.key + "Hardness", fallback.hardness, in: 0...1),
                                         opacity: number(family.key + "Opacity", fallback.opacity, in: 0.01...1))
        }
        result.smoothing = number("brushSmoothing", result.smoothing, in: 0...100)
        result.flow = number("brushFlow", result.flow, in: 0.01...1)
        result.pressureSize = ToolDefaults.bool("brushPressureSize", result.pressureSize, in: store)
        result.pressureOpacity = ToolDefaults.bool("brushPressureOpacity", result.pressureOpacity, in: store)
        // Earlier versions saved the Brush's mode (Paint, Erase, Dodge or Burn) instead; Burn is the one that says
        // which tool the Dodge slot holds.
        result.burns = ToolDefaults.string("toneTool", ToolDefaults.string("brushMode", "", in: store), in: store) == "Burn"
        result.toneRange = ToneRange(rawValue: ToolDefaults.string("toneRange", "", in: store)) ?? result.toneRange
        result.toneExposure = number("toneExposure", result.toneExposure, in: 0...1)
        result.foreground = PaletteColor(hex: ToolDefaults.string("foregroundColor", "", in: store)) ?? result.foreground
        result.background = PaletteColor(hex: ToolDefaults.string("backgroundColor", "", in: store)) ?? result.background
        return result
    }

    /// Writes only what differs from `old`, so documents open side by side don't write back each other's settings.
    func save(since old: BrushDefaults, to store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        var wroteTip = false
        for family in BrushTipFamily.allCases where self[family: family] != old[family: family] {
            let tip = self[family: family]
            ToolDefaults.set(Double(tip.diameter), family.key + "Size", in: store)
            ToolDefaults.set(Double(tip.hardness), family.key + "Hardness", in: store)
            ToolDefaults.set(Double(tip.opacity), family.key + "Opacity", in: store)
            wroteTip = true
        }
        // From now on a family with nothing saved is at its compiled default, no longer sharing an older one's tip.
        if wroteTip { ToolDefaults.set(BrushTipFamily.allCases.count, Self.familiesKey, in: store) }
        if smoothing != old.smoothing { ToolDefaults.set(Double(smoothing), "brushSmoothing", in: store) }
        if flow != old.flow { ToolDefaults.set(Double(flow), "brushFlow", in: store) }
        if pressureSize != old.pressureSize { ToolDefaults.set(pressureSize, "brushPressureSize", in: store) }
        if pressureOpacity != old.pressureOpacity { ToolDefaults.set(pressureOpacity, "brushPressureOpacity", in: store) }
        if burns != old.burns { ToolDefaults.set(burns ? "Burn" : "Dodge", "toneTool", in: store) }
        if toneRange != old.toneRange { ToolDefaults.set(toneRange.rawValue, "toneRange", in: store) }
        if toneExposure != old.toneExposure { ToolDefaults.set(Double(toneExposure), "toneExposure", in: store) }
        if foreground != old.foreground { ToolDefaults.set(foreground.hex, "foregroundColor", in: store) }
        if background != old.background { ToolDefaults.set(background.hex, "backgroundColor", in: store) }
    }
}
