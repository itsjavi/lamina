import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Color Overlay recolors the layer's own pixels and keeps their alpha, on the GPU (canvas, and export when Metal is
/// there) and on the CPU (export without Metal) alike.
@Suite struct ColorOverlayTests {
    /// The premultiplied RGBA bytes at the middle of `image`.
    private func middle(of image: CGImage) throws -> [Int] {
        let all = try EffectPixels.bytes(of: image)
        let offset = ((image.height / 2) * image.width + image.width / 2) * 4
        return (0..<4).map { Int(all[offset + $0]) }
    }

    @Test(arguments: [true, false])
    func overlayRecolorsTranslucentPixelsAndKeepsTheirAlpha(gpu: Bool) throws {
        // Half-transparent black under a white overlay: it should turn half-transparent white, which covers a white
        // background completely, not half-transparent grey that leaves a grey band.
        var effects = LayerEffects()
        effects.colorOverlay = ColorOverlayEffect(red: 1, green: 1, blue: 1, opacity: 1)
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5))
        let pixel = try middle(of: LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu).image)
        #expect(abs(pixel[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(pixel[channel] - pixel[3]) <= 1) }
    }

    @Test(arguments: [true, false])
    func overlayOpacityMixesWithTheLayersOwnColor(gpu: Bool) throws {
        var effects = LayerEffects()
        effects.colorOverlay = ColorOverlayEffect(red: 0, green: 0, blue: 1, opacity: 0.5)
        let source = try EffectPixels.square(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let pixel = try middle(of: LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu).image)
        #expect(abs(pixel[0] - 128) <= 2 && pixel[1] <= 2 && abs(pixel[2] - 128) <= 2 && pixel[3] == 255)
    }

    @Test(arguments: [true, false])
    func overlayLeavesTheShadowBeneathTranslucentPixels(gpu: Bool) throws {
        // A red shadow straight under half-transparent black: the overlay recolors the layer, not the shadow, so the
        // result is half-transparent white over the shadow, itself half-transparent red as it follows the layer.
        var effects = LayerEffects()
        effects.colorOverlay = ColorOverlayEffect(red: 1, green: 1, blue: 1, opacity: 1)
        effects.shadow = ShadowEffect(angle: 90, distance: 0, blur: 0, red: 1, green: 0, blue: 0, opacity: 1)
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5))
        let pixel = try middle(of: LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu).image)
        #expect(abs(pixel[0] - 192) <= 2 && abs(pixel[1] - 128) <= 2 && abs(pixel[2] - 128) <= 2 && abs(pixel[3] - 192) <= 2)
    }

    /// The canvas draws effects with Metal and export falls back to the CPU without it: both give the same pixels,
    /// each the overlay mixed into the layer's own color by its opacity, at the layer's own alpha.
    @Test(.enabled(if: MetalLayerEffects.shared != nil, "The GPU path needs Metal"))
    func gpuAndCPUOverlayMatch() throws {
        let (source, mask) = try EffectPixels.translucentGradient()
        var effects = LayerEffects()
        effects.colorOverlay = ColorOverlayEffect(red: 0.2, green: 0.8, blue: 0.4, opacity: 0.75)
        let plain = try LayerEffectsRenderer.render(source, mask: mask, effects: LayerEffects(), gpu: false)
        let gpu = try LayerEffectsRenderer.render(source, mask: mask, effects: effects, gpu: true)
        let cpu = try LayerEffectsRenderer.render(source, mask: mask, effects: effects, gpu: false)
        #expect(gpu.inset == cpu.inset && gpu.inset == plain.inset)
        #expect(gpu.image.width == cpu.image.width && gpu.image.height == cpu.image.height)
        let gpuBytes = try EffectPixels.bytes(of: gpu.image), cpuBytes = try EffectPixels.bytes(of: cpu.image),
            plainBytes = try EffectPixels.bytes(of: plain.image)
        let overlay = [0.2, 0.8, 0.4], opacity = 0.75
        var worstMatch = 0, worstExpected = 0
        for pixel in 0..<(gpuBytes.count / 4) {
            let alpha = Double(plainBytes[pixel * 4 + 3])
            for channel in 0..<4 {
                let index = pixel * 4 + channel
                worstMatch = max(worstMatch, abs(Int(gpuBytes[index]) - Int(cpuBytes[index])))
                // Source-atop: alpha is the layer's own; color moves toward the overlay's by its opacity.
                let expected = channel == 3 ? alpha
                    : overlay[channel] * 255 * opacity * alpha / 255 + Double(plainBytes[index]) * (1 - opacity)
                worstExpected = max(worstExpected, abs(Int(cpuBytes[index]) - Int(expected.rounded())))
            }
        }
        #expect(worstMatch <= 2, "GPU and CPU differ by up to \(worstMatch) levels")
        #expect(worstExpected <= 2, "The overlay is off by up to \(worstExpected) levels")
    }
}
