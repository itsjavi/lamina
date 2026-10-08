import Foundation
import LaminaAutomation
import LaminaCore

/// Puts a command's filter or adjustment settings (named as in `EffectCatalog`) into the app's own settings types.
/// Settings left out keep their defaults; AutomationTests checks every setting here changes something.
nonisolated enum AutomationEffects {
    /// A filter dialog's values: the filter's defaults, then the settings given. The gradient map's colors come from
    /// `base`, the dialog as it opened, since they start from the foreground and background colors.
    static func filterSettings(_ kind: FilterKind, base: FilterSettings, _ settings: Arguments) -> FilterSettings {
        var result = FilterSettings()
        result.gradientMap = base.gradientMap
        let s = settings
        switch kind {
        case .gaussianBlur: set(&result.radius, s, "radius")
        case .motionBlur:
            set(&result.angle, s, "angle")
            set(&result.distance, s, "distance")
        case .addNoise:
            set(&result.amount, s, "amount")
            set(&result.gaussian, s, "gaussian")
            set(&result.monochromatic, s, "monochromatic")
        case .vignette:
            set(&result.vignetteAmount, s, "amount")
            set(&result.vignetteColor, s, "color")
            set(&result.vignetteMidpoint, s, "midpoint")
            set(&result.vignetteRoundness, s, "roundness")
            set(&result.vignetteFeather, s, "feather")
            set(&result.vignetteHighlights, s, "highlights")
        case .bloomGlow:
            set(&result.bloomAmount, s, "amount")
            set(&result.bloomRadius, s, "radius")
        case .tonalContrast:
            set(&result.tonalAmount, s, "amount")
            set(&result.tonalRadius, s, "radius")
            set(&result.tonalShadows, s, "shadows")
            set(&result.tonalMidtones, s, "midtones")
            set(&result.tonalHighlights, s, "highlights")
        case .lensCorrection: set(&result.distortion, s, "distortion")
        case .removeBackground:
            if let quality = s.string("quality"), let value = BackgroundQuality.allCases.first(where: { $0.rawValue.lowercased() == quality }) {
                result.backgroundQuality = value
            }
            set(&result.refineEdges, s, "refine_edges")
            set(&result.matteContrast, s, "matte_contrast")
            set(&result.shiftEdge, s, "shift_edge")
        case .exposure: exposure(&result.exposure, s)
        case .grain: grain(&result.grain, s)
        case .blackWhite: blackWhite(&result.blackWhite, s)
        case .colorBalance: colorBalance(&result.colorBalance, s)
        case .gradientMap: gradientMap(&result.gradientMap, s)
        // Kinds the catalog doesn't offer (Curves, Camera Raw…, and filters added to the app later) take no settings
        // here; a kind joins commands by being added to EffectCatalog and mapped above.
        default: break
        }
        return result
    }

    /// A new adjustment layer's value (`base`, as Layer › New Adjustment Layer made it) with the settings given.
    static func adjustment(_ base: LayerAdjustment, _ settings: Arguments) -> LayerAdjustment {
        var result = base
        let s = settings
        switch base.kind {
        case .hsv:
            guard !s.values.isEmpty else { break }
            result.hsvSettings = HueSaturationSettings(hue: s.double("hue") ?? 0, saturation: s.double("saturation") ?? 0,
                                                       lightness: s.double("lightness") ?? 0, colorize: s.bool("colorize") ?? false)
        case .exposure: exposure(&result.exposure, s)
        case .grain: grain(&result.grain, s)
        case .addNoise:
            set(&result.resolvedNoiseAmount, s, "amount")
            set(&result.resolvedNoiseGaussian, s, "gaussian")
            set(&result.resolvedNoiseMonochromatic, s, "monochromatic")
        case .gaussianBlur: set(&result.gaussianRadius, s, "radius")
        case .motionBlur:
            set(&result.resolvedMotionAngle, s, "angle")
            set(&result.resolvedMotionDistance, s, "distance")
        case .blackWhite: blackWhite(&result.blackWhite, s)
        case .colorBalance: colorBalance(&result.colorBalance, s)
        case .gradientMap: gradientMap(&result.gradientMap, s)
        // Invert has no settings; Levels, Curves and kinds added later aren't offered by the catalog yet.
        default: break
        }
        return result
    }

    /// The catalog's name for an adjustment kind; kinds commands can't add yet get the same style of name.
    static func name(of kind: AdjustmentKind) -> String {
        EffectCatalog.adjustments.first { $0.title == kind.rawValue }?.name
            ?? kind.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    // MARK: Settings shared by filters and adjustment layers

    private static func exposure(_ value: inout ExposureSettings, _ s: Arguments) {
        set(&value.exposure, s, "exposure")
        set(&value.offset, s, "offset")
        set(&value.gamma, s, "gamma")
    }

    private static func grain(_ value: inout GrainSettings, _ s: Arguments) {
        set(&value.amount, s, "amount")
        set(&value.size, s, "size")
        set(&value.roughness, s, "roughness")
    }

    private static func blackWhite(_ value: inout BlackWhiteSettings, _ s: Arguments) {
        set(&value.reds, s, "reds")
        set(&value.yellows, s, "yellows")
        set(&value.greens, s, "greens")
        set(&value.cyans, s, "cyans")
        set(&value.blues, s, "blues")
        set(&value.magentas, s, "magentas")
        set(&value.tint, s, "tint")
        set(&value.tintHue, s, "tint_hue")
        set(&value.tintSaturation, s, "tint_saturation")
    }

    private static func colorBalance(_ value: inout ColorBalanceSettings, _ s: Arguments) {
        set(&value.shadowCyanRed, s, "shadows_cyan_red")
        set(&value.shadowMagentaGreen, s, "shadows_magenta_green")
        set(&value.shadowYellowBlue, s, "shadows_yellow_blue")
        set(&value.midCyanRed, s, "midtones_cyan_red")
        set(&value.midMagentaGreen, s, "midtones_magenta_green")
        set(&value.midYellowBlue, s, "midtones_yellow_blue")
        set(&value.highlightCyanRed, s, "highlights_cyan_red")
        set(&value.highlightMagentaGreen, s, "highlights_magenta_green")
        set(&value.highlightYellowBlue, s, "highlights_yellow_blue")
        set(&value.preserveLuminosity, s, "preserve_luminosity")
    }

    private static func gradientMap(_ value: inout GradientMapSettings, _ s: Arguments) {
        set(&value.shadows, s, "shadows")
        set(&value.highlights, s, "highlights")
        set(&value.reversed, s, "reversed")
    }

    private static func set(_ target: inout Double, _ s: Arguments, _ name: String) {
        if let value = s.double(name) { target = value }
    }

    private static func set(_ target: inout Bool, _ s: Arguments, _ name: String) {
        if let value = s.bool(name) { target = value }
    }

    private static func set(_ target: inout AdjustmentColor, _ s: Arguments, _ name: String) {
        if let color = s.color(name) { target = AdjustmentColor(red: color.red, green: color.green, blue: color.blue) }
    }
}
