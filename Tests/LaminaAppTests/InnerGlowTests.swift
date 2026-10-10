import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

@Suite struct InnerGlowTests {
    private func solidSquare(size: Int = 40, color: PaletteColor = PaletteColor(red: 1, green: 1, blue: 1)) throws -> CGImage {
        let context = try BrushRaster.context(width: size, height: size, mask: false)
        context.setFillColor(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return try #require(context.makeImage())
    }

    @Test func innerGlowRendersInsideSourceWithoutBoundsExpansion() throws {
        let source = try solidSquare(size: 40, color: PaletteColor(red: 0, green: 0, blue: 0)) // Black square
        var glow = InnerGlowEffect()
        glow.red = 1; glow.green = 1; glow.blue = 0 // Yellow inner glow
        glow.size = 12
        glow.opacity = 1.0

        var effects = LayerEffects()
        effects.innerGlow = glow

        // Margin should not expand for inner glow (remains baseline 2)
        let margin = LayerEffectsRenderer.margin(for: effects)
        #expect(margin == 2)

        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects)
        let image = rendered.image
        let inset = rendered.inset

        let bitmap = NSBitmapImageRep(cgImage: image)

        // The outer padding area (e.g. x = 0, y = 0) must remain completely transparent
        let outsideColor = try #require(bitmap.colorAt(x: 0, y: 0))
        #expect(outsideColor.alphaComponent == 0)

        // Near the edge inside the square (e.g. x = Int(inset) + 2, y = Int(inset) + 20), inner glow should tint the pixel yellow
        let edgeX = Int(inset) + 2
        let edgeY = Int(inset) + 20
        let edgeColor = try #require(bitmap.colorAt(x: edgeX, y: edgeY))
        #expect(edgeColor.alphaComponent > 0.9)
        #expect(edgeColor.redComponent > 0.3 && edgeColor.greenComponent > 0.3)

        // In the deep center (x = Int(inset) + 20, y = Int(inset) + 20), the black source dominates
        let centerX = Int(inset) + 20
        let centerY = Int(inset) + 20
        let centerColor = try #require(bitmap.colorAt(x: centerX, y: centerY))
        #expect(centerColor.redComponent < 0.2 && centerColor.greenComponent < 0.2)
    }

    @Test func innerGlowRendersAroundTextGlyphs() throws {
        var style = LayerTextStyle()
        style.content = "O"
        style.fontSize = 72
        style.red = 0; style.green = 0; style.blue = 0 // Black text

        let textImage = try EditorSession.textImage(style)
        var glow = InnerGlowEffect()
        glow.red = 1; glow.green = 0; glow.blue = 0 // Red inner glow
        glow.size = 8
        glow.opacity = 0.9

        var effects = LayerEffects()
        effects.innerGlow = glow

        let rendered = try LayerEffectsRenderer.render(textImage, mask: nil, effects: effects)
        #expect(rendered.image.width >= textImage.width)
        #expect(rendered.image.height >= textImage.height)

        let bitmap = NSBitmapImageRep(cgImage: rendered.image)
        let inset = Int(rendered.inset)

        // Outside glyph bounds must be transparent
        let outside = try #require(bitmap.colorAt(x: 0, y: 0))
        #expect(outside.alphaComponent == 0)

        // Search for a glyph pixel that has inner glow tinting
        var foundGlow = false
        for y in inset..<(rendered.image.height - inset) {
            for x in inset..<(rendered.image.width - inset) {
                if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.5, color.redComponent > 0.3 {
                    foundGlow = true
                    break
                }
            }
            if foundGlow { break }
        }
        #expect(foundGlow)
    }

    @Test func innerGlowCPUAndMetalParity() throws {
        guard let metal = MetalLayerEffects.shared else { return }

        let source = try solidSquare(size: 40, color: PaletteColor(red: 0.1, green: 0.1, blue: 0.1))
        var glow = InnerGlowEffect()
        glow.red = 0; glow.green = 1; glow.blue = 1 // Cyan inner glow
        glow.size = 10
        glow.opacity = 0.8

        var effects = LayerEffects()
        effects.innerGlow = glow

        let inset = LayerEffectsRenderer.margin(for: effects)
        let width = source.width + Int(inset) * 2
        let height = source.height + Int(inset) * 2
        let placed = CGRect(x: inset, y: inset, width: CGFloat(source.width), height: CGFloat(source.height))

        let padded = try BrushRaster.context(width: width, height: height, mask: false)
        BrushRaster.draw(source, in: placed, mask: false, context: padded)
        let room = try #require(padded.makeImage())

        let metalImage = try metal.render(room, effects: effects)
        let metalBitmap = NSBitmapImageRep(cgImage: metalImage)

        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: false)
        let cpuBitmap = NSBitmapImageRep(cgImage: rendered.image)

        // Compare an edge point inside the square where inner glow is active
        let edgeX = Int(inset) + 3
        let edgeY = Int(inset) + 20
        let metalColor = try #require(metalBitmap.colorAt(x: edgeX, y: edgeY))
        let cpuColor = try #require(cpuBitmap.colorAt(x: edgeX, y: edgeY))

        #expect(abs(metalColor.alphaComponent - cpuColor.alphaComponent) < 0.15)
        #expect(abs(metalColor.greenComponent - cpuColor.greenComponent) < 0.2)
        #expect(abs(metalColor.blueComponent - cpuColor.blueComponent) < 0.2)
    }

    /// White, size 8, at full strength.
    private var whiteGlow: InnerGlowEffect { InnerGlowEffect(size: 8, red: 1, green: 1, blue: 1, opacity: 1) }

    @Test(arguments: [true, false])
    func innerGlowRecolorsTranslucentPixelsAndKeepsTheirAlpha(gpu: Bool) throws {
        // Half-transparent black under a white inner glow keeps its alpha everywhere, rather than turning more opaque.
        // Deep inside, the glow is the inverse of the layer's own alpha, half strength here, so it turns a quarter
        // white; at the edge, where the glow is stronger, it turns whiter.
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5), size: 60)
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(innerGlow: whiteGlow), gpu: gpu)
        let inset = Int(rendered.inset)
        let middle = try EffectPixels.pixel(rendered.image, x: inset + 30, y: inset + 30)
        #expect(abs(middle[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(middle[channel] - 64) <= 2) }
        let edge = try EffectPixels.pixel(rendered.image, x: inset, y: inset + 30)
        #expect(abs(edge[3] - 128) <= 1)
        for channel in 0..<3 { #expect(edge[channel] > 80 && edge[channel] <= edge[3] + 1) }
    }

    @Test(arguments: [true, false])
    func innerGlowLeavesTheShadowBeneathTranslucentPixels(gpu: Bool) throws {
        // A red shadow straight under half-transparent black: the glow recolors the layer, not the shadow, so the
        // result is the layer, a quarter white at half alpha, over the shadow, half-transparent red.
        var effects = LayerEffects(innerGlow: whiteGlow)
        effects.shadow = ShadowEffect(angle: 90, distance: 0, blur: 0, red: 1, green: 0, blue: 0, opacity: 1)
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5), size: 60)
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: effects, gpu: gpu)
        let inset = Int(rendered.inset)
        let pixel = try EffectPixels.pixel(rendered.image, x: inset + 30, y: inset + 30)
        #expect(abs(pixel[0] - 128) <= 2 && abs(pixel[1] - 64) <= 2 && abs(pixel[2] - 64) <= 2 && abs(pixel[3] - 192) <= 2)
    }

    @Test(.enabled(if: MetalLayerEffects.shared != nil, "The surface draws its effects with Metal"))
    @MainActor func brushStrokeSurfaceRecolorsTranslucentPixels() throws {
        // While the layer is painted, the surface the canvas shows it from keeps the layer's alpha too.
        let effects = LayerEffects(innerGlow: whiteGlow)
        let source = try EffectPixels.square(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5), size: 60)
        let image = try EffectPixels.surface(source, effects: effects)
        let inset = Int(LayerEffectsRenderer.margin(for: effects))
        let middle = try EffectPixels.pixel(image, x: inset + 30, y: inset + 30)
        #expect(abs(middle[3] - 128) <= 1)
        for channel in 0..<3 { #expect(abs(middle[channel] - 64) <= 2) }
    }

    @Test func innerGlowOnOpaquePixelsMovesTheirColorByItsCoverage() throws {
        // Opaque pixels come out as they did when the glow was laid over them: the layer's color moved toward the
        // glow's by its coverage times its opacity, still opaque.
        let source = try solidSquare(size: 40, color: PaletteColor(red: 0.2, green: 0.4, blue: 0.6))
        let glow = InnerGlowEffect(size: 10, red: 1, green: 0.5, blue: 0, opacity: 0.8)
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(innerGlow: glow), gpu: false)
        let width = rendered.image.width, height = rendered.image.height
        let placed = CGRect(x: rendered.inset, y: rendered.inset, width: CGFloat(source.width), height: CGFloat(source.height))
        let coverage = try LayerEffectsRenderer.innerGlowCoverage(source, placed: placed, size: CGSize(width: width, height: height), glow: glow)
        let levels = try GuidedMatte.levels(of: coverage, width: width, height: height)
        let bytes = try EffectPixels.bytes(of: rendered.image)
        let own = [0.2, 0.4, 0.6], color = [1, 0.5, 0]
        var worst = 0
        for y in Int(placed.minY)..<Int(placed.maxY) {
            for x in Int(placed.minX)..<Int(placed.maxX) {
                let pixel = y * width + x, amount = Double(levels[pixel]) * glow.opacity
                #expect(bytes[pixel * 4 + 3] == 255)
                for channel in 0..<3 {
                    let expected = (own[channel] * (1 - amount) + color[channel] * amount) * 255
                    worst = max(worst, abs(Int(bytes[pixel * 4 + channel]) - Int(expected.rounded())))
                }
            }
        }
        #expect(worst <= 2, "The glow is off by up to \(worst) levels")
    }

    /// The canvas draws effects with Metal and export falls back to the CPU without it: on a translucent, masked
    /// layer both keep its alpha and agree on its color.
    @Test(.enabled(if: MetalLayerEffects.shared != nil, "The GPU path needs Metal"))
    func gpuAndCPUInnerGlowMatch() throws {
        let effects = LayerEffects(innerGlow: InnerGlowEffect(size: 6, red: 0.1, green: 0.9, blue: 0.8, opacity: 0.8))
        let worst = try EffectPixels.gpuAndCPUColorDifference(effects)
        #expect(worst <= 2, "GPU and CPU differ by up to \(worst) levels")
    }

    @Test func innerGlowPreservedInExport() async throws {
        let image = try solidSquare(size: 30, color: PaletteColor(red: 0, green: 0, blue: 0))
        let id = UUID()
        let transform = LayerTransform(origin: CGPoint(x: 20, y: 20), size: CGSize(width: 30, height: 30))
        var glow = InnerGlowEffect()
        glow.red = 1; glow.green = 0; glow.blue = 1 // Magenta
        glow.size = 8
        glow.opacity = 0.9

        let effects = LayerEffects(innerGlow: glow)
        let record = ProjectLayerRecord(id: id, name: "InnerGlowLayer", isVisible: true, transform: transform,
                                        imageFile: "\(id).png", effects: effects)
        let manifest = ProjectManifest(documentID: UUID(), width: 100, height: 100, activeLayerID: id, layers: [record])
        let snapshot = ProjectSnapshot(manifest: manifest, images: [id: ImportedImage(image: image, thumbnail: image, name: "InnerGlowLayer")])

        let pngData = try await ImageExporter.shared.pngData(snapshot)
        let rep = try #require(NSBitmapImageRep(data: pngData))

        // Search for an edge pixel inside the 30x30 square placed at (20, 20) with inner glow
        var found = false
        for x in 21...28 {
            if let color = rep.colorAt(x: x, y: 35) {
                if color.alphaComponent > 0.8 && color.redComponent > 0.2 && color.blueComponent > 0.2 {
                    found = true
                    break
                }
            }
        }
        #expect(found)
    }
}
