import AppKit
import CoreGraphics
import CoreImage
import LaminaCore

struct LayerEffectSelection: Equatable {
    let layerID: UUID
    let kind: LayerEffectKind
}

extension EditorSession {
    var canEditEffects: Bool { canEditLayers && activeLayer?.isGroup == false && activeLayer?.asset != nil && !activeAppearanceLocked }
    var activeEffects: LayerEffects { activeLayer?.effects ?? LayerEffects() }
    var selectedEffect: LayerEffectSelection? {
        guard let effectSelection, effectSelection.layerID == activeLayerID,
              activeEffects.contains(effectSelection.kind) else { return nil }
        return effectSelection
    }

    /// Selects an effect row; `editing` (a double-click) opens the Layer Style dialog on its page.
    func selectEffect(_ kind: LayerEffectKind, on id: UUID, editing: Bool = false) {
        guard canEditLayers, document?.layers.first(where: { $0.id == id })?.effects?.contains(kind) == true else { return }
        selectLayer(id)
        selectedLayerIDs = [id]
        isMaskSelected = false
        effectSelection = LayerEffectSelection(layerID: id, kind: kind)
        if editing { openLayerStyle(.effect(kind)) }
    }

    func setEffects(_ effects: LayerEffects, on id: UUID? = nil, name: String = "Layer Effects") {
        guard canEditLayers, effects.isValid,
              let index = document?.layers.firstIndex(where: { $0.id == (id ?? activeLayerID) }),
              document?.layers[index].isGroup == false, document?.layers[index].asset != nil,
              document?.effectiveLocks(of: document!.layers[index].id).all != true,
              document?.layers[index].effects != (effects.isEmpty ? nil : effects) else { return }
        finishOpacityEdit()
        beginEdit(name)
        document?.layers[index].effects = effects.isEmpty ? nil : effects
        endEdit()
    }

    func canCopyEffect(_ kind: LayerEffectKind, from source: UUID, to target: UUID) -> Bool {
        guard canEditLayers, source != target,
              document?.layers.first(where: { $0.id == source })?.effects?.contains(kind) == true,
              let layer = document?.layers.first(where: { $0.id == target }),
              !layer.isGroup, layer.asset != nil else { return false }
        return true
    }

    func copyEffect(_ kind: LayerEffectKind, from source: UUID, to target: UUID) {
        guard canCopyEffect(kind, from: source, to: target),
              let original = document?.layers.first(where: { $0.id == source })?.effects else { return }
        var effects = document?.layers.first(where: { $0.id == target })?.effects ?? LayerEffects()
        switch kind {
        case .stroke: effects.stroke = original.stroke
        case .shadow: effects.shadow = original.shadow
        case .colorOverlay: effects.colorOverlay = original.colorOverlay
        case .innerShadow: effects.innerShadow = original.innerShadow
        case .outerGlow: effects.outerGlow = original.outerGlow
        case .innerGlow: effects.innerGlow = original.innerGlow
        }
        setEffects(effects, on: target, name: "Copy " + kind.rawValue)
        selectEffect(kind, on: target)
    }

    func toggleEffect(_ kind: LayerEffectKind, on id: UUID) {
        guard var effects = document?.layers.first(where: { $0.id == id })?.effects else { return }
        let enabled = effects.isEnabled(kind)
        effects.setEnabled(!enabled, for: kind)
        setEffects(effects, on: id, name: (enabled ? "Hide " : "Show ") + kind.rawValue)
    }

    /// The Effects row's eye: hides every effect when any shows, otherwise shows them all, in one undo step.
    func toggleAllEffects(on id: UUID) {
        guard var effects = document?.layers.first(where: { $0.id == id })?.effects, !effects.isEmpty else { return }
        let showing = effects.kinds.contains { effects.isEnabled($0) }
        for kind in effects.kinds { effects.setEnabled(!showing, for: kind) }
        setEffects(effects, on: id, name: showing ? "Hide Effects" : "Show Effects")
    }

    /// The fx badge's triangle: folds a styled layer's effect rows away in the Layers panel, or shows them again.
    func toggleEffectsExpansion(_ id: UUID) {
        if collapsedEffectLayerIDs.contains(id) { collapsedEffectLayerIDs.remove(id) }
        else {
            if effectSelection?.layerID == id { effectSelection = nil }
            collapsedEffectLayerIDs.insert(id)
        }
    }

    func removeSelectedEffect() {
        guard let selectedEffect, canEditLayers,
              var effects = document?.layers.first(where: { $0.id == selectedEffect.layerID })?.effects else { return }
        effects.remove(selectedEffect.kind)
        setEffects(effects, on: selectedEffect.layerID, name: "Remove " + selectedEffect.kind.rawValue)
        effectSelection = nil
    }
}

/// Draws a layer's effects around its pixels. The result is the layer as it should appear — shadow behind, stroke
/// around, pixels on top — on a canvas grown by `inset` pixels on every side, so the caller places it by growing
/// the layer's transform in the same proportion.
nonisolated enum LayerEffectsRenderer {
    /// The last few layers drawn with effects, so the canvas doesn't rebuild them on every redraw.
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(image: CGImage, mask: CGImage?, effects: LayerEffects, result: CGImage, inset: CGFloat)] = []
        func result(image: CGImage, mask: CGImage?, effects: LayerEffects,
                    make: () throws -> (image: CGImage, inset: CGFloat)) throws -> (image: CGImage, inset: CGFloat) {
            lock.lock()
            let hit = entries.first { $0.image === image && $0.mask === mask && $0.effects == effects }
            lock.unlock()
            if let hit { return (hit.result, hit.inset) }
            let made = try make()
            lock.lock()
            let budget = 64 * 1024 * 1024
            let cost = made.image.bytesPerRow * made.image.height + image.bytesPerRow * image.height + (mask.map { $0.bytesPerRow * $0.height } ?? 0)
            if cost <= budget {
                entries.append((image, mask, effects, made.image, made.inset))
                while entries.count > 8 || entries.reduce(0, { $0 + $1.result.bytesPerRow * $1.result.height + $1.image.bytesPerRow * $1.image.height + ($1.mask.map { $0.bytesPerRow * $0.height } ?? 0) }) > budget {
                    entries.removeFirst()
                }
            }
            lock.unlock()
            return made
        }
    }
    private static let cache = Cache()

    /// `image` with `effects` around it, reusing the last result for the same pixels, mask and settings. Nil when
    /// there is nothing to draw or the effects can't be made, so the caller draws the layer as it is.
    static func cached(_ image: CGImage, mask: CGImage?, effects: LayerEffects?) -> (image: CGImage, inset: CGFloat)? {
        guard let effects = effects?.visible, !effects.isEmpty, effects.isValid else { return nil }
        return try? cache.result(image: image, mask: mask, effects: effects) {
            try render(image, mask: mask, effects: effects)
        }
    }

    /// The layer's transform grown by the margin its effects need, so the bigger image lands in the same place.
    static func placed(_ transform: LayerTransform, image: CGImage, inset: CGFloat) -> LayerTransform {
        var grown = transform
        let width = CGFloat(image.width), height = CGFloat(image.height)
        guard width > inset * 2, height > inset * 2 else { return transform }
        grown.size = CGSize(width: transform.size.width * width / (width - inset * 2),
                            height: transform.size.height * height / (height - inset * 2))
        grown.origin = CGPoint(x: transform.center.x - grown.size.width / 2, y: transform.center.y - grown.size.height / 2)
        return grown
    }

    static func margin(for effects: LayerEffects) -> CGFloat {
        let effects = effects.visible
        var margin: CGFloat = 0
        if let stroke = effects.stroke, !stroke.inside { margin = max(margin, stroke.size) }
        if let shadow = effects.shadow {
            margin = max(margin, shadow.distance + shadow.blur * 3)
        }
        if let glow = effects.outerGlow {
            margin = max(margin, glow.size * 3)
        }
        return ceil(margin) + 2
    }

    /// `image` with `effects` around it. `mask` (the layer's own mask, in its pixel grid) hides part of the layer
    /// before the effects are made, so they follow the shape that is actually shown, as in Photoshop. `gpu` false
    /// draws them on the CPU, as when Metal is unavailable, so tests can hold the two paths to the same result.
    static func render(_ image: CGImage, mask: CGImage?, effects: LayerEffects,
                       gpu: Bool = true) throws -> (image: CGImage, inset: CGFloat) {
        let effects = effects.visible
        guard effects.isValid else { throw ProjectError.invalid }
        let inset = margin(for: effects)
        let width = image.width + Int(inset) * 2, height = image.height + Int(inset) * 2
        guard width > 0, height > 0, width * height <= DocumentLimits.maxSurfacePixels else { throw ProjectError.tooLarge }
        let placed = CGRect(x: inset, y: inset, width: CGFloat(image.width), height: CGFloat(image.height))
        let full = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        // The layer as it is shown: its pixels through its mask.
        let shown = try masked(image, mask: mask)
        if gpu, let metal = MetalLayerEffects.shared {
            // The pixels with room around them, then the stroke and shadow drawn on the GPU.
            let padded = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(shown, in: placed, mask: false, context: padded)
            if let room = padded.makeImage(), let built = try? metal.render(room, effects: effects) {
                return (built, inset)
            }
        }
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        if let shadow = effects.shadow, shadow.opacity > 0 {
            let alpha = try coverage(shown, in: placed.offsetBy(dx: shadow.offset.width, dy: shadow.offset.height),
                                     size: CGSize(width: width, height: height), blur: shadow.blur)
            fill(shadow.color, alpha: shadow.opacity, coverage: alpha, in: full, context: context)
        }
        if let glow = effects.outerGlow, glow.opacity > 0 {
            let alpha = try outerGlowCoverage(shown, placed: placed, size: CGSize(width: width, height: height), glow: glow)
            fill(glow.color, alpha: glow.opacity, coverage: alpha, in: full, context: context)
        }
        // An outside stroke sits behind the layer's own pixels; an inside one is drawn over them, or the pixels
        // would simply cover it.
        let stroke = effects.stroke.flatMap { $0.size > 0 && $0.opacity > 0 ? $0 : nil }
        func drawStroke(_ stroke: StrokeEffect) throws {
            let alpha = try strokeCoverage(shown, placed: placed, size: CGSize(width: width, height: height), stroke: stroke)
            fill(stroke.color, alpha: stroke.opacity, coverage: alpha, in: full, context: context)
        }
        if let stroke, !stroke.inside { try drawStroke(stroke) }
        // The layer's own pixels, recolored by a color overlay, then an inner glow and an inner shadow, each keeping
        // the pixels' alpha as Photoshop's do, so a translucent pixel takes them fully and the effects beneath stay
        // untinted.
        let layer = try BrushRaster.context(width: width, height: height, mask: false)
        BrushRaster.draw(shown, in: placed, mask: false, context: layer)
        if let overlay = effects.colorOverlay, overlay.isEnabled, overlay.opacity > 0 {
            recolor(layer, overlay.color, alpha: overlay.opacity, amount: nil, in: full)
        }
        if let innerGlow = effects.innerGlow, innerGlow.isEnabled, innerGlow.opacity > 0,
           let insideGlow = try? innerGlowCoverage(shown, placed: placed, size: CGSize(width: width, height: height), glow: innerGlow) {
            recolor(layer, innerGlow.color, alpha: innerGlow.opacity, amount: insideGlow, in: full)
        }
        if let inner = effects.innerShadow, inner.isEnabled, inner.opacity > 0,
           let inside = try? innerCoverage(shown, placed: placed, size: CGSize(width: width, height: height), shadow: inner) {
            recolor(layer, inner.color, alpha: inner.opacity, amount: inside, in: full)
        }
        guard let styled = layer.makeImage() else { throw ExportError.render }
        // Source-over preserves effects beneath transparent pixels. BrushRaster.draw uses .copy,
        // which would erase the stroke/shadow everywhere inside the source's rectangular bounds.
        context.saveGState()
        context.translateBy(x: 0, y: full.height)
        context.scaleBy(x: 1, y: -1)
        context.setBlendMode(.normal)
        context.draw(styled, in: full)
        context.restoreGState()
        if let stroke, stroke.inside { try drawStroke(stroke) }
        guard let result = context.makeImage() else { throw ExportError.render }
        return (result, inset)
    }

    /// How strongly an inner glow falls on each pixel: strongest at the layer's edges, fading inward. It's the
    /// strength before the layer's own alpha, which the glow keeps as it recolors the pixels (see `recolor`).
    static func innerGlowCoverage(_ image: CGImage, placed: CGRect, size: CGSize, glow: InnerGlowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let blurred = try coverage(image, in: placed, size: size, blur: glow.size)
        let inside = try GuidedMatte.levels(of: blurred, width: width, height: height).map { max(0, min(1, 1 - $0)) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// The layer's pixels with its mask applied, or the pixels as they are when it has none.
    private static func masked(_ image: CGImage, mask: CGImage?) throws -> CGImage {
        guard let mask else { return image }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let context = try BrushRaster.context(width: image.width, height: image.height, mask: false)
        // Draw the source and its grayscale mask in the same image coordinate system.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: bounds, mask: mask)
        context.draw(image, in: bounds)
        guard let result = context.makeImage() else { throw ExportError.render }
        return result
    }

    /// Moves the pixels' color toward `color` by `alpha`, scaled by `amount` where given, keeping their alpha:
    /// source-atop, so a half-transparent pixel takes the color fully.
    static func recolor(_ context: CGContext, _ color: PaletteColor, alpha: Double, amount: CGImage?, in rect: CGRect) {
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        if let amount { fill(color, alpha: alpha, coverage: amount, in: rect, context: context) }
        else {
            context.setFillColor(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: CGFloat(alpha)))
            context.fill(rect)
        }
        context.restoreGState()
    }

    /// A shadow's coverage for one piece of a layer: its shape, moved and softened.
    static func shadowCoverage(_ pixels: CGImage, in size: CGSize, offset: CGSize, blur: CGFloat) throws -> CGImage {
        let placed = CGRect(origin: .zero, size: CGSize(width: pixels.width, height: pixels.height))
        return try coverage(pixels, in: placed.offsetBy(dx: offset.width, dy: offset.height), size: size, blur: blur)
    }

    /// How strongly an inner shadow falls on each pixel: what lies outside the layer, moved and softened. Like
    /// `innerGlowCoverage`, it's the strength before the layer's own alpha.
    static func innerCoverage(_ image: CGImage, placed: CGRect, size: CGSize, shadow: InnerShadowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let moved = try coverage(image, in: placed.offsetBy(dx: shadow.offset.width, dy: shadow.offset.height),
                                 size: size, blur: shadow.blur)
        let inside = try GuidedMatte.levels(of: moved, width: width, height: height).map { max(0, min(1, 1 - $0)) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// An outer glow's coverage: the layer's shape softened omnidirectionally, with the shape interior excluded.
    static func outerGlowCoverage(_ image: CGImage, placed: CGRect, size: CGSize, glow: OuterGlowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let shape = try coverage(image, in: placed, size: size, blur: 0)
        let soft = try coverage(image, in: placed, size: size, blur: glow.size)
        var levels = try GuidedMatte.levels(of: soft, width: width, height: height)
        let mask = try GuidedMatte.levels(of: shape, width: width, height: height)
        for i in levels.indices {
            levels[i] = max(0, min(1, levels[i] * (1 - mask[i])))
        }
        return try GuidedMatte.image(levels, width: width, height: height)
    }

    /// A stroke's ring for one piece of a layer.
    static func ringCoverage(_ pixels: CGImage, in size: CGSize, stroke: StrokeEffect) throws -> CGImage {
        try strokeCoverage(pixels, placed: CGRect(origin: .zero, size: CGSize(width: pixels.width, height: pixels.height)),
                           size: size, stroke: stroke)
    }

    /// The shape's own alpha, placed in a bigger canvas and optionally softened: gray, white where the layer is.
    static func coverage(_ image: CGImage, in rect: CGRect, size: CGSize, blur: CGFloat) throws -> CGImage {
        let context = try BrushRaster.context(width: Int(size.width), height: Int(size.height), mask: true)
        BrushRaster.draw(image, in: rect, mask: true, context: context)
        guard let sharp = context.makeImage() else { throw ExportError.render }
        guard blur > 0 else { return sharp }
        let extent = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let soft = CIImage(cgImage: sharp).clampedToExtent().applyingGaussianBlur(sigma: blur / 2).cropped(to: extent)
        return try PixelAdjust.render(soft, width: Int(size.width), height: Int(size.height), isMask: true)
    }

    /// Where a stroke lands: the shape grown (or shrunk) by its size, less the shape itself. A square reach, not a
    /// round one — a round one eats into the corners of a rectangle, which reads as a wobbly edge.
    static func strokeCoverage(_ image: CGImage, placed: CGRect, size: CGSize, stroke: StrokeEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let shape = try coverage(image, in: placed, size: size, blur: 0)
        var levels = try GuidedMatte.levels(of: shape, width: width, height: height)
        let reach = max(1, Int(stroke.size.rounded()))
        let moved = extreme(levels, width: width, height: height, reach: reach, smallest: stroke.inside)
        // The ring between the two shapes.
        for i in levels.indices {
            levels[i] = stroke.inside ? max(0, levels[i] - moved[i]) : max(0, moved[i] - levels[i])
        }
        return try GuidedMatte.image(levels, width: width, height: height)
    }

    /// The largest (or smallest) value within `reach` on each side: two sliding-window passes, so the cost doesn't
    /// grow with the reach. Core Image's own morphology filters stall on a wide stroke.
    static func extreme(_ source: [Float], width: Int, height: Int, reach: Int, smallest: Bool) -> [Float] {
        guard width > 0, height > 0, source.count == width * height else { return [] }
        let radius = max(0, reach)
        var pass = [Float](repeating: 0, count: source.count)
        var result = [Float](repeating: 0, count: source.count)
        // Each index enters and leaves the deque at most once. A head index avoids Array.removeFirst's
        // shifting cost; one reusable buffer avoids allocating a queue and values array for every line.
        var queue = [Int](repeating: 0, count: max(width, height))
        func sweep(_ input: UnsafeBufferPointer<Float>, _ output: UnsafeMutableBufferPointer<Float>,
                   lines: Int, count: Int, lineStep: Int, elementStep: Int) {
            for line in 0..<lines {
                let base = line * lineStep
                var head = 0, tail = 0, next = 0
                for center in 0..<count {
                    while next <= min(count - 1, center + radius) {
                        let value = input[base + next * elementStep]
                        while tail > head {
                            let previous = input[base + queue[tail - 1] * elementStep]
                            if smallest ? previous < value : previous > value { break }
                            tail -= 1
                        }
                        queue[tail] = next
                        tail += 1
                        next += 1
                    }
                    while head < tail, queue[head] < center - radius { head += 1 }
                    let outside = center < radius || center + radius >= count
                    output[base + center * elementStep] = smallest && outside ? 0 : input[base + queue[head] * elementStep]
                }
            }
        }
        source.withUnsafeBufferPointer { input in
            pass.withUnsafeMutableBufferPointer { output in
                sweep(input, output, lines: height, count: width, lineStep: width, elementStep: 1)
            }
        }
        pass.withUnsafeBufferPointer { input in
            result.withUnsafeMutableBufferPointer { output in
                sweep(input, output, lines: width, count: height, lineStep: 1, elementStep: width)
            }
        }
        return result
    }

    private static func fill(_ color: PaletteColor, alpha: Double, coverage: CGImage, in rect: CGRect, context: CGContext) {
        // Coverage is a CGImage: use the same local image flip as the source, so asymmetric marks
        // and their effects line up instead of mirroring the coverage vertically.
        BrushRaster.fill(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1),
                         coverage: coverage, in: rect, alpha: CGFloat(alpha), context: context)
    }
}
