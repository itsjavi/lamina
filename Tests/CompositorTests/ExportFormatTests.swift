import AppKit
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import Compositor

@MainActor
struct ExportFormatTests {
    /// 64 × 32 at 144 pixels/inch: the left half opaque red, the right half clear.
    private func raster() throws -> ExportRaster {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 256,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(try #require(CGColor(colorSpace: space, components: [1, 0, 0, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return ExportRaster(image: try #require(context.makeImage()), resolution: 144)
    }

    /// The image's pixels as sRGB RGBA bytes, top row first.
    private func pixels(_ image: CGImage, width: Int = 64, height: Int = 32) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: width * height * 4))
    }

    /// Red on the left; on the right, clear where the format keeps transparency and the white matte where it doesn't.
    private func expectRedAndClear(_ image: CGImage, keepsTransparency: Bool, _ comment: Comment) throws {
        let bytes = try pixels(image)
        let red = (16 * 64 + 8) * 4, clear = (16 * 64 + 56) * 4
        #expect(bytes[red] > 240 && bytes[red + 1] < 16 && bytes[red + 2] < 16 && bytes[red + 3] == 255, comment)
        if keepsTransparency { #expect(bytes[clear + 3] < 4, comment) }
        else { #expect(bytes[clear] > 240 && bytes[clear + 1] > 240 && bytes[clear + 2] > 240 && bytes[clear + 3] == 255, comment) }
    }

    @Test func listsOnlyFormatsThisMacCanWrite() {
        // An encoder list without AVIF or HEIC, as on a Mac whose ImageIO can't write them: they're left out.
        #expect(ExportFormat.available(encoders: ["public.png", "public.jpeg", "public.tiff"]) == [.png, .jpeg, .tiff, .pdf])
        let encoders = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
        for format in ExportFormat.available where format != .pdf {
            #expect(encoders.contains(format.type.identifier), "\(format.title)")
        }
        #expect(Set([.png, .jpeg, .tiff, .pdf]).isSubset(of: ExportFormat.available))
    }

    @Test(arguments: ExportFormat.available)
    func roundTrips(format: ExportFormat) async throws {
        let raster = try raster()
        let result = try await ImageExporter.shared.encode(raster, options: ExportOptions(format: format))
        let comment = Comment(rawValue: format.title)
        // The preview is the encoded file read back, at full size.
        #expect(result.preview.width == 64 && result.preview.height == 32, comment)
        try expectRedAndClear(result.preview, keepsTransparency: format.keepsTransparency, comment)
        if format == .pdf {
            let document = try #require(CGPDFDocument(CGDataProvider(data: result.data as CFData)!))
            #expect(document.numberOfPages == 1)
            // One page the printed size: 64 × 32 pixels at 144 per inch is 32 × 16 points.
            let box = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
            #expect(abs(box.width - 32) < 0.001 && abs(box.height - 16) < 0.001)
            // The pixels go in losslessly, never as JPEG.
            let text = String(decoding: result.data, as: UTF8.self)
            #expect(text.contains("/FlateDecode") && !text.contains("/DCTDecode"))
            return
        }
        let source = try #require(CGImageSourceCreateWithData(result.data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == format.type.identifier, comment)
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 64 && image.height == 32, comment)
        try expectRedAndClear(image, keepsTransparency: format.keepsTransparency, comment)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyDepth] as? Int == 8, comment)
        #expect(abs((properties[kCGImagePropertyDPIWidth] as? Double ?? 0) - 144) < 0.5, comment)
        if format == .tiff {
            let tiff = try #require(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
            #expect(tiff[kCGImagePropertyTIFFCompression] as? Int == 5)
        }
    }

    @Test func qualityChangesLossyFormats() async throws {
        let context = try #require(CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
            bytesPerRow: 512, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for y in 0..<128 {
            for x in 0..<128 {
                context.setFillColor(CGColor(red: CGFloat((x * 37 + y * 17) % 256) / 255,
                    green: CGFloat((x * 11 + y * 53) % 256) / 255,
                    blue: CGFloat((x * 79 + y * 7) % 256) / 255, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let raster = ExportRaster(image: try #require(context.makeImage()))
        let lossy = ExportFormat.available.filter(\.hasQuality)
        #expect(lossy.contains(.jpeg))
        for format in lossy {
            let low = try await ImageExporter.shared.encode(raster, options: ExportOptions(format: format, quality: 0.1))
            let high = try await ImageExporter.shared.encode(raster, options: ExportOptions(format: format, quality: 1))
            #expect(low.data.count < high.data.count, "\(format.title)")
        }
    }
}
