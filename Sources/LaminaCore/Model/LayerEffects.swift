import CoreGraphics

/// A line drawn around what the layer shows, outside its edge or inside it.
package struct StrokeEffect: Codable, Equatable, Sendable {
    /// Supported document-pixel width; preview work is bounded independently of this value.
    package static let maxSize: CGFloat = 500
    package var enabled: Bool? = nil // Missing in older projects means visible.
    package var isEnabled: Bool { enabled ?? true }
    package var size: CGFloat = 4
    package var red: CGFloat = 0
    package var green: CGFloat = 0
    package var blue: CGFloat = 0
    package var opacity: Double = 1
    package var inside = false

    package init(enabled: Bool? = nil, size: CGFloat = 4, red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0,
                 opacity: Double = 1, inside: Bool = false) {
        self.enabled = enabled
        self.size = size
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.inside = inside
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    package var isValid: Bool {
        size.isFinite && (0...StrokeEffect.maxSize).contains(size) && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// The layer's shape repeated behind it, offset and softened.
package struct ShadowEffect: Codable, Equatable, Sendable {
    package var enabled: Bool? = nil
    package var isEnabled: Bool { enabled ?? true }
    /// Where the light comes from, in degrees counterclockwise from the right, as Photoshop's dial is: 90 is from
    /// straight above, which drops the shadow straight down.
    package var angle: CGFloat = 90
    package var distance: CGFloat = 20
    package var blur: CGFloat = 20
    package var red: CGFloat = 0
    package var green: CGFloat = 0
    package var blue: CGFloat = 0
    package var opacity: Double = 0.5

    package init(enabled: Bool? = nil, angle: CGFloat = 90, distance: CGFloat = 20, blur: CGFloat = 20,
                 red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, opacity: Double = 0.5) {
        self.enabled = enabled
        self.angle = angle
        self.distance = distance
        self.blur = blur
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    /// Where the shadow sits, in layer pixels (y grows downward, as the layer's own pixels do).
    package var offset: CGSize {
        let radians = angle * .pi / 180
        // The shadow falls away from the light, and a layer's pixels count y downward.
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
    package var isValid: Bool {
        [angle, distance, blur].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(distance) && (0...500).contains(blur)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A flat color over everything the layer shows.
package struct ColorOverlayEffect: Codable, Equatable, Sendable {
    package var enabled: Bool? = nil
    package var isEnabled: Bool { enabled ?? true }
    package var red: CGFloat = 0
    package var green: CGFloat = 0
    package var blue: CGFloat = 0
    package var opacity: Double = 1

    package init(enabled: Bool? = nil, red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, opacity: Double = 1) {
        self.enabled = enabled
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    package var isValid: Bool {
        opacity.isFinite && (0...1).contains(opacity) && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A shadow cast inside the layer's own edges, as though it were cut out of what is behind it.
package struct InnerShadowEffect: Codable, Equatable, Sendable {
    package var enabled: Bool? = nil
    package var isEnabled: Bool { enabled ?? true }
    package var angle: CGFloat = 90
    package var distance: CGFloat = 10
    package var blur: CGFloat = 10
    package var red: CGFloat = 0
    package var green: CGFloat = 0
    package var blue: CGFloat = 0
    package var opacity: Double = 0.5

    package init(enabled: Bool? = nil, angle: CGFloat = 90, distance: CGFloat = 10, blur: CGFloat = 10,
                 red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, opacity: Double = 0.5) {
        self.enabled = enabled
        self.angle = angle
        self.distance = distance
        self.blur = blur
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    /// Where the shadow falls, in layer pixels (y grows downward).
    package var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
    package var isValid: Bool {
        [angle, distance, blur].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(distance) && (0...500).contains(blur)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A soft glow drawn omnidirectionally around the outside of what the layer shows.
package struct OuterGlowEffect: Codable, Equatable, Sendable {
    package var enabled: Bool? = nil
    package var isEnabled: Bool { enabled ?? true }
    package var size: CGFloat = 20
    package var red: CGFloat = 1
    package var green: CGFloat = 1
    package var blue: CGFloat = 1
    package var opacity: Double = 0.75

    package init(enabled: Bool? = nil, size: CGFloat = 20, red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1,
                 opacity: Double = 0.75) {
        self.enabled = enabled
        self.size = size
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    package var isValid: Bool {
        size.isFinite && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A glow cast inside the layer's own edges, emanating inward from its boundary.
package struct InnerGlowEffect: Codable, Equatable, Sendable {
    package var enabled: Bool? = nil
    package var isEnabled: Bool { enabled ?? true }
    package var size: CGFloat = 10
    package var red: CGFloat = 1
    package var green: CGFloat = 1
    package var blue: CGFloat = 1
    package var opacity: Double = 0.75

    package init(enabled: Bool? = nil, size: CGFloat = 10, red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1,
                 opacity: Double = 0.75) {
        self.enabled = enabled
        self.size = size
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    package var isValid: Bool {
        size.isFinite && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// What a layer draws around itself. Kept with the layer, so it follows every edit and can be changed or removed
/// at any time; the pixels themselves are never touched.
package struct LayerEffects: Codable, Equatable, Sendable {
    package var stroke: StrokeEffect? = nil
    package var shadow: ShadowEffect? = nil
    package var colorOverlay: ColorOverlayEffect? = nil
    package var innerShadow: InnerShadowEffect? = nil
    package var outerGlow: OuterGlowEffect? = nil
    package var innerGlow: InnerGlowEffect? = nil

    package init(stroke: StrokeEffect? = nil, shadow: ShadowEffect? = nil, colorOverlay: ColorOverlayEffect? = nil,
                 innerShadow: InnerShadowEffect? = nil, outerGlow: OuterGlowEffect? = nil,
                 innerGlow: InnerGlowEffect? = nil) {
        self.stroke = stroke
        self.shadow = shadow
        self.colorOverlay = colorOverlay
        self.innerShadow = innerShadow
        self.outerGlow = outerGlow
        self.innerGlow = innerGlow
    }

    package var isEmpty: Bool { stroke == nil && shadow == nil && colorOverlay == nil && innerShadow == nil && outerGlow == nil && innerGlow == nil }
    package var isValid: Bool {
        (stroke?.isValid ?? true) && (shadow?.isValid ?? true)
            && (colorOverlay?.isValid ?? true) && (innerShadow?.isValid ?? true)
            && (outerGlow?.isValid ?? true) && (innerGlow?.isValid ?? true)
    }
    /// The effects for an image resampled by `factor`: every size, distance and blur in pixels scaled with it, held to
    /// the ranges `isValid` accepts.
    package func scaled(by factor: CGFloat) -> LayerEffects {
        func scale(_ value: CGFloat?, upTo limit: CGFloat) -> CGFloat { min(limit, (value ?? 0) * factor) }
        var result = self
        result.stroke?.size = scale(stroke?.size, upTo: 500)
        result.shadow?.distance = scale(shadow?.distance, upTo: 5000)
        result.shadow?.blur = scale(shadow?.blur, upTo: 500)
        result.innerShadow?.distance = scale(innerShadow?.distance, upTo: 5000)
        result.innerShadow?.blur = scale(innerShadow?.blur, upTo: 500)
        result.outerGlow?.size = scale(outerGlow?.size, upTo: 500)
        result.innerGlow?.size = scale(innerGlow?.size, upTo: 500)
        return result
    }
    package var kinds: [LayerEffectKind] { LayerEffectKind.allCases.filter { contains($0) } }
    package func contains(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: return stroke != nil
        case .shadow: return shadow != nil
        case .colorOverlay: return colorOverlay != nil
        case .innerShadow: return innerShadow != nil
        case .outerGlow: return outerGlow != nil
        case .innerGlow: return innerGlow != nil
        }
    }
    package func isEnabled(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: return stroke?.isEnabled == true
        case .shadow: return shadow?.isEnabled == true
        case .colorOverlay: return colorOverlay?.isEnabled == true
        case .innerShadow: return innerShadow?.isEnabled == true
        case .outerGlow: return outerGlow?.isEnabled == true
        case .innerGlow: return innerGlow?.isEnabled == true
        }
    }
    /// The effect's own color, and a way to put a new one back.
    package func color(_ kind: LayerEffectKind) -> PaletteColor? {
        switch kind {
        case .stroke: return stroke?.color
        case .shadow: return shadow?.color
        case .colorOverlay: return colorOverlay?.color
        case .innerShadow: return innerShadow?.color
        case .outerGlow: return outerGlow?.color
        case .innerGlow: return innerGlow?.color
        }
    }
    package mutating func setColor(_ color: PaletteColor, for kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke?.red = color.red; stroke?.green = color.green; stroke?.blue = color.blue
        case .shadow: shadow?.red = color.red; shadow?.green = color.green; shadow?.blue = color.blue
        case .colorOverlay: colorOverlay?.red = color.red; colorOverlay?.green = color.green; colorOverlay?.blue = color.blue
        case .innerShadow: innerShadow?.red = color.red; innerShadow?.green = color.green; innerShadow?.blue = color.blue
        case .outerGlow: outerGlow?.red = color.red; outerGlow?.green = color.green; outerGlow?.blue = color.blue
        case .innerGlow: innerGlow?.red = color.red; innerGlow?.green = color.green; innerGlow?.blue = color.blue
        }
    }
    package mutating func remove(_ kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke = nil
        case .shadow: shadow = nil
        case .colorOverlay: colorOverlay = nil
        case .innerShadow: innerShadow = nil
        case .outerGlow: outerGlow = nil
        case .innerGlow: innerGlow = nil
        }
    }
    package mutating func setEnabled(_ enabled: Bool, for kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke?.enabled = enabled
        case .shadow: shadow?.enabled = enabled
        case .colorOverlay: colorOverlay?.enabled = enabled
        case .innerShadow: innerShadow?.enabled = enabled
        case .outerGlow: outerGlow?.enabled = enabled
        case .innerGlow: innerGlow?.enabled = enabled
        }
    }
    package var visible: LayerEffects {
        LayerEffects(stroke: stroke?.isEnabled == true ? stroke : nil,
                     shadow: shadow?.isEnabled == true ? shadow : nil,
                     colorOverlay: colorOverlay?.isEnabled == true ? colorOverlay : nil,
                     innerShadow: innerShadow?.isEnabled == true ? innerShadow : nil,
                     outerGlow: outerGlow?.isEnabled == true ? outerGlow : nil,
                     innerGlow: innerGlow?.isEnabled == true ? innerGlow : nil)
    }
}

package enum LayerEffectKind: String, CaseIterable, Sendable {
    case stroke = "Stroke", shadow = "Drop Shadow", colorOverlay = "Color Overlay", innerShadow = "Inner Shadow", outerGlow = "Outer Glow", innerGlow = "Inner Glow"
}
