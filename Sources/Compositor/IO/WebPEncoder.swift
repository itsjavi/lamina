import Accelerate
import CoreGraphics
import Foundation
import libwebp

/// WebP export, which ImageIO can read but not write: libwebp's lossy encoder, which keeps the alpha losslessly.
nonisolated enum WebPEncoder {
    /// The largest side a WebP can have (libwebp's WEBP_MAX_DIMENSION).
    static let maxSide = 16_383

    /// `image` as a WebP at `quality` (0–1), in sRGB, with its transparency.
    static func encode(_ image: CGImage, quality: Double) throws -> Data {
        let width = image.width, height = image.height
        guard width <= maxSide, height <= maxSide else { throw ExportError.webPTooLarge }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let pixels = context.data else { throw ExportError.render }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // libwebp takes straight RGBA; Core Graphics only draws premultiplied, so that is undone in place.
        var buffer = vImage_Buffer(data: pixels, height: vImagePixelCount(height), width: vImagePixelCount(width),
                                   rowBytes: context.bytesPerRow)
        guard vImageUnpremultiplyData_RGBA8888(&buffer, &buffer, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            throw ExportError.render
        }
        var output: UnsafeMutablePointer<UInt8>?
        defer { WebPFree(output) }
        let size = WebPEncodeRGBA(pixels.assumingMemoryBound(to: UInt8.self), Int32(width), Int32(height),
                                  Int32(context.bytesPerRow), Float(min(1, max(0, quality)) * 100), &output)
        guard size > 0, let output else { throw ExportError.encode }
        return Data(bytes: output, count: size)
    }
}
