import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Flow as Photoshop's: each dab lays its share of the tip, a pass builds up over the few dabs that cover a point,
/// going over the same place again builds further, and Opacity caps the stroke.
@MainActor
struct BrushFlowTests {
    private let size = CGSize(width: 600, height: 200)

    private func stroke(diameter: CGFloat = 60, hardness: CGFloat = 1, opacity: CGFloat = 1, flow: CGFloat = 1,
                        useGPU: Bool = true) throws -> BrushStroke {
        let session = EditorSession()
        session.createDocument(width: Int(size.width), height: Int(size.height))
        session.addBlankLayer()
        var settings = BrushSettings(diameter: diameter, hardness: hardness, red: 1, green: 1, blue: 1, opacity: opacity)
        settings.flow = flow
        return try BrushStroke(layer: #require(session.activeLayer), mask: false, settings: settings, canvas: size, useGPU: useGPU)
    }
    private func trace(_ stroke: BrushStroke, _ points: [CGPoint], step: CGFloat = 7) throws {
        try stroke.append(points[0])
        for (a, b) in zip(points, points.dropFirst()) {
            let count = max(1, Int(ceil(hypot(b.x - a.x, b.y - a.y) / step)))
            for index in 1...count {
                let t = CGFloat(index) / CGFloat(count)
                try stroke.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        try stroke.flush()
    }
    private func raster(_ stroke: BrushStroke) throws -> CGContext {
        let context = try BrushRaster.context(width: Int(size.width), height: Int(size.height), mask: false)
        LayerRenderer.drawBrushPreview(nil, transform: stroke.paintTransform, center: stroke.paintTransform.center,
            scale: 1, opacity: 1, blendMode: .normal, mask: nil, patches: stroke.patches,
            pixelWidth: stroke.width, pixelHeight: stroke.height, paintingMask: false, in: context)
        return context
    }
    private func alpha(_ context: CGContext, _ x: Int, _ y: Int) -> Int {
        Int(context.data!.assumingMemoryBound(to: UInt8.self)[y * context.bytesPerRow + x * 4 + 3])
    }
    /// One pass, left to right through the middle.
    private let pass = [CGPoint(x: 60, y: 100), CGPoint(x: 540, y: 100)]

    @Test func theGPUBrushCompiles() {
        #expect(MetalBrushCoverage.shared != nil, "the shader is compiled at run time; a mistake would fall back silently")
    }

    @Test func aClickLaysFlowsShareOfTheTip() throws {
        for useGPU in [true, false] {
            for hardness: CGFloat in [1, 0] {
                let click = try stroke(hardness: hardness, flow: 0.5, useGPU: useGPU)
                try trace(click, [CGPoint(x: 300, y: 100)])
                #expect(abs(alpha(try raster(click), 300, 100) - 128) <= 2, "GPU \(useGPU), hardness \(hardness)")
            }
        }
    }

    /// A pass lays one dab every quarter of the tip's width, so the middle of a hard line gets four:
    /// 1 − (1 − flow)⁴, as in Photoshop at its default spacing.
    @Test func aPassBuildsUpOverPhotoshopsDabs() throws {
        for flow: CGFloat in [0.1, 0.3, 0.5] {
            let expected = Int((255 * (1 - pow(1 - flow, 4))).rounded())
            let gpu = try stroke(flow: flow)
            try trace(gpu, pass)
            #expect(abs(alpha(try raster(gpu), 300, 100) - expected) <= 3, "flow \(flow)")
            // The software brush stamps those dabs: three to five reach a point, depending on where they fall.
            let cpu = try stroke(flow: flow, useGPU: false)
            try trace(cpu, pass)
            let low = Int(255 * (1 - pow(1 - flow, 3))), high = Int((255 * (1 - pow(1 - flow, 5))).rounded(.up))
            #expect((low...high).contains(alpha(try raster(cpu), 300, 100)), "flow \(flow)")
        }
        // Low flow is still well short of full after a pass, and the line's edges are lighter than its middle.
        let faint = try stroke(flow: 0.1)
        try trace(faint, pass)
        let line = try raster(faint)
        #expect(alpha(line, 300, 100) < 100 && alpha(line, 300, 125) < alpha(line, 300, 100))
    }

    @Test func goingOverItAgainInTheStrokeBuildsUpToTheOpacity() throws {
        for useGPU in [true, false] {
            for hardness: CGFloat in [1, 0.5] {
                let once = try stroke(hardness: hardness, flow: 0.2, useGPU: useGPU)
                try trace(once, pass)
                let again = try stroke(hardness: hardness, flow: 0.2, useGPU: useGPU)
                try trace(again, pass + [CGPoint(x: 60, y: 100), CGPoint(x: 540, y: 100), CGPoint(x: 60, y: 100)])
                let single = alpha(try raster(once), 300, 100), built = alpha(try raster(again), 300, 100)
                #expect(built > single + 30, "GPU \(useGPU), hardness \(hardness): \(single) → \(built)")

                // Opacity caps it however often the stroke goes over the same place, and scales each dab with it.
                let capped = try stroke(hardness: hardness, opacity: 0.5, flow: 0.5, useGPU: useGPU)
                try trace(capped, [CGPoint(x: 300, y: 100)])
                #expect(abs(alpha(try raster(capped), 300, 100) - 64) <= 2)
                let scrubbed = try stroke(hardness: hardness, opacity: 0.5, flow: 0.5, useGPU: useGPU)
                try trace(scrubbed, pass + [CGPoint(x: 60, y: 100), CGPoint(x: 540, y: 100), CGPoint(x: 60, y: 100), CGPoint(x: 540, y: 100)])
                let raster = try raster(scrubbed)
                #expect(abs(alpha(raster, 300, 100) - 128) <= 2)
                let bytes = raster.data!.assumingMemoryBound(to: UInt8.self)
                #expect(stride(from: 3, to: raster.bytesPerRow * raster.height, by: 4).allSatisfy { bytes[$0] <= 128 })
            }
        }
    }

    /// Flow at 100% is the brush as it always was, and just below that it hardly differs: there's no jump.
    @Test func fullFlowIsTheBrushWithoutFlow() throws {
        for hardness: CGFloat in [1, 0.5, 0] {
            let full = try stroke(hardness: hardness), almost = try stroke(hardness: hardness, flow: 0.99)
            try trace(full, pass)
            try trace(almost, pass)
            let a = try raster(full), b = try raster(almost)
            for y in stride(from: 100, to: 132, by: 2) {
                #expect(abs(alpha(a, 300, y) - alpha(b, 300, y)) <= 12, "hardness \(hardness), row \(y)")
            }
        }
    }

    @Test func eraseAndMaskPaintingFollowFlow() async throws {
        func session(then tool: NavigationTool = .brush) -> EditorSession {
            let session = EditorSession()
            session.createDocument(width: 80, height: 80)
            session.addBlankLayer()
            session.selectTool(.brush)
            session.brushSettings = BrushSettings(diameter: 200, hardness: 1, red: 1, green: 0, blue: 0)
            session.beginBrush(at: CGPoint(x: 40, y: 40))
            session.finishBrushImmediately()
            session.selectTool(tool)
            session.brushSettings.diameter = 20
            session.brushSettings.hardness = 1
            session.brushSettings.flow = 0.5
            return session
        }
        func alpha(_ session: EditorSession) async throws -> (center: Int, corner: Int) {
            let image = try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
            let bitmap = NSBitmapImageRep(cgImage: image)
            var pixel = [Int](repeating: 0, count: 4), corner = [Int](repeating: 0, count: 4)
            bitmap.getPixel(&pixel, atX: 40, y: 40)
            bitmap.getPixel(&corner, atX: 5, y: 5)
            return (pixel[3], corner[3])
        }
        let erasing = session(then: .eraser)
        erasing.beginBrush(at: CGPoint(x: 40, y: 40))
        erasing.finishBrushImmediately()
        let erased = try await alpha(erasing)
        #expect(abs(erased.center - 128) <= 2 && erased.corner == 255)

        let masking = session()
        masking.addLayerMask(revealing: true)
        masking.selectLayerTarget(try #require(masking.activeLayerID), mask: true)
        masking.foregroundColor = .black
        masking.beginBrush(at: CGPoint(x: 40, y: 40))
        masking.finishBrushImmediately()
        let masked = try await alpha(masking)
        #expect(abs(masked.center - 128) <= 2 && masked.corner == 255)
    }

    /// Flow belongs to the Brush (and Eraser, Dodge and Burn), as in Photoshop: the other brush tools lay their full tip.
    @Test func onlyTheBrushUsesFlow() {
        let session = EditorSession()
        session.createDocument(width: 80, height: 80)
        session.addBlankLayer()
        session.selectTool(.brush)
        session.brushSettings.flow = 0.3
        session.beginBrush(at: CGPoint(x: 30, y: 40))
        #expect(session.brushStroke?.settings.flow == 0.3)
        session.cancelBrush()
        session.selectTool(.eraser)
        session.beginBrush(at: CGPoint(x: 30, y: 40))
        #expect(session.brushStroke?.settings.flow == 0.3 && session.brushStroke?.settings.erasing == true)
        session.cancelBrush()
        session.selectTool(.spotHealing)
        session.beginBrush(at: CGPoint(x: 30, y: 40))
        #expect(session.brushStroke?.settings.flow == 1)
        session.cancelBrush()
    }
}
