import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LaminaCore

nonisolated enum ExportError: LocalizedError {
    case tooLarge, render, encode, webPTooLarge
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Image export supports canvases up to \(DocumentLimits.maxSurfaceMegapixels) megapixels and \(DocumentLimits.maxSide.formatted()) pixels per side."
        case .render: "The canvas could not be rendered. Try a smaller canvas."
        case .encode: "The image could not be encoded."
        case .webPTooLarge: "WebP supports images up to \(WebPEncoder.maxSide.formatted()) pixels per side."
        }
    }
}

/// The formats File › Export As… offers. Every export is the flattened canvas, 8 bits per channel, in sRGB.
nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png, jpeg, heic, avif, webP = "webp", tiff, pdf

    var id: Self { self }
    var title: String { self == .webP ? "WebP" : rawValue.uppercased() }
    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .avif: UTType(importedAs: "public.avif")
        case .webP: .webP
        case .tiff: .tiff
        case .pdf: .pdf
        }
    }
    var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    /// Lossy formats, which have a quality setting.
    var hasQuality: Bool { [.jpeg, .heic, .avif, .webP].contains(self) }
    /// JPEG has no alpha: its transparent areas are filled with a chosen color.
    var keepsTransparency: Bool { self != .jpeg }

    /// The formats this Mac can write. ImageIO's encoders vary with the macOS version and the hardware (AVIF, HEIC),
    /// so they're asked at run time; WebP is written by the bundled libwebp and PDF drawn by Core Graphics.
    static var available: [ExportFormat] { available(encoders: Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])) }
    static func available(encoders: Set<String>) -> [ExportFormat] {
        allCases.filter { $0 == .webP || $0 == .pdf || encoders.contains($0.type.identifier) }
    }
}

actor ImageExporter {
    static let shared = ImageExporter()

    func render(_ snapshot: ProjectSnapshot) throws -> ExportRaster {
        let width = snapshot.manifest.width, height = snapshot.manifest.height
        guard (1...DocumentLimits.maxSide).contains(width), (1...DocumentLimits.maxSide).contains(height),
              width * height <= DocumentLimits.maxSurfacePixels else { throw ExportError.tooLarge }
        return try autoreleasepool {
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw ExportError.render
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            let records = Dictionary(uniqueKeysWithValues: snapshot.manifest.layers.map { ($0.id, $0) })
            for layer in snapshot.manifest.layers {
                guard layer.imageFile == nil || snapshot.images[layer.id] != nil,
                      layer.maskFile == nil || snapshot.masks[layer.id] != nil else { throw ProjectError.missingImage }
            }
            try LiveMaskGraph.validate(snapshot.manifest.layers)
            let live = LiveMaskRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: height), source: { records[$0]?.maskSourceID }) { id, target in
                guard let layer = records[id], let image = snapshot.images[id]?.image else { return }
                let opacity = layer.effectiveOpacity(in: records)
                let mask = snapshot.mask(for: layer).flatMap { $0.clipImage(placement: $0.placement, over: layer.transform, width: image.width, height: image.height) }
                let effects = LayerEffectsRenderer.cached(image, mask: mask, effects: layer.effects)
                func drawLayer(_ mode: LayerBlendMode, _ into: CGContext) {
                    if let effects {
                        let grown = LayerEffectsRenderer.placed(layer.transform, image: effects.image, inset: effects.inset)
                        LayerRenderer.draw(effects.image, transform: grown, center: grown.center,
                            opacity: opacity, blendMode: mode, mask: nil, in: into)
                        return
                    }
                    LayerRenderer.draw(image, transform: layer.transform, center: layer.transform.center,
                        opacity: opacity, blendMode: mode, mask: mask, in: into)
                }
                let mode = layer.blendMode ?? .normal
                // Core Graphics blends these two wrong; see SeparableBlend.
                if SeparableBlend.needsSurface(mode), SeparableBlend.draw(mode, in: target, body: { drawLayer(.normal, $0) }) { return }
                drawLayer(mode, target)
            }
            live.adjustment = { records[$0]?.adjustment }
            live.adjustmentOpacity = { records[$0]?.effectiveOpacity(in: records) ?? 1 }
            live.adjustmentClip = { id, ctx in
                if let layer = records[id], let image = snapshot.mask(for: layer)?.enabledImage {
                    FolderMaskClip(image: image, transform: layer.transform).apply(center: layer.transform.center, in: ctx)
                }
            }
            live.prepareStacks(LayerHierarchy.visibleLayers(snapshot.manifest.layers).map(\.id), parent: { records[$0]?.parentID }, blend: { records[$0]?.blendMode ?? .normal })
            FolderMaskClip.draw(LayerHierarchy.visibleLayers(snapshot.manifest.layers).map(\.id), parent: { records[$0]?.parentID }, clip: { id in
                guard let folder = records[id], let image = snapshot.mask(for: folder)?.enabledImage else { return nil }
                let clip = FolderMaskClip(image: image, transform: folder.transform)
                return { clip.apply(center: folder.transform.center, in: $0) }
            }, in: context) { live.drawComposite($0, in: context) }
            guard let image = context.makeImage() else { throw ExportError.render }
            return ExportRaster(image: image, resolution: snapshot.manifest.resolution ?? 72)
        }
    }

    /// The Space-bar preview, saved in the project's QuickLook folder: the flattened image on white, a JPEG up to
    /// 1,024 px on the long side, about 100–200 KB. Nil for canvases too large to flatten on every save.
    func quickLookImages(_ snapshot: ProjectSnapshot) -> QuickLookImages? {
        guard snapshot.manifest.width * snapshot.manifest.height <= 50_000_000,
              let raster = try? render(snapshot),
              let preview = try? scaledJPEG(raster.image, longSide: 1024) else { return nil }
        return QuickLookImages(preview: preview)
    }

    private func scaledJPEG(_ image: CGImage, longSide: CGFloat) throws -> Data {
        let scale = min(1, longSide / CGFloat(max(image.width, image.height)))
        let width = max(1, Int((CGFloat(image.width) * scale).rounded())), height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        return try autoreleasepool {
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { throw ExportError.render }
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(bounds)
            context.interpolationQuality = .high
            context.draw(image, in: bounds)
            guard let flattened = context.makeImage() else { throw ExportError.render }
            return try encode(flattened, type: .jpeg, properties: [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        }
    }

    func pngData(_ snapshot: ProjectSnapshot) throws -> Data {
        let raster = try render(snapshot)
        return try encode(raster.image, type: .png, properties: [
            kCGImagePropertyDPIWidth: raster.resolution, kCGImagePropertyDPIHeight: raster.resolution
        ] as CFDictionary)
    }

    private func encode(_ image: CGImage, type: UTType, properties: CFDictionary? = nil) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw ExportError.encode
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.encode }
        return data as Data
    }

    /// The flattened canvas encoded as `options.format`, with a preview decoded back from the encoded file, so the
    /// export sheet shows the format's own artifacts.
    func encode(_ raster: ExportRaster, options: ExportOptions) throws -> ExportResult {
        let data = try encodedData(raster, options: options)
        try Task.checkCancellation()
        return try autoreleasepool {
            // Full size, so the dialog's 100% view shows the real artifacts; capped to keep memory in bounds.
            let side = min(max(raster.image.width, raster.image.height), 8192)
            let preview = options.format == .pdf ? try pdfPreview(data, maxPixelSize: side) : try decodedPreview(data, maxPixelSize: side)
            return ExportResult(data: data, preview: preview)
        }
    }

    /// The flattened canvas encoded as `options.format`: the file Export As… and Quick Export as PNG write.
    func encodedData(_ raster: ExportRaster, options: ExportOptions) throws -> Data {
        try Task.checkCancellation()
        return try autoreleasepool {
            var image = raster.image
            if options.fillsTransparency {
                image = try matted(image, options: options)
                try Task.checkCancellation()
            }
            var properties: [CFString: Any] = [kCGImagePropertyDPIWidth: raster.resolution, kCGImagePropertyDPIHeight: raster.resolution]
            if options.format.hasQuality {
                // ImageIO's AVIF encoder fails at exactly 1 (lossless), and gives the same file from 0.99 up.
                let best = options.format == .avif ? 0.99 : 1
                properties[kCGImageDestinationLossyCompressionQuality] = min(best, max(0, options.quality))
            }
            switch options.format {
            case .png, .jpeg, .heic, .avif:
                return try encode(image, type: options.format.type, properties: properties as CFDictionary)
            case .webP:
                return try WebPEncoder.encode(image, quality: options.quality)
            case .tiff:
                // LZW: lossless, read by everything that reads TIFF, and far smaller than uncompressed.
                properties[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFCompression: 5]
                return try encode(image, type: .tiff, properties: properties as CFDictionary)
            case .pdf:
                return try pdf(ExportRaster(image: image, resolution: raster.resolution))
            }
        }
    }

    /// `image` over the options' matte, opaque: for JPEG, which has no alpha, and with Transparency off.
    private func matted(_ image: CGImage, options: ExportOptions) throws -> CGImage {
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ExportError.render }
        context.setFillColor(CGColor(colorSpace: context.colorSpace!,
            components: [options.red, options.green, options.blue, 1])!)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.fill(bounds)
        context.draw(image, in: bounds)
        guard let flattened = context.makeImage() else { throw ExportError.render }
        return flattened
    }

    private func decodedPreview(_ data: Data, maxPixelSize: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw ExportError.encode }
        return preview
    }

    /// One page the document's printed size (its pixels at its resolution), holding the flattened canvas at full
    /// resolution. Drawn by Core Graphics rather than written by ImageIO, whose PDF stores the pixels as a JPEG and
    /// drops the transparency: here they stay lossless, and transparent areas stay transparent, as in a PNG.
    private func pdf(_ raster: ExportRaster) throws -> Data {
        let pointsPerPixel = 72 / (raster.resolution > 0 ? raster.resolution : 72)
        var page = CGRect(x: 0, y: 0, width: CGFloat(raster.image.width) * pointsPerPixel,
                          height: CGFloat(raster.image.height) * pointsPerPixel)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &page, nil) else { throw ExportError.encode }
        context.beginPDFPage(nil)
        context.draw(raster.image, in: page)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// The PDF's page drawn back into pixels, as a viewer shows it (ImageIO can't read PDF).
    private func pdfPreview(_ data: Data, maxPixelSize: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else { throw ExportError.encode }
        let box = page.getBoxRect(.mediaBox)
        let scale = CGFloat(maxPixelSize) / max(box.width, box.height, 1)
        let width = max(1, Int((box.width * scale).rounded())), height = max(1, Int((box.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ExportError.render }
        context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
        context.drawPDFPage(page)
        guard let image = context.makeImage() else { throw ExportError.render }
        return image
    }

    func exportPNG(_ snapshot: ProjectSnapshot, to url: URL) throws {
        let data = try pngData(snapshot)
        try write(data, to: url)
    }

    func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) }
            catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }
}

nonisolated struct QuickLookImages: Sendable {
    let preview: Data
}
nonisolated struct ExportRaster: @unchecked Sendable {
    let image: CGImage
    var resolution: Double = 72
}
nonisolated struct ExportOptions: Equatable, Sendable {
    static let defaultQuality = 0.85
    var format: ExportFormat
    /// For the formats that have one (`ExportFormat.hasQuality`).
    var quality = ExportOptions.defaultQuality
    /// The color under transparent areas (Matte), for formats without alpha (JPEG) and with `transparency` off.
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    /// Keeps transparent areas transparent, in the formats that can (`ExportFormat.keepsTransparency`).
    var transparency = true
    /// Whether transparent areas are filled with the matte.
    var fillsTransparency: Bool { !format.keepsTransparency || !transparency }
}
nonisolated struct ExportResult: @unchecked Sendable {
    let data: Data
    let preview: CGImage
}

/// What Export As… remembers between exports: the format last exported, and for each format the quality and
/// Transparency it was last exported with; the matte is shared. Quick Export as PNG uses PNG's.
nonisolated enum ExportSettings {
    static let formatKey = "exportAsFormat"
    static let matteKey = "exportMatte"
    /// Keys from before Export As… had one dialog, so a quality saved by Export JPEG… carries over.
    static func qualityKey(_ format: ExportFormat) -> String {
        format == .jpeg ? "jpegExportQuality" : "\(format.rawValue)ExportQuality"
    }
    static func transparencyKey(_ format: ExportFormat) -> String { "\(format.rawValue)ExportTransparency" }

    /// The format last exported if it's among `formats`, otherwise the first of them.
    static func format(among formats: [ExportFormat], in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> ExportFormat {
        (store?.object(forKey: formatKey) as? String).flatMap(ExportFormat.init(rawValue:)).flatMap { formats.contains($0) ? $0 : nil }
            ?? formats.first ?? .png
    }

    /// `format` with the settings it was last exported with.
    static func options(for format: ExportFormat, in store: (any ToolDefaultsStore)? = ToolDefaults.store) -> ExportOptions {
        var options = ExportOptions(format: format)
        if let quality = store?.object(forKey: qualityKey(format)) as? Double, quality.isFinite { options.quality = min(1, max(0, quality)) }
        if let transparency = store?.object(forKey: transparencyKey(format)) as? Bool { options.transparency = transparency }
        if let matte = store?.object(forKey: matteKey) as? [Double], matte.count == 3, matte.allSatisfy({ (0...1).contains($0) }) {
            (options.red, options.green, options.blue) = (matte[0], matte[1], matte[2])
        }
        return options
    }

    /// Remembers an export's settings, and its format as the one Export As… starts on.
    static func save(_ options: ExportOptions, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        store?.set(options.format.rawValue, forKey: formatKey)
        if options.format.hasQuality { store?.set(options.quality, forKey: qualityKey(options.format)) }
        if options.format.keepsTransparency { store?.set(options.transparency, forKey: transparencyKey(options.format)) }
        store?.set([Double(options.red), Double(options.green), Double(options.blue)], forKey: matteKey)
    }
}
