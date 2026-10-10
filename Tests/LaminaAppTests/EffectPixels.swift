import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Layers and pixel readers shared by the layer effect suites.
enum EffectPixels {
    /// A square of one color, `size` pixels wide.
    static func square(_ color: CGColor, size: Int = 20) throws -> CGImage {
        let context = try BrushRaster.context(width: size, height: size, mask: false)
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return try #require(context.makeImage())
    }

    /// The premultiplied RGBA bytes of `image`, row by row.
    static func bytes(of image: CGImage) throws -> [UInt8] {
        let context = try BrushRaster.copy(image)
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<image.height).flatMap { y in
            (0..<image.width * 4).map { data[y * context.bytesPerRow + $0] }
        }
    }

    /// The premultiplied RGBA bytes of one pixel of `image`, the top row first.
    static func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let all = try bytes(of: image)
        let offset = (y * image.width + x) * 4
        return (0..<4).map { Int(all[offset + $0]) }
    }

    /// A gradient from clear to opaque, red to blue, seen through a mask that fades the other way.
    static func translucentGradient() throws -> (image: CGImage, mask: CGImage) {
        let width = 64, height = 48
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        for x in 0..<width {
            let t = CGFloat(x) / CGFloat(width - 1)
            context.setFillColor(CGColor(srgbRed: 1 - t, green: 0.3, blue: t, alpha: t))
            context.fill(CGRect(x: x, y: 0, width: 1, height: height))
        }
        let mask = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        for y in 0..<height {
            mask.setFillColor(gray: 1 - CGFloat(y) / CGFloat(height) * 0.8, alpha: 1)
            mask.fill(CGRect(x: 0, y: y, width: width, height: 1))
        }
        return (try #require(context.makeImage()), try #require(mask.makeImage()))
    }

    /// `image` with `effects` as the brush-stroke surface draws them while the layer is painted, the same size as
    /// `LayerEffectsRenderer.render`'s result.
    @MainActor static func surface(_ image: CGImage, effects: LayerEffects) throws -> CGImage {
        let grid = CGSize(width: image.width, height: image.height)
        let surface = try #require(LayerEffectsSurface(layerID: UUID(), effects: effects, grid: grid,
                                                       sourceRect: CGRect(origin: .zero, size: grid)))
        surface.update(base: image, patches: [], mask: nil)
        return try #require(surface.image)
    }

    /// Renders `effects` over the translucent gradient on the GPU and on the CPU. Both keep the layer's own alpha
    /// (within `alphaTolerance` of the plain layer's), and differ in color by no more than the returned levels.
    static func gpuAndCPUColorDifference(_ effects: LayerEffects, alphaTolerance: Int = 2) throws -> Int {
        let (source, mask) = try translucentGradient()
        let plain = try LayerEffectsRenderer.render(source, mask: mask, effects: LayerEffects(), gpu: false)
        let gpu = try LayerEffectsRenderer.render(source, mask: mask, effects: effects, gpu: true)
        let cpu = try LayerEffectsRenderer.render(source, mask: mask, effects: effects, gpu: false)
        #expect(gpu.inset == cpu.inset && gpu.inset == plain.inset)
        #expect(gpu.image.width == cpu.image.width && gpu.image.height == cpu.image.height)
        let gpuBytes = try bytes(of: gpu.image), cpuBytes = try bytes(of: cpu.image), plainBytes = try bytes(of: plain.image)
        var worstAlpha = 0, worstColor = 0
        for pixel in 0..<(gpuBytes.count / 4) {
            let alpha = Int(plainBytes[pixel * 4 + 3])
            worstAlpha = max(worstAlpha, abs(Int(gpuBytes[pixel * 4 + 3]) - alpha), abs(Int(cpuBytes[pixel * 4 + 3]) - alpha))
            for channel in 0..<3 {
                let index = pixel * 4 + channel
                worstColor = max(worstColor, abs(Int(gpuBytes[index]) - Int(cpuBytes[index])))
            }
        }
        #expect(worstAlpha <= alphaTolerance, "The layer's alpha moved by up to \(worstAlpha) levels")
        return worstColor
    }
}
