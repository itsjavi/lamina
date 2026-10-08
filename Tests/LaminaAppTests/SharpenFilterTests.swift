import AppKit
import Testing
@testable import LaminaApp

@MainActor
struct SharpenFilterTests {
    /// 40 × 10, gray 102 on the left half and 153 on the right, opaque.
    private func step() throws -> CGImage {
        let context = try BrushRaster.context(width: 40, height: 10, mask: false)
        context.setFillColor(gray: 0.4, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        context.setFillColor(gray: 0.6, alpha: 1)
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 10))
        return try #require(context.makeImage())
    }

    /// The red channel along the middle row, without any color conversion.
    private func row(_ image: CGImage) -> [Int] {
        let bitmap = NSBitmapImageRep(cgImage: image)
        var pixel = [Int](repeating: 0, count: 4)
        return (0..<image.width).map { x in bitmap.getPixel(&pixel, atX: x, y: 5); return pixel[0] }
    }

    private func run(_ kind: FilterKind, _ settings: FilterSettings, on image: CGImage) throws -> CGImage {
        try PixelFilter.run(FilterJob(kind: kind, image: image, settings: settings, scale: 1, selection: nil, mapping: .identity))
    }

    @Test func unsharpMaskDeepensAnEdgeAndLeavesFlatAreasAlone() throws {
        let source = try step()
        let before = row(source)
        var settings = FilterSettings()
        settings.sharpenAmount = 200
        settings.sharpenRadius = 2
        let after = row(try run(.unsharpMask, settings, on: source))
        #expect(after[19] < before[19] - 10, "the dark side of the edge gets darker")
        #expect(after[20] > before[20] + 10, "and the light side lighter")
        #expect(after[2] == before[2] && after[37] == before[37], "far from it, nothing changes")
        // The edge's own difference from its blur stays under the threshold, so it's left as it was.
        settings.sharpenThreshold = 40
        #expect(row(try run(.unsharpMask, settings, on: source)) == before)
    }

    /// The blur is read the right way up: a barely-there Unsharp Mask on a top-dark, bottom-light image leaves it
    /// nearly as it was, where a blur upside down would swap the halves' surroundings.
    @Test func theBlurLinesUpWithTheLayer() throws {
        let context = try BrushRaster.context(width: 10, height: 40, mask: false)
        context.setFillColor(gray: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 20))
        context.setFillColor(gray: 0.9, alpha: 1)
        context.fill(CGRect(x: 0, y: 20, width: 10, height: 20))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.sharpenAmount = 500
        settings.sharpenRadius = 1
        let result = try run(.unsharpMask, settings, on: source)
        let before = NSBitmapImageRep(cgImage: source), after = NSBitmapImageRep(cgImage: result)
        var a = [Int](repeating: 0, count: 4), b = [Int](repeating: 0, count: 4)
        for y in [2, 10, 30, 37] {
            before.getPixel(&a, atX: 5, y: y)
            after.getPixel(&b, atX: 5, y: y)
            #expect(a[0] == b[0], "row \(y) is far from the edge")
        }
    }

    @Test func highPassKeepsOnlyTheEdgeAboutMiddleGrayAndTheAlpha() throws {
        let context = try BrushRaster.context(width: 40, height: 10, mask: false)
        context.setFillColor(gray: 0.4, alpha: 0.5)
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        context.setFillColor(gray: 0.6, alpha: 0.5)
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 10))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.highPassRadius = 2
        let result = try run(.highPass, settings, on: source)
        let bitmap = NSBitmapImageRep(cgImage: result)
        var pixel = [Int](repeating: 0, count: 4)
        func straight(_ x: Int) -> Int { bitmap.getPixel(&pixel, atX: x, y: 5); return pixel[0] * 255 / max(1, pixel[3]) }
        #expect(abs(straight(2) - 128) <= 2 && abs(straight(37) - 128) <= 2, "flat areas go middle gray")
        #expect(straight(19) < 118 && straight(20) > 138, "the edge stands out either way")
        bitmap.getPixel(&pixel, atX: 10, y: 5)
        #expect(abs(pixel[3] - 128) <= 1, "the alpha is left as it was")
    }

    @Test func neitherGrowsTheLayer() {
        // Neither spreads past the layer.
        #expect(FilterEdit.blurMargin(.unsharpMask, FilterSettings()) == 0 && FilterEdit.blurMargin(.highPass, FilterSettings()) == 0)
    }

    /// Through the Filter menu: only inside the selection, the layer keeping its size and place, as one undo step.
    @Test func bothKeepToTheSelectionAndTheLayersSize() async throws {
        for kind in [FilterKind.unsharpMask, .highPass] {
            let session = EditorSession()
            session.createDocument(width: 40, height: 10)
            let source = try step()
            session.insert(ImportedImage(image: source, thumbnail: source, name: "Step"))
            let place = try #require(session.activeLayer?.transform)
            // The dark half: the edge's dark side is inside the selection, its light side outside.
            session.document?.selection = DocumentSelection(path: CGPath(rect: CGRect(x: 0, y: 0, width: 20, height: 10), transform: nil))
            session.beginFilter(kind)
            var settings = FilterSettings()
            settings.sharpenAmount = 200
            settings.sharpenRadius = 2
            settings.highPassRadius = 2
            session.updateFilter(settings, preview: true)
            let count = session.history.undoCount
            await session.commitFilter()
            #expect(session.history.undoCount == count + 1)
            let result = try #require(session.activeLayer?.asset?.image)
            #expect(result.width == 40 && result.height == 10 && session.activeLayer?.transform == place, "\(kind)")
            let before = row(source), after = row(result)
            #expect(after[19] != before[19], "\(kind) changes the selected side of the edge")
            #expect(Array(after[20...]) == Array(before[20...]), "\(kind) leaves the rest alone")
        }
    }
}