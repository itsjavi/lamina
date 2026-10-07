import Foundation

/// The brush tips, the Brush's mode (with Dodge and Burn's range and exposure) and the two colors belong to the person too (`ToolDefaults`): a new document
/// starts with them as they were last left, in any document, as Photoshop's do.
nonisolated struct BrushDefaults: Equatable, Sendable {
    struct Tip: Equatable, Sendable {
        var diameter: CGFloat
        var hardness: CGFloat
        var opacity: CGFloat
    }
    /// One tip per family: Brush and Spot Healing, Clone Stamp, then Smear. The last two start soft.
    var tips = [Tip(diameter: 40, hardness: 1, opacity: 1), Tip(diameter: 40, hardness: 0, opacity: 1), Tip(diameter: 40, hardness: 0, opacity: 1)]
    var smoothing: CGFloat = 0
    var mode = BrushToolMode.paint
    var toneRange = ToneRange.midtones
    var toneExposure: CGFloat = 0.5
    var foreground = PaletteColor.black
    var background = PaletteColor.white

    private static let families = ["brush", "clone", "smear"]

    static func load(from store: (any ToolDefaultsStore)? = ToolDefaults.store) -> BrushDefaults {
        func number(_ key: String, _ fallback: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
            let saved = CGFloat(ToolDefaults.double(key, Double(fallback), in: store))
            return saved.isFinite ? min(range.upperBound, max(range.lowerBound, saved)) : fallback
        }
        var result = BrushDefaults()
        for (family, name) in families.enumerated() {
            let fallback = result.tips[family]
            result.tips[family] = Tip(diameter: number(name + "Size", fallback.diameter, in: 1...2000),
                                      hardness: number(name + "Hardness", fallback.hardness, in: 0...1),
                                      opacity: number(name + "Opacity", fallback.opacity, in: 0.01...1))
        }
        result.smoothing = number("brushSmoothing", result.smoothing, in: 0...100)
        result.mode = BrushToolMode(rawValue: ToolDefaults.string("brushMode", "", in: store)) ?? result.mode
        result.toneRange = ToneRange(rawValue: ToolDefaults.string("toneRange", "", in: store)) ?? result.toneRange
        result.toneExposure = number("toneExposure", result.toneExposure, in: 0...1)
        result.foreground = PaletteColor(hex: ToolDefaults.string("foregroundColor", "", in: store)) ?? result.foreground
        result.background = PaletteColor(hex: ToolDefaults.string("backgroundColor", "", in: store)) ?? result.background
        return result
    }

    /// Writes only what differs from `old`, so documents open side by side don't write back each other's settings.
    func save(since old: BrushDefaults, to store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        for (family, name) in Self.families.enumerated() where tips[family] != old.tips[family] {
            ToolDefaults.set(Double(tips[family].diameter), name + "Size", in: store)
            ToolDefaults.set(Double(tips[family].hardness), name + "Hardness", in: store)
            ToolDefaults.set(Double(tips[family].opacity), name + "Opacity", in: store)
        }
        if smoothing != old.smoothing { ToolDefaults.set(Double(smoothing), "brushSmoothing", in: store) }
        if mode != old.mode { ToolDefaults.set(mode.rawValue, "brushMode", in: store) }
        if toneRange != old.toneRange { ToolDefaults.set(toneRange.rawValue, "toneRange", in: store) }
        if toneExposure != old.toneExposure { ToolDefaults.set(Double(toneExposure), "toneExposure", in: store) }
        if foreground != old.foreground { ToolDefaults.set(foreground.hex, "foregroundColor", in: store) }
        if background != old.background { ToolDefaults.set(background.hex, "backgroundColor", in: store) }
    }
}
