import AppKit
import Testing
@testable import Compositor

@MainActor
struct PaintBucketTests {
    private let green = PaletteColor(red: 0, green: 1, blue: 0)

    private func makeSession(width: Int = 100, height: Int = 40) -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: width, height: height, emptyLayer: true)
        session.selectTool(.paintBucket)
        session.setPaletteColor(green, background: false)
        return session
    }
    /// Adds a layer of `width` × `height` pixels, each `color(x, y)` as straight RGBA, stored with `alphaInfo`.
    private func addImage(_ session: EditorSession, width: Int = 100, height: Int = 40,
                          alphaInfo: CGImageAlphaInfo = .premultipliedLast, _ color: (Int, Int) -> [UInt8]) throws {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = color(x, y)
                for channel in 0..<4 { bytes[(y * width + x) * 4 + channel] = pixel[channel] }
            }
        }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Pixels"))
        session.selectTool(.paintBucket)
    }
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (y * image.width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }
    private func render(_ session: EditorSession) async throws -> CGImage {
        try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
    }
    private let red: [UInt8] = [255, 0, 0, 255], blue: [UInt8] = [0, 0, 255, 255]

    @Test func fillsTheClickedAreaAsOneUndoStep() async throws {
        let session = makeSession()
        try addImage(session) { x, _ in x < 50 ? red : blue }
        session.bucketSettings.antialiased = false
        let count = session.history.undoCount
        await session.paintBucket(at: CGPoint(x: 10, y: 10))
        #expect(session.history.undoCount == count + 1 && session.history.undoName == "Paint Bucket")
        let result = try await render(session)
        #expect(try pixel(result, x: 0, y: 0) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 49, y: 39) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 50, y: 0) == [0, 0, 255, 255])
        session.undo()
        #expect(try pixel(try await render(session), x: 10, y: 10) == [255, 0, 0, 255])
    }

    @Test func toleranceAndContiguousDecideTheArea() async throws {
        let session = makeSession()
        // Red, a blue wall, then a red 20 levels darker.
        try addImage(session) { x, _ in x < 30 ? red : x < 60 ? blue : [235, 0, 0, 255] }
        session.bucketSettings.antialiased = false
        await session.paintBucket(at: CGPoint(x: 5, y: 5))
        var result = try await render(session)
        #expect(try pixel(result, x: 20, y: 20) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 80, y: 20) == [235, 0, 0, 255], "the wall stops a contiguous fill")
        session.undo()
        session.bucketSettings.contiguous = false
        session.bucketSettings.tolerance = 10
        await session.paintBucket(at: CGPoint(x: 5, y: 5))
        result = try await render(session)
        #expect(try pixel(result, x: 80, y: 20) == [235, 0, 0, 255], "20 levels off is past a tolerance of 10")
        session.undo()
        session.bucketSettings.tolerance = 32
        await session.paintBucket(at: CGPoint(x: 5, y: 5))
        result = try await render(session)
        #expect(try pixel(result, x: 80, y: 20) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 45, y: 20) == [0, 0, 255, 255])
    }

    @Test func transparentPixelsMatchWhateverColorTheyHide() async throws {
        let session = makeSession()
        // Fully transparent pixels that once were different colors, stored unpremultiplied as a PNG may keep them.
        try addImage(session, alphaInfo: .last) { x, y in x < 50 ? [UInt8(x * 5), UInt8(y * 6), 200, 0] : blue }
        session.bucketSettings.antialiased = false
        await session.paintBucket(at: CGPoint(x: 10, y: 10))
        let result = try await render(session)
        #expect(try pixel(result, x: 0, y: 0) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 49, y: 39) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 75, y: 20) == [0, 0, 255, 255])
    }

    @Test func aBlankLayerFillsWholeAtTheChosenOpacity() async throws {
        let session = makeSession()
        #expect(session.activeLayer?.asset == nil)
        session.bucketSettings.opacity = 0.5
        await session.paintBucket(at: CGPoint(x: 50, y: 20))
        let result = try await render(session)
        for (x, y) in [(0, 0), (99, 39), (50, 20)] {
            let value = try pixel(result, x: x, y: y)
            #expect(value[0] == 0 && abs(value[1] - 128) <= 1 && value[2] == 0 && abs(value[3] - 128) <= 1)
        }
    }

    @Test func antialiasingSoftensOnlyTheEdge() async throws {
        let session = makeSession()
        try addImage(session) { x, _ in x < 50 ? red : blue }
        await session.paintBucket(at: CGPoint(x: 10, y: 10))
        let result = try await render(session)
        #expect(try pixel(result, x: 10, y: 20) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 70, y: 20) == [0, 0, 255, 255])
        // Either side of the edge the green blends with what was there: mostly green inside, a little outside.
        let inside = try pixel(result, x: 49, y: 20), outside = try pixel(result, x: 50, y: 20)
        #expect(inside[1] > 128 && inside[1] < 255 && inside[0] > 0)
        #expect(outside[1] > 0 && outside[1] < 128 && outside[2] > 128)
    }

    @Test func fillsOnlyInsideTheSelection() async throws {
        let session = makeSession()
        session.selectionAntialiased = false
        session.applySelection(CGPath(rect: CGRect(x: 20, y: 10, width: 30, height: 20), transform: nil), mode: .replace, name: "Select")
        // The click is outside the selection: the area still reaches it.
        await session.paintBucket(at: CGPoint(x: 5, y: 5))
        let result = try await render(session)
        #expect(try pixel(result, x: 30, y: 20) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 5, y: 5)[3] == 0)
        #expect(try pixel(result, x: 60, y: 20)[3] == 0)
    }

    @Test func followsAScaledLayer() async throws {
        let session = makeSession()
        // 50 × 20 pixels stretched 2× over the canvas.
        try addImage(session, width: 50, height: 20) { x, _ in x < 25 ? red : blue }
        var transform = try #require(session.activeLayer).transform
        transform.origin = .zero
        transform.size = CGSize(width: 100, height: 40)
        session.selectTool(.move)
        session.beginTransform()
        session.previewTransform(transform)
        session.commitTransform()
        session.selectTool(.paintBucket)
        session.bucketSettings.antialiased = false
        await session.paintBucket(at: CGPoint(x: 10, y: 30))
        #expect(session.activeLayer?.asset?.image.width == 50, "filled at the layer's own resolution")
        let result = try await render(session)
        #expect(try pixel(result, x: 2, y: 2) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 47, y: 37) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 52, y: 20) == [0, 0, 255, 255])
    }

    @Test func followsARotatedLayer() async throws {
        let session = makeSession()
        // A 40 × 40 red square turned 45° about the canvas center: a diamond reaching 28 px from it.
        try addImage(session, width: 40, height: 40) { _, _ in red }
        var transform = try #require(session.activeLayer).transform
        transform.origin = CGPoint(x: 30, y: 0)
        transform.rotation = 45
        session.selectTool(.move)
        session.beginTransform()
        session.previewTransform(transform)
        session.commitTransform()
        session.selectTool(.paintBucket)
        // The diamond runs past the canvas's top and bottom, splitting the transparent area in two: clicking the
        // left part fills just that, on pixels the layer grows to hold.
        await session.paintBucket(at: CGPoint(x: 2, y: 2))
        let result = try await render(session)
        #expect(try pixel(result, x: 2, y: 2) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 2, y: 38) == [0, 255, 0, 255])
        #expect(try pixel(result, x: 92, y: 20)[3] == 0, "the right part isn't connected")
        #expect(try pixel(result, x: 50, y: 20) == [255, 0, 0, 255])
        #expect(try pixel(result, x: 50, y: 8) == [255, 0, 0, 255])
    }

    @Test func aMaskTargetReadsAndFillsTheMask() async throws {
        let session = makeSession()
        try addImage(session) { x, _ in x < 50 ? red : blue }
        let id = try #require(session.activeLayerID)
        session.addLayerMask(revealing: true)
        session.selectLayerTarget(id, mask: true)
        // Hide the top half: the mask's palette is black (hide) on white (reveal).
        session.selectionAntialiased = false
        session.applySelection(CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 20), transform: nil), mode: .replace, name: "Select")
        await session.fillSelection(with: .foreground)
        session.deselect()
        #expect(try pixel(try await render(session), x: 75, y: 5)[3] == 0)
        // White fills the black half of the mask, across both colors of the layer: the mask is what's read.
        session.swapPaletteColors()
        session.bucketSettings.antialiased = false
        await session.paintBucket(at: CGPoint(x: 10, y: 5))
        #expect(session.history.undoName == "Paint Bucket Mask")
        let result = try await render(session)
        #expect(try pixel(result, x: 10, y: 5) == [255, 0, 0, 255])
        #expect(try pixel(result, x: 75, y: 5) == [0, 0, 255, 255])
    }

    @Test func liveTextIsRecoloredNotRasterized() async throws {
        let session = EditorSession()
        session.createDocument(width: 400, height: 200, emptyLayer: true)
        session.selectTool(.type)
        session.beginText(at: CGPoint(x: 30, y: 60))
        var draft = try #require(session.textDraft)
        draft.style.content = "Fill"
        #expect(session.applyText(draft))
        session.selectTool(.paintBucket)
        session.setPaletteColor(green, background: false)
        await session.paintBucket(at: CGPoint(x: 5, y: 5))
        #expect(session.history.undoName == "Fill Text")
        let style = try #require(session.activeLayer?.liveText?.style)
        #expect(style.red == 0 && style.green == 1 && style.blue == 0)
    }

    @Test func gPicksTheLastFillToolAndShiftGSwitches() {
        let session = makeSession()
        session.selectTool(.gradient)
        session.toggleFillTool()
        #expect(session.tool == .paintBucket)
        session.typeOpacityDigit(5)
        #expect(session.bucketSettings.opacity == 0.5)
        session.selectTool(.move)
        session.pressGradientKey()
        #expect(session.tool == .paintBucket)
        session.toggleFillTool()
        #expect(session.tool == .gradient)
        session.selectTool(.move)
        session.pressGradientKey()
        #expect(session.tool == .gradient)
    }
}
