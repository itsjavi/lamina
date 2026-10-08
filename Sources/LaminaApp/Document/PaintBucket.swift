import AppKit
import CPixels
import LaminaCore

/// The Paint Bucket's options-bar settings.
nonisolated struct BucketSettings: Equatable, Sendable {
    /// How far (0–255) each channel may differ from the clicked pixel and still be filled.
    var tolerance = 32
    /// Only similar pixels connected to the clicked one, rather than every similar pixel.
    var contiguous = true
    /// Read the visible composite rather than just the active layer (or its mask).
    var sampleAllLayers = false
    /// Soften the fill's edge, a pixel either side of it.
    var antialiased = true
    var opacity: CGFloat = 1
}

/// Fills an area of similar color. The area is the one the Magic Wand finds (`wand_mask`, sampling the clicked pixel)
/// and its edge is softened in C too (`bucket_coverage`), so a large fill stays quick in an unoptimized build. Pixels
/// are compared premultiplied, so fully transparent pixels all match each other whatever color they once had.
nonisolated enum PaintBucket {
    struct Coverage: @unchecked Sendable {
        /// Grayscale, white where the fill paints.
        let image: CGImage
        /// Where `image` sits, in document pixels.
        let rect: CGRect
    }

    /// The area matching the pixel at `point` in `image` (document-sized, top-left pixel coordinates). Nil when
    /// nothing matches or the point is outside the image.
    static func coverage(in image: CGImage, at point: CGPoint, settings: BucketSettings) throws -> Coverage? {
        let width = image.width, height = image.height
        let x = Int(point.x.rounded(.down)), y = Int(point.y.rounded(.down))
        guard point.x.isFinite, point.y.isFinite, (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let context = try BrushRaster.copy(image)
        guard let data = context.data else { throw ExportError.render }
        var mask = [UInt8](repeating: 0, count: width * height)
        let count = mask.withUnsafeMutableBufferPointer {
            wand_mask(data.assumingMemoryBound(to: UInt8.self), width, height, context.bytesPerRow, x, y, 0,
                      Int32(min(255, max(0, settings.tolerance))), settings.contiguous ? 1 : 0, $0.baseAddress)
        }
        guard count >= 0 else { throw MagicWand.Failure.memory }
        guard count > 0 else { return nil }
        var box = [Int](repeating: 0, count: 4)
        guard mask.withUnsafeBufferPointer({ bucket_bounds($0.baseAddress, width, height, &box) }) == 1 else { return nil }
        // An anti-aliased edge reaches a pixel past the area.
        var rect = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
        if settings.antialiased {
            rect = rect.insetBy(dx: -1, dy: -1).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let boxWidth = Int(rect.width), boxHeight = Int(rect.height)
        var pixels = [UInt8](repeating: 0, count: boxWidth * boxHeight)
        mask.withUnsafeBufferPointer { source in
            pixels.withUnsafeMutableBufferPointer { target in
                bucket_coverage(source.baseAddress, width, height, Int(rect.minX), Int(rect.minY), boxWidth, boxHeight,
                                settings.antialiased ? 1 : 0, target.baseAddress)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let coverage = CGImage(width: boxWidth, height: boxHeight, bitsPerComponent: 8, bitsPerPixel: 8,
                                     bytesPerRow: boxWidth, space: CGColorSpaceCreateDeviceGray(),
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw ExportError.render }
        return Coverage(image: coverage, rect: rect)
    }
}

private nonisolated struct BucketJob: @unchecked Sendable {
    let image: CGImage
    let point: CGPoint
    let settings: BucketSettings
}

private nonisolated struct BucketResult: @unchecked Sendable {
    let coverage: PaintBucket.Coverage?
    let error: Error?
}

extension EditorSession {
    /// The Paint Bucket: fills the area of similar color around `point` (document pixels) with the foreground color,
    /// on the active layer or its mask, as one undo step. With a selection only selected pixels are filled; the
    /// selection doesn't limit how far the area reaches. Matching runs off the main thread, as the Magic Wand's does.
    func paintBucket(at point: CGPoint) async {
        guard tool == .paintBucket, !isProjectBusy, let document, let layer = activeLayer,
              point.x >= 0, point.y >= 0, point.x < document.size.width, point.y < document.size.height else { return }
        guard canEditPixels else { brushError = paintRefusal; return }
        let value = paletteColor(background: false)
        // A text layer that is still text takes the color as its own, as Edit › Fill does: the letters stay editable.
        if !isMaskSelected, selection == nil, layer.liveText != nil, recolorText(layer.id, to: value) { return }
        let settings = bucketSettings
        guard let sample = bucketSample(document, layer: layer, sampleAllLayers: settings.sampleAllLayers) else { return }
        let job = BucketJob(image: sample, point: point, settings: settings)
        isProjectBusy = true
        let result = await Task.detached(priority: .userInitiated) { () -> BucketResult in
            do { return BucketResult(coverage: try PaintBucket.coverage(in: job.image, at: job.point, settings: job.settings), error: nil) }
            catch { return BucketResult(coverage: nil, error: error) }
        }.value
        isProjectBusy = false
        if let error = result.error { brushError = error.localizedDescription; return }
        guard self.document?.id == document.id, activeLayerID == layer.id, let current = activeLayer,
              let coverage = result.coverage else { return }
        let color = isMaskSelected
            ? CGColor(gray: value.luminance, alpha: 1)
            : CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [value.red, value.green, value.blue, 1])!
        await applyPixelEdit(to: current, name: isMaskSelected ? "Paint Bucket Mask" : "Paint Bucket") {
            try $0.fill(color, coverage: coverage.image, in: coverage.rect, opacity: settings.opacity)
        }
    }

    /// What the Paint Bucket reads, at document size: every visible layer as shown, or what it fills — the active
    /// layer's own pixels or, when its mask is the target, the mask's grays (its background past its edge).
    func bucketSample(_ document: CanvasDocument, layer: ImageLayer, sampleAllLayers: Bool) -> CGImage? {
        guard isMaskSelected, !sampleAllLayers, let mask = layer.mask else {
            return selectionSample(document, sampleAllLayers: sampleAllLayers)
        }
        guard let context = try? BrushRaster.context(width: document.width, height: document.height, mask: false) else { return nil }
        context.setFillColor(gray: LayerMask.background(of: mask.asset.thumbnail), alpha: 1)
        context.fill(CGRect(origin: .zero, size: document.size))
        let transform = layer.maskTransform
        LayerRenderer.draw(mask.asset.image, transform: transform, center: transform.center, in: context)
        return context.makeImage()
    }

    /// G chooses the Gradient or the Paint Bucket, whichever was used last; Shift-G switches between them.
    func pressGradientKey() {
        selectTool(lastFillTool)
    }

    func toggleFillTool() {
        selectTool(tool == .paintBucket ? .gradient : .paintBucket)
    }
}
