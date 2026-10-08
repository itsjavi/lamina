import Foundation

/// A filter or adjustment-layer kind and the settings it takes. `title` is the app's own name for it (the menu item),
/// which is how the app finds its filter or adjustment; tests check that every one exists and that the defaults here
/// are the app's.
public struct EffectKind: Sendable {
    public let name: String
    public let title: String
    public let summary: String
    public let settings: [ParameterSpec]

    public init(_ name: String, _ title: String, _ summary: String, _ settings: [ParameterSpec]) {
        self.name = name
        self.title = title
        self.summary = summary
        self.settings = settings
    }

    /// Checks a settings object against this kind's settings. Settings left out stay at their defaults.
    public func validate(_ settings: [String: JSONValue]) throws -> Arguments {
        let known = Set(self.settings.map(\.name))
        if let unknown = settings.keys.sorted().first(where: { !known.contains($0) }) {
            let names = self.settings.map(\.name)
            throw AutomationError.invalid("\(name) has no setting \(unknown). "
                + (names.isEmpty ? "It takes no settings." : "Its settings: \(names.joined(separator: ", "))."))
        }
        var values: [String: JSONValue] = [:]
        for setting in self.settings {
            if let value = settings[setting.name], !value.isNull { values[setting.name] = try setting.validate(value, in: "settings") }
        }
        return Arguments(values)
    }

    /// One line per setting, for help and tool descriptions.
    public var settingsHelp: String {
        guard !settings.isEmpty else { return "\(name): no settings" }
        return "\(name): " + settings.map { setting in
            let values: String = switch setting.type {
            case .number(let range): "\(ParameterSpec.format(range.lowerBound))–\(ParameterSpec.format(range.upperBound))"
            case .boolean: "true|false"
            case .choice(let names): names.joined(separator: "|")
            default: setting.typeDescription
            }
            let fallback = setting.defaultValue.map { ", default \(EffectCatalog.describe($0))" } ?? ""
            return "\(setting.name) (\(values)\(fallback))"
        }.joined(separator: ", ")
    }
}

/// The filters (Filter and Image › Adjustments menus, applied to a layer's pixels) and adjustment layers (Layer › New
/// Adjustment Layer) commands can use. Kinds that need more than plain settings — Curves and Levels (point lists),
/// Camera Raw (hundreds of settings), Content-Aware Fill (a selection), Dither (a palette) — aren't offered yet.
public enum EffectCatalog {
    public static let filters: [EffectKind] = [
        EffectKind("gaussian-blur", "Gaussian Blur", "Blurs evenly; the layer grows to make room for the blur.", [
            number("radius", 0.1...250, 1, "Blur radius in layer pixels (the blur's standard deviation)."),
        ]),
        EffectKind("motion-blur", "Motion Blur", "Streaks the layer along a direction.", motionBlur(distance: 10)),
        EffectKind("add-noise", "Add Noise", "Adds random noise.", addNoise),
        EffectKind("vignette", "Vignette", "Darkens (or colors) the layer's edges; on an empty layer it frames the canvas.", [
            number("amount", 0...100, 35, "Strength."),
            ParameterSpec("color", .color, "Edge color.", default: "#000000"),
            number("midpoint", 0...100, 50, "Where the falloff starts; lower reaches further in."),
            number("roundness", -100...100, 100, "Shape: 100 is an ellipse, lower values are more rectangular."),
            number("feather", 0...100, 60, "Softness of the falloff."),
            number("highlights", 0...100, 25, "How much bright areas resist darkening."),
        ]),
        EffectKind("bloom-glow", "Bloom / Glow", "Makes bright areas glow.", [
            number("amount", 0...100, 40, "Strength."),
            number("radius", 1...150, 24, "Glow radius in layer pixels."),
        ]),
        EffectKind("tonal-contrast", "Tonal Contrast", "Local contrast, set separately for shadows, midtones and highlights.", [
            number("amount", 0...100, 50, "Overall strength."),
            number("radius", 1...100, 16, "Detail radius in layer pixels."),
            number("shadows", -100...100, 40, "Strength in the shadows."),
            number("midtones", -100...100, 60, "Strength in the midtones."),
            number("highlights", -100...100, 30, "Strength in the highlights."),
        ]),
        EffectKind("lens-correction", "Lens Correction", "Removes barrel or pincushion distortion.", [
            number("distortion", -100...100, 0, "Positive straightens barrel distortion, negative pincushion."),
        ]),
        EffectKind("remove-background", "Remove Background", "Masks out everything but the subject (a layer mask, so it can be undone by editing the mask).", [
            ParameterSpec("quality", .choice(["basic", "advanced"]), "basic is Apple's subject mask; advanced refines it against the image, recovering hair and fur but slower.", default: "basic"),
            number("refine_edges", 0...40, 12, "Advanced: how far the mask is pulled onto the image's own edges, in layer pixels."),
            number("matte_contrast", 0...100, 25, "Advanced: pushes the mask's grays towards black and white."),
            number("shift_edge", -10...10, 0, "Advanced: contracts (negative) or expands (positive) the mask edge, in layer pixels."),
        ]),
        EffectKind("exposure", "Exposure", "Exposure, offset and gamma, as Photoshop's.", exposure),
        EffectKind("grain", "Grain", "Film grain, strongest in the midtones.", grain),
        EffectKind("black-white", "Black & White", "Converts to gray, choosing how bright each color family becomes.", blackWhite),
        EffectKind("color-balance", "Color Balance", "Shifts the colors of the shadows, midtones and highlights.", colorBalance),
        EffectKind("gradient-map", "Gradient Map", "Maps brightness to a gradient between two colors.", gradientMap),
    ]

    public static let adjustments: [EffectKind] = [
        EffectKind("hue-saturation", "Hue/Saturation", "Shifts hue, saturation and lightness, or colorizes.", [
            number("hue", -180...360, 0, "Hue shift in degrees, −180–180; when colorizing, the hue itself, 0–360."),
            number("saturation", -100...100, 0, "Saturation change; when colorizing, the saturation, 0–100."),
            number("lightness", -100...100, 0, "Lightness change."),
            ParameterSpec("colorize", .boolean, "Tint everything one hue instead of shifting hues.", default: false),
        ]),
        EffectKind("exposure", "Exposure", "Exposure, offset and gamma, as Photoshop's.", exposure),
        EffectKind("grain", "Grain", "Film grain, strongest in the midtones (each layer gets its own pattern).", grain),
        EffectKind("add-noise", "Add Noise", "Random noise.", addNoise),
        EffectKind("gaussian-blur", "Gaussian Blur", "Blurs everything below.", [
            number("radius", 0.1...250, 10, "Blur radius in pixels."),
        ]),
        EffectKind("motion-blur", "Motion Blur", "Streaks everything below along a direction.", motionBlur(distance: 10)),
        EffectKind("invert", "Invert", "Inverts the colors below.", []),
        EffectKind("black-white", "Black & White", "Converts to gray, choosing how bright each color family becomes.", blackWhite),
        EffectKind("color-balance", "Color Balance", "Shifts the colors of the shadows, midtones and highlights.", colorBalance),
        EffectKind("gradient-map", "Gradient Map", "Maps brightness to a gradient between two colors.", gradientMap),
    ]

    public static func filter(_ name: String) -> EffectKind? { filters.first { $0.name == name } }
    public static func adjustment(_ name: String) -> EffectKind? { adjustments.first { $0.name == name } }

    // MARK: Settings shared by filters and adjustment layers

    static func number(_ name: String, _ range: ClosedRange<Double>, _ fallback: Double, _ summary: String) -> ParameterSpec {
        ParameterSpec(name, .number(range), summary, default: .number(fallback))
    }

    static func motionBlur(distance: Double) -> [ParameterSpec] {
        [
            number("angle", -90...90, 0, "Direction in degrees, counterclockwise from horizontal."),
            number("distance", 1...2000, distance, "Streak length in pixels."),
        ]
    }

    static let addNoise: [ParameterSpec] = [
        number("amount", 0.1...400, 10, "Strength, as Photoshop's percentage."),
        ParameterSpec("gaussian", .boolean, "Gaussian distribution (more speckled) instead of uniform.", default: false),
        ParameterSpec("monochromatic", .boolean, "Change brightness only, the same on every channel.", default: false),
    ]

    static let exposure: [ParameterSpec] = [
        number("exposure", -20...20, 0, "Stops of light."),
        number("offset", -0.5...0.5, 0, "Added in linear light: negative deepens the shadows, positive lifts them."),
        number("gamma", 0.01...9.99, 1, "Gamma correction; above 1 brightens the midtones."),
    ]

    static let grain: [ParameterSpec] = [
        number("amount", 0...100, 25, "Strength."),
        number("size", 0.5...20, 1.5, "Grain size in pixels."),
        number("roughness", 0...100, 50, "How much finer, irregular detail roughens the grain."),
    ]

    static let blackWhite: [ParameterSpec] = [
        number("reds", -200...300, 40, "Gray level of reds."),
        number("yellows", -200...300, 60, "Gray level of yellows."),
        number("greens", -200...300, 40, "Gray level of greens."),
        number("cyans", -200...300, 60, "Gray level of cyans."),
        number("blues", -200...300, 20, "Gray level of blues."),
        number("magentas", -200...300, 80, "Gray level of magentas."),
        ParameterSpec("tint", .boolean, "Color the result (sepia, cyanotype…).", default: false),
        number("tint_hue", 0...360, 40, "Tint hue in degrees."),
        number("tint_saturation", 0...100, 20, "Tint saturation."),
    ]

    static let colorBalance: [ParameterSpec] = ["shadows", "midtones", "highlights"].flatMap { range in
        [
            number("\(range)_cyan_red", -100...100, 0, "\(range.capitalized): towards cyan (negative) or red (positive)."),
            number("\(range)_magenta_green", -100...100, 0, "\(range.capitalized): towards magenta (negative) or green (positive)."),
            number("\(range)_yellow_blue", -100...100, 0, "\(range.capitalized): towards yellow (negative) or blue (positive)."),
        ]
    } + [ParameterSpec("preserve_luminosity", .boolean, "Keep each pixel's brightness.", default: true)]

    static let gradientMap: [ParameterSpec] = [
        ParameterSpec("shadows", .color, "Color for the darkest tones (default: the foreground color, as in the app)."),
        ParameterSpec("highlights", .color, "Color for the lightest tones (default: the background color, as in the app)."),
        ParameterSpec("reversed", .boolean, "Swap the two ends.", default: false),
    ]

    static func describe(_ value: JSONValue) -> String {
        switch value {
        case .number(let number): ParameterSpec.format(number)
        case .string(let text): text
        case .bool(let flag): flag ? "true" : "false"
        default: value.encodedString()
        }
    }
}
