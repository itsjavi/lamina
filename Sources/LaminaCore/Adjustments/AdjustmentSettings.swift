import Foundation

/// A setting held to its range, or put back to `fallback` when it isn't a number at all.
package enum AdjustmentValues {
    package static func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}

/// A straight sRGB color stored with an adjustment, 0–1 per channel.
package struct AdjustmentColor: Codable, Equatable, Sendable {
    package var red: Double
    package var green: Double
    package var blue: Double
    package init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    package init(_ color: PaletteColor) { self.init(red: Double(color.red), green: Double(color.green), blue: Double(color.blue)) }
    package var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    package var clamped: Self {
        Self(red: AdjustmentValues.clamp(red, 0...1, 0), green: AdjustmentValues.clamp(green, 0...1, 0),
             blue: AdjustmentValues.clamp(blue, 0...1, 0))
    }
}

/// Photoshop's Exposure: `exposure` (stops) scales linear light and `offset` shifts it, then gamma
/// correction bends the result. The same curve runs on every channel; alpha is kept.
package struct ExposureSettings: Codable, Equatable, Sendable {
    package static let exposureRange: ClosedRange<Double> = -20...20
    package static let offsetRange: ClosedRange<Double> = -0.5...0.5
    package static let gammaRange: ClosedRange<Double> = 0.01...9.99
    /// Stops of light, −20…20.
    package var exposure: Double = 0
    /// Added in linear light, −0.5…0.5: negative deepens the shadows, positive lifts them.
    package var offset: Double = 0
    /// Gamma correction, 0.01…9.99; above 1 brightens the midtones.
    package var gamma: Double = 1

    package init(exposure: Double = 0, offset: Double = 0, gamma: Double = 1) {
        self.exposure = exposure
        self.offset = offset
        self.gamma = gamma
    }

    package var isValid: Bool { Self.exposureRange.contains(exposure) && Self.offsetRange.contains(offset) && Self.gammaRange.contains(gamma) }
    package var normalized: Self {
        Self(exposure: AdjustmentValues.clamp(exposure, Self.exposureRange, 0),
             offset: AdjustmentValues.clamp(offset, Self.offsetRange, 0),
             gamma: AdjustmentValues.clamp(gamma, Self.gammaRange, 1))
    }
    /// Each channel's output (0–1) for each input byte, decoded to linear light and encoded back.
    package var table: [Float] {
        let scale = pow(2, exposure)
        return (0...255).map { index in
            let encoded = Double(index) / 255
            var linear = encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
            linear = pow(max(0, linear * scale + offset), 1 / gamma)
            let output = linear <= 0.0031308 ? linear * 12.92 : 1.055 * pow(linear, 1 / 2.4) - 0.055
            return Float(min(1, max(0, output)))
        }
    }
}

/// Gradient Map: each pixel's brightness picks a color between `shadows` and `highlights` (the other
/// way round when reversed); alpha is kept.
package struct GradientMapSettings: Codable, Equatable, Sendable {
    package var shadows = AdjustmentColor(red: 0, green: 0, blue: 0)
    package var highlights = AdjustmentColor(red: 1, green: 1, blue: 1)
    package var reversed = false

    package init(shadows: AdjustmentColor = AdjustmentColor(red: 0, green: 0, blue: 0),
                 highlights: AdjustmentColor = AdjustmentColor(red: 1, green: 1, blue: 1), reversed: Bool = false) {
        self.shadows = shadows
        self.highlights = highlights
        self.reversed = reversed
    }

    package var isValid: Bool { shadows.isValid && highlights.isValid }
    package var normalized: Self {
        var result = self
        result.shadows = shadows.clamped
        result.highlights = highlights.clamped
        return result
    }
    /// The colors for the darkest and lightest tones, in the order they apply.
    package var ends: (dark: AdjustmentColor, light: AdjustmentColor) { reversed ? (highlights, shadows) : (shadows, highlights) }
}

/// Black & White, as Photoshop's is: not a desaturation, but a choice of how bright each family of
/// colors becomes in gray. Reds at 40% and yellows at 60% is why a default conversion keeps skin and
/// foliage apart where a plain luminance flattens them.
package struct BlackWhiteSettings: Codable, Equatable, Sendable {
    package static let range: ClosedRange<Double> = -200...300
    /// Photoshop's defaults.
    package var reds: Double = 40
    package var yellows: Double = 60
    package var greens: Double = 40
    package var cyans: Double = 60
    package var blues: Double = 20
    package var magentas: Double = 80
    /// Color the result while keeping its tones, for a sepia or a cyanotype.
    package var tint = false
    package var tintHue: Double = 40
    package var tintSaturation: Double = 20

    package init(reds: Double = 40, yellows: Double = 60, greens: Double = 40, cyans: Double = 60, blues: Double = 20,
                 magentas: Double = 80, tint: Bool = false, tintHue: Double = 40, tintSaturation: Double = 20) {
        self.reds = reds
        self.yellows = yellows
        self.greens = greens
        self.cyans = cyans
        self.blues = blues
        self.magentas = magentas
        self.tint = tint
        self.tintHue = tintHue
        self.tintSaturation = tintSaturation
    }

    package var isValid: Bool {
        [reds, yellows, greens, cyans, blues, magentas].allSatisfy { $0.isFinite && Self.range.contains($0) }
            && tintHue.isFinite && (0...360).contains(tintHue)
            && tintSaturation.isFinite && (0...100).contains(tintSaturation)
    }
}

/// Color Balance: shifts color towards one end of each opposing pair, separately for shadows,
/// midtones and highlights. Preserve Luminosity puts each pixel's brightness back afterwards, so a
/// warm cast doesn't also lighten the picture.
package struct ColorBalanceSettings: Codable, Equatable, Sendable {
    package static let range: ClosedRange<Double> = -100...100
    package var shadowCyanRed: Double = 0
    package var shadowMagentaGreen: Double = 0
    package var shadowYellowBlue: Double = 0
    package var midCyanRed: Double = 0
    package var midMagentaGreen: Double = 0
    package var midYellowBlue: Double = 0
    package var highlightCyanRed: Double = 0
    package var highlightMagentaGreen: Double = 0
    package var highlightYellowBlue: Double = 0
    package var preserveLuminosity = true

    package init(shadowCyanRed: Double = 0, shadowMagentaGreen: Double = 0, shadowYellowBlue: Double = 0,
                 midCyanRed: Double = 0, midMagentaGreen: Double = 0, midYellowBlue: Double = 0,
                 highlightCyanRed: Double = 0, highlightMagentaGreen: Double = 0, highlightYellowBlue: Double = 0,
                 preserveLuminosity: Bool = true) {
        self.shadowCyanRed = shadowCyanRed
        self.shadowMagentaGreen = shadowMagentaGreen
        self.shadowYellowBlue = shadowYellowBlue
        self.midCyanRed = midCyanRed
        self.midMagentaGreen = midMagentaGreen
        self.midYellowBlue = midYellowBlue
        self.highlightCyanRed = highlightCyanRed
        self.highlightMagentaGreen = highlightMagentaGreen
        self.highlightYellowBlue = highlightYellowBlue
        self.preserveLuminosity = preserveLuminosity
    }

    private var all: [Double] {
        [shadowCyanRed, shadowMagentaGreen, shadowYellowBlue,
         midCyanRed, midMagentaGreen, midYellowBlue,
         highlightCyanRed, highlightMagentaGreen, highlightYellowBlue]
    }
    package var isValid: Bool { all.allSatisfy { $0.isFinite && Self.range.contains($0) } }
    package var isIdentity: Bool { all.allSatisfy { $0 == 0 } }
}

/// Film grain: brightness noise, strongest in the midtones. Its pattern is fixed in document space by
/// `seed`, so it stays put as the canvas pans or redraws part of the image.
package struct GrainSettings: Codable, Equatable, Sendable {
    package static let amountRange: ClosedRange<Double> = 0...100
    package static let sizeRange: ClosedRange<Double> = 0.5...20
    package static let roughnessRange: ClosedRange<Double> = 0...100
    /// Strength, 0–100.
    package var amount: Double = 25
    /// Grain scale in document pixels, 0.5–20.
    package var size: Double = 1.5
    /// 0–100: how much smaller, irregular detail roughens the main grain particles.
    package var roughness: Double = 50
    package var seed: UInt32 = 0

    package init(amount: Double = 25, size: Double = 1.5, roughness: Double = 50, seed: UInt32 = 0) {
        self.amount = amount
        self.size = size
        self.roughness = roughness
        self.seed = seed
    }

    package var isValid: Bool { Self.amountRange.contains(amount) && Self.sizeRange.contains(size) && Self.roughnessRange.contains(roughness) }
    package var normalized: Self {
        var result = self
        result.amount = AdjustmentValues.clamp(amount, Self.amountRange, 25)
        result.size = AdjustmentValues.clamp(size, Self.sizeRange, 1.5)
        result.roughness = AdjustmentValues.clamp(roughness, Self.roughnessRange, 50)
        return result
    }
}
