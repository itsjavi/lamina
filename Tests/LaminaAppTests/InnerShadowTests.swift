import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Inner Shadow recolors the layer's own pixels and keeps their alpha, as Photoshop's does, on the GPU (canvas, and
/// export when Metal is there) and on the CPU (export without Metal) alike.
@Suite struct InnerShadowTests {
    /// Straight down by 10 with no blur: on a 20 px square, the top 10 rows are wholly in the shadow, and below that
    /// it falls only as far as the moved layer is translucent.
    private func shadow(red: CGFloat, green: CGFloat, blue: CGFloat, opacity: Double) -> InnerShadowEffect {
        InnerShadowEffect(angle: 90, distance: 10, blur: 0, red: red, green: green, blue: blue, opacity: opacity)
    }

    @Test(arguments: [true, false])
    func innerShadowRecolorsTranslucentPixelsAndKeepsTheirAlpha(gpu: Bool) throws {
        // Half-transparent black under a white inner shadow: where the shadow falls fully, it turns half-transparent
        // white, not a more opaque gray.
        let effects = LayerEffects(innerShadow: shadow(red: 1, green: 1, blue: 1, opacity: 1))
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5))
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu)
        let inset = Int(rendered.inset)
        let shaded = try EffectPixels.pixel(rendered.image, x: inset + 10, y: inset + 4)
        #expect(abs(shaded[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(shaded[channel] - shaded[3]) <= 1) }
        // Below, the moved layer is itself half-transparent, so the shadow falls at half strength: a quarter white.
        let half = try EffectPixels.pixel(rendered.image, x: inset + 10, y: inset + 15)
        #expect(abs(half[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(half[channel] - 64) <= 2) }
    }

    @Test(arguments: [true, false])
    func innerShadowOnOpaquePixelsMixesByItsOpacity(gpu: Bool) throws {
        // Opaque red under a black inner shadow at 50%: half red where it falls, untouched where it doesn't, opaque
        // throughout, as before translucent pixels were recolored.
        let effects = LayerEffects(innerShadow: shadow(red: 0, green: 0, blue: 0, opacity: 0.5))
        let source = try EffectPixels.square(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu)
        let inset = Int(rendered.inset)
        let shaded = try EffectPixels.pixel(rendered.image, x: inset + 10, y: inset + 4)
        #expect(abs(shaded[0] - 128) <= 2 && shaded[1] <= 2 && shaded[2] <= 2 && shaded[3] == 255)
        let clear = try EffectPixels.pixel(rendered.image, x: inset + 10, y: inset + 15)
        #expect(clear == [255, 0, 0, 255])
    }

    @Test(arguments: [true, false])
    func innerShadowLeavesTheDropShadowBeneathTranslucentPixels(gpu: Bool) throws {
        // A red drop shadow straight under half-transparent black: the inner shadow recolors the layer, not the drop
        // shadow, so the result is half-transparent white over half-transparent red.
        var effects = LayerEffects(innerShadow: shadow(red: 1, green: 1, blue: 1, opacity: 1))
        effects.shadow = ShadowEffect(angle: 90, distance: 0, blur: 0, red: 1, green: 0, blue: 0, opacity: 1)
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5))
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu)
        let inset = Int(rendered.inset)
        let pixel = try EffectPixels.pixel(rendered.image, x: inset + 10, y: inset + 4)
        #expect(abs(pixel[0] - 192) <= 2 && abs(pixel[1] - 128) <= 2 && abs(pixel[2] - 128) <= 2 && abs(pixel[3] - 192) <= 2)
    }

    @Test(.enabled(if: MetalLayerEffects.shared != nil, "The surface draws its effects with Metal"))
    @MainActor func brushStrokeSurfaceRecolorsTranslucentPixels() throws {
        // While the layer is painted, the surface the canvas shows it from turns it half-transparent white too.
        let effects = LayerEffects(innerShadow: shadow(red: 1, green: 1, blue: 1, opacity: 1))
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5))
        let image = try EffectPixels.surface(source, effects: effects)
        let inset = Int(LayerEffectsRenderer.margin(for: effects))
        let shaded = try EffectPixels.pixel(image, x: inset + 10, y: inset + 4)
        #expect(abs(shaded[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(shaded[channel] - shaded[3]) <= 1) }
    }

    /// The canvas draws effects with Metal and export falls back to the CPU without it: on a translucent, masked
    /// layer both keep its alpha and agree on its color.
    @Test(.enabled(if: MetalLayerEffects.shared != nil, "The GPU path needs Metal"))
    func gpuAndCPUInnerShadowMatch() throws {
        let effects = LayerEffects(innerShadow: InnerShadowEffect(angle: 120, distance: 6, blur: 4,
                                                                  red: 0.9, green: 0.2, blue: 0.1, opacity: 0.8))
        let worst = try EffectPixels.gpuAndCPUColorDifference(effects)
        #expect(worst <= 2, "GPU and CPU differ by up to \(worst) levels")
    }
}
