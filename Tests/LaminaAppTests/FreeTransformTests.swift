import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The Free Transform bar's model: the reference point, Interpolation's names, a handle drag waiting for Commit,
/// and Edit ▸ Transform's Flip and Distort.
@MainActor
struct FreeTransformTests {
    /// A 400 × 300 document with a red 100 × 100 layer in the middle (150–250 × 100–200), the Move tool, and a canvas.
    private func makeCanvas() throws -> (EditorSession, CanvasView, NSWindow) {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        let context = try BrushRaster.context(width: 100, height: 100, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Red"))
        session.selectTool(.move)
        let view = CanvasView(session: session)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = view
        session.viewport.resize(to: view.bounds.size, backingScale: 1, documentSize: try #require(session.document?.size))
        view.synchronizeDisplay()
        return (session, view, window)
    }

    /// Drags in document pixels, holding Control so nothing snaps.
    private func drag(_ session: EditorSession, _ view: CanvasView, in window: NSWindow, from start: CGPoint, to end: CGPoint) throws {
        let size = try #require(session.document?.size)
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            let spot = session.viewport.viewPoint(from: point, documentSize: size)
            return try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: spot.x, y: view.bounds.height - spot.y),
                modifierFlags: .control, timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, at: start))
        view.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)))
        view.mouseDragged(with: try event(.leftMouseDragged, at: end))
        view.mouseUp(with: try event(.leftMouseUp, at: end))
    }

    private func near(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01 }

    @Test func typedValuesKeepTheReferencePointInPlace() {
        var box = LayerTransform(origin: CGPoint(x: 10, y: 20), size: CGSize(width: 100, height: 50))
        box.rotation = 30
        for unit in LayerTransform.referencePoints {
            let anchor = box.point(unit)
            #expect(near(box.resized(to: CGSize(width: 40, height: 80), keeping: unit).point(unit), anchor), "\(unit)")
            #expect(near(box.rotated(to: -45, about: unit).point(unit), anchor), "\(unit)")
            let moved = box.moving(unit, to: CGPoint(x: 300, y: 7))
            #expect(near(moved.point(unit), CGPoint(x: 300, y: 7)) && moved.size == box.size && moved.rotation == 30)
        }
        #expect(LayerTransform.referencePoints.count == 9 && LayerTransform.referencePoints[4] == LayerTransform.centerReference)
        #expect(ReferencePointPicker.name(of: CGPoint(x: 0, y: 0)) == "Top Left")
        #expect(ReferencePointPicker.name(of: CGPoint(x: 1, y: 0.5)) == "Middle Right")
        #expect(ReferencePointPicker.name(of: LayerTransform.centerReference) == "Center")
    }

    @Test func rotationDragsTurnAboutTheReferencePoint() {
        let original = LayerTransform(origin: CGPoint(x: 100, y: 100), size: CGSize(width: 100, height: 100))
        let corner = CGPoint(x: 0, y: 0)
        let drag = TransformDrag(original: original, start: CGPoint(x: 300, y: 100), mode: .rotate, pivot: corner)
        let turned = drag.updated(to: CGPoint(x: 100, y: 300), lockRatio: true, shift: false)
        #expect(abs(turned.rotation - 90) < 0.001)
        #expect(near(turned.point(corner), original.point(corner)), "the top left corner stays put")
        let centered = TransformDrag(original: original, start: CGPoint(x: 300, y: 150), mode: .rotate)
            .updated(to: CGPoint(x: 150, y: 300), lockRatio: true, shift: false)
        #expect(near(centered.center, original.center), "the middle by default")
    }

    @Test func interpolationNamesMapTheSavedSampling() {
        #expect(LayerSampling.allCases.map(\.interpolationName) == ["Nearest Neighbor", "Bilinear", "Bicubic"])
        #expect(LayerSampling.allCases.map(\.rawValue) == ["Nearest", "Smooth", "High quality"], "what projects save")
    }

    /// A handle starts a Free Transform that waits, as in familiar editors: more drags join it, Commit applies it all
    /// as one undo step, and Cancel puts the layer back.
    @Test func aHandleDragWaitsForCommitAsOneUndoStep() throws {
        let (session, view, window) = try makeCanvas()
        let original = try #require(session.activeLayer?.transform)
        let count = session.history.undoCount
        try drag(session, view, in: window, from: CGPoint(x: 250, y: 200), to: CGPoint(x: 290, y: 240))
        #expect(session.transformEdit?.persistent == true, "the bar turns into the Free Transform bar")
        #expect(session.activeLayer?.transform == original, "nothing applied yet")
        #expect(session.history.undoCount == count)
        let first = try #require(session.transformEdit?.draft)
        #expect(first.size.width > original.size.width)
        try drag(session, view, in: window, from: CGPoint(x: 150, y: 100), to: CGPoint(x: 130, y: 80))
        let second = try #require(session.transformEdit?.draft)
        #expect(second.size.width > first.size.width, "the second drag joins the same edit")
        session.commitTransform()
        #expect(session.transformEdit == nil)
        #expect(session.activeLayer?.transform == second)
        #expect(session.history.undoCount == count + 1)
        session.undo()
        #expect(session.activeLayer?.transform == original)

        try drag(session, view, in: window, from: CGPoint(x: 250, y: 200), to: CGPoint(x: 290, y: 240))
        session.cancelTransform()
        #expect(session.activeLayer?.transform == original && session.history.undoCount == count)
    }

    @Test func flipDuringAFreeTransformTurnsTheBoxOverAsPartOfIt() throws {
        let (session, _, _) = try makeCanvas()
        let original = try #require(session.activeLayer?.transform)
        let count = session.history.undoCount
        session.transformCommand()
        session.transformReference = CGPoint(x: 0, y: 0.5)
        session.flipTransform(horizontally: true)
        let draft = try #require(session.transformEdit?.draft)
        #expect(draft.flipX && draft.origin.x == original.origin.x - original.size.width, "mirrored across the left edge")
        #expect(session.activeLayer?.transform == original && session.history.undoCount == count)
        session.commitTransform()
        #expect(session.history.undoCount == count + 1)
        #expect(session.activeLayer?.transform.flipX == true)
        // Without a Free Transform, the layer flips at once about its middle, one undo step.
        session.flipTransform(horizontally: true)
        #expect(session.activeLayer?.transform.flipX == false && session.transformEdit == nil)
        #expect(session.history.undoCount == count + 2)
    }

    @Test func distortStartsWithoutADrag() async throws {
        let (session, _, _) = try makeCanvas()
        #expect(session.canDistort)
        await session.distortCommand()
        #expect(session.transformEdit?.persistent == true && session.transformEdit?.corners?.count == 4)
        #expect(!session.canDistort && !session.canFlipTransform, "already distorting; no box to flip")
        session.cancelTransform()
        #expect(session.transformEdit == nil)
    }

    /// Several layers transform as one box; Interpolation chosen for it goes to each of them.
    @Test func interpolationChosenForSeveralLayersReachesEachOne() throws {
        let (session, _, _) = try makeCanvas()
        let first = try #require(session.activeLayerID)
        let context = try BrushRaster.context(width: 50, height: 50, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Blue"))
        let second = try #require(session.activeLayerID)
        session.selectLayers([first, second], primary: second)
        session.transformCommand()
        session.changeTransformValue { $0.sampling = .nearest }
        session.commitTransform()
        let samplings = session.document?.layers.filter { [first, second].contains($0.id) }.map(\.transform.sampling)
        #expect(samplings == [.nearest, .nearest])
    }
}
