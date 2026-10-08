import Foundation

package enum AdjustmentKind: String, Codable, CaseIterable, Sendable {
    case hsv = "Hue/Saturation", levels = "Levels", curves = "Curves"
    case exposure = "Exposure", gradientMap = "Gradient Map", grain = "Grain", addNoise = "Add Noise"
    case gaussianBlur = "Gaussian Blur", motionBlur = "Motion Blur"
    case invert = "Invert"
    case blackWhite = "Black & White", colorBalance = "Color Balance"
}
package struct LayerAdjustment: Codable, Equatable, Sendable {
    package var kind: AdjustmentKind
    package var hue: Double = 0
    package var saturation: Double = 0
    package var lightness: Double = 0
    package var colorize = false
    // Optional so projects saved before range-aware HSV adjustments still decode.
    package var hsvSettings: HueSaturationSettings?
    package var resolvedHSV: HueSaturationSettings {
        hsvSettings ?? HueSaturationSettings(hue: hue, saturation: saturation, lightness: lightness, colorize: colorize)
    }
    package var levels = LevelsSettings()
    package var curves = CurvesSettings()
    // Optional so projects saved before these adjustments existed decode, and save, exactly as before.
    package var exposureSettings: ExposureSettings?
    package var gradientMapSettings: GradientMapSettings?
    package var grainSettings: GrainSettings?
    package var blackWhiteSettings: BlackWhiteSettings?
    package var colorBalanceSettings: ColorBalanceSettings?
    // Optional so projects created before blur adjustments continue to decode unchanged.
    package var blurRadius: Double?
    package var motionAngle: Double?
    package var motionDistance: Double?
    package var noiseAmount: Double?
    package var noiseGaussian: Bool?
    package var noiseMonochromatic: Bool?
    package var noiseSeed: UInt32?

    package init(kind: AdjustmentKind, hue: Double = 0, saturation: Double = 0, lightness: Double = 0, colorize: Bool = false,
                 hsvSettings: HueSaturationSettings? = nil, levels: LevelsSettings = LevelsSettings(),
                 curves: CurvesSettings = CurvesSettings(), exposureSettings: ExposureSettings? = nil,
                 gradientMapSettings: GradientMapSettings? = nil, grainSettings: GrainSettings? = nil,
                 blackWhiteSettings: BlackWhiteSettings? = nil, colorBalanceSettings: ColorBalanceSettings? = nil,
                 blurRadius: Double? = nil, motionAngle: Double? = nil, motionDistance: Double? = nil,
                 noiseAmount: Double? = nil, noiseGaussian: Bool? = nil, noiseMonochromatic: Bool? = nil,
                 noiseSeed: UInt32? = nil) {
        self.kind = kind
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.colorize = colorize
        self.hsvSettings = hsvSettings
        self.levels = levels
        self.curves = curves
        self.exposureSettings = exposureSettings
        self.gradientMapSettings = gradientMapSettings
        self.grainSettings = grainSettings
        self.blackWhiteSettings = blackWhiteSettings
        self.colorBalanceSettings = colorBalanceSettings
        self.blurRadius = blurRadius
        self.motionAngle = motionAngle
        self.motionDistance = motionDistance
        self.noiseAmount = noiseAmount
        self.noiseGaussian = noiseGaussian
        self.noiseMonochromatic = noiseMonochromatic
        self.noiseSeed = noiseSeed
    }

    package var exposure: ExposureSettings {
        get { exposureSettings ?? ExposureSettings() }
        set { exposureSettings = newValue }
    }
    package var gradientMap: GradientMapSettings {
        get { gradientMapSettings ?? GradientMapSettings() }
        set { gradientMapSettings = newValue }
    }
    package var grain: GrainSettings {
        get { grainSettings ?? GrainSettings() }
        set { grainSettings = newValue }
    }
    package var blackWhite: BlackWhiteSettings {
        get { blackWhiteSettings ?? BlackWhiteSettings() }
        set { blackWhiteSettings = newValue }
    }
    package var colorBalance: ColorBalanceSettings {
        get { colorBalanceSettings ?? ColorBalanceSettings() }
        set { colorBalanceSettings = newValue }
    }
    package var gaussianRadius: Double {
        get { blurRadius ?? 10 }
        set { blurRadius = newValue }
    }
    package var resolvedMotionAngle: Double {
        get { motionAngle ?? 0 }
        set { motionAngle = newValue }
    }
    package var resolvedMotionDistance: Double {
        get { motionDistance ?? 10 }
        set { motionDistance = newValue }
    }
    package var resolvedNoiseAmount: Double {
        get { noiseAmount ?? 10 }
        set { noiseAmount = newValue }
    }
    package var resolvedNoiseGaussian: Bool {
        get { noiseGaussian ?? false }
        set { noiseGaussian = newValue }
    }
    package var resolvedNoiseMonochromatic: Bool {
        get { noiseMonochromatic ?? false }
        set { noiseMonochromatic = newValue }
    }
    package var resolvedNoiseSeed: UInt32 {
        get { noiseSeed ?? 0 }
        set { noiseSeed = newValue }
    }
    package var isValid: Bool {
        hue.isFinite && saturation.isFinite && lightness.isFinite && abs(hue) <= 360 && abs(saturation) <= 100 && abs(lightness) <= 100
        && resolvedHSV.adjustments.values.allSatisfy {
            $0.hue.isFinite && abs($0.hue) <= 360 && $0.saturation.isFinite && abs($0.saturation) <= 100
                && $0.lightness.isFinite && abs($0.lightness) <= 100
        }
        && resolvedHSV.bands.values.allSatisfy { $0.handles.allSatisfy { $0.isFinite } }
        && levels.ranges.count == 4 && levels.ranges.allSatisfy { $0 == $0.normalized } && curves.isValid
        && exposure.isValid && gradientMap.isValid && grain.isValid && blackWhite.isValid && colorBalance.isValid
        && gaussianRadius.isFinite && (0.1...250).contains(gaussianRadius)
        && resolvedMotionAngle.isFinite && (-90...90).contains(resolvedMotionAngle)
        && resolvedMotionDistance.isFinite && (1...2000).contains(resolvedMotionDistance)
        && resolvedNoiseAmount.isFinite && (0.1...400).contains(resolvedNoiseAmount)
    }
}
