import AppKit

/// Turns raster coverage into a selection outline along exact pixel edges.
nonisolated enum MaskTracing {
    enum Failure: LocalizedError {
        case tooDetailed
        var errorDescription: String? { "That outline is too detailed to make a selection from." }
    }

    /// Outline of a mask's pixels darker than 50% gray.
    static func darkPixels(in image: CGImage) throws -> CGPath? { try trace(image, alpha: false) { $0 < 128 } }

    /// Outline of a mask's pixels lighter than 50% gray — what a mask shows.
    static func whitePixels(in image: CGImage) throws -> CGPath? { try trace(image, alpha: false) { $0 >= 128 } }

    /// Outline of an image's pixels that are at least 50% opaque.
    static func opaquePixels(in image: CGImage) throws -> CGPath? { try trace(image, alpha: true) { $0 >= 128 } }

    /// Outline, in the image's top-left pixel coordinates, of pixels whose gray value (or
    /// alpha) passes `test`. Outer boundaries run clockwise and holes counterclockwise, so
    /// the winding fill rule reproduces exactly the traced pixels. Nil when none pass.
    /// Traced by the Magic Wand's native tracer, which refuses an outline too detailed to draw (a noisy mask on a
    /// big layer) instead of building an edge graph of any size.
    private static func trace(_ image: CGImage, alpha: Bool, _ test: (UInt8) -> Bool) throws -> CGPath? {
        let width = image.width, height = image.height
        // Alpha is read from RGBA pixels (the 4th byte); gray from a one-byte gray bitmap.
        let channels = alpha ? 4 : 1
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * channels,
                                      space: alpha ? CGColorSpace(name: CGColorSpace.sRGB)! : CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                                                        : CGImageAlphaInfo.none.rawValue),
              let data = context.data else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let offset = channels - 1
        var selected = [UInt8](repeating: 0, count: width * height)
        selected.withUnsafeMutableBufferPointer { mask in
            for index in 0..<mask.count where test(bytes[index * channels + offset]) { mask[index] = 255 }
        }
        do { return try MagicWand.outline(of: selected, width: width, height: height) }
        catch MagicWand.Failure.tooDetailed { throw Failure.tooDetailed }
    }
}

extension EditorSession {
    /// The document-space outline of a layer's mask's black (hidden) areas; nil when there's nothing to trace.
    /// Throws `MaskTracing.Failure.tooDetailed` for an outline too detailed to draw.
    private func maskSelectionOutline(layerID: UUID) throws -> CGPath? {
        guard let layer = document?.layers.first(where: { $0.id == layerID }), let mask = layer.mask?.asset.image,
              let traced = try MaskTracing.darkPixels(in: mask) else { return nil }
        var toDocument = BrushRaster.pixelToDocument(layer.maskTransform, width: mask.width, height: mask.height)
        return traced.copy(using: &toDocument)
    }
    /// The document-space outline of a layer's visible (≥ 50% opaque) pixels; nil when there's nothing to trace.
    /// Throws `MaskTracing.Failure.tooDetailed` for an outline too detailed to draw.
    private func layerSelectionOutline(layerID: UUID) throws -> CGPath? {
        guard let layer = document?.layers.first(where: { $0.id == layerID }), !layer.isGroup,
              let image = layer.asset?.image, let traced = try MaskTracing.opaquePixels(in: image) else { return nil }
        var toDocument = BrushRaster.pixelToDocument(layer.transform, width: image.width, height: image.height)
        return traced.copy(using: &toDocument)
    }

    /// Cmd-click on a mask thumbnail: the mask's black (hidden) areas become the
    /// selection. Shift adds to the current selection; Option subtracts from it.
    func loadMaskSelection(layerID: UUID, mode: SelectionMode = .replace) {
        guard canEditSelection else { return }
        let outline: CGPath?
        do { outline = try maskSelectionOutline(layerID: layerID) } catch { brushError = error.localizedDescription; return }
        guard let outline else { NSSound.beep(); return }
        applySelection(outline, mode: mode, name: "Load Mask Selection")
    }

    /// Cmd-click on a layer thumbnail: the layer's visible (≥ 50% opaque) pixels become
    /// the selection, ignoring its mask, as in Photoshop. Shift adds; Option subtracts.
    func loadLayerSelection(layerID: UUID, mode: SelectionMode = .replace) {
        guard canEditSelection else { return }
        let outline: CGPath?
        do { outline = try layerSelectionOutline(layerID: layerID) } catch { brushError = error.localizedDescription; return }
        guard let outline else { NSSound.beep(); return }
        applySelection(outline, mode: mode, name: "Load Layer Selection")
    }

    /// Intersect Mask/Pixels with Selection, from the Layers panel's context menu. Not a marquee/lasso mode —
    /// nothing there offers an intersect — so it stands apart from `SelectionMode` and combines paths directly.
    func intersectMaskSelection(layerID: UUID) {
        guard canEditSelection else { return }
        do {
            guard let outline = try maskSelectionOutline(layerID: layerID) else { return }
            intersectSelection(with: outline, name: "Intersect Mask Selection")
        } catch { brushError = error.localizedDescription }
    }
    func intersectLayerSelection(layerID: UUID) {
        guard canEditSelection else { return }
        do {
            guard let outline = try layerSelectionOutline(layerID: layerID) else { return }
            intersectSelection(with: outline, name: "Intersect Layer Selection")
        } catch { brushError = error.localizedDescription }
    }
    private func intersectSelection(with outline: CGPath, name: String) {
        guard let current = selection else { return }
        let result = DocumentSelection(path: current.path.intersection(outline, using: .winding), antialiased: current.antialiased,
                                       feather: current.feather)
        // Nothing in common is no selection at all, as in Photoshop — not an invisible empty one.
        setSelection(result.isEmpty ? nil : result, name: name)
    }
}
