import AppKit
import Testing
@testable import LaminaApp

/// Filter ▸ Liquify… picks the Liquify brush, outside the toolbar; Done keeps its strokes and Cancel takes them back,
/// and either returns to the tool chosen before.
@MainActor
struct LiquifyTests {
    /// Vertical stripes, so a push sideways changes pixels; the Brush chosen.
    private func session() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 120, height: 80)
        let context = try BrushRaster.context(width: 120, height: 80, mask: false)
        for stripe in 0..<12 {
            let gray = CGFloat(stripe % 2)
            context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
            context.fill(CGRect(x: stripe * 10, y: 0, width: 10, height: 80))
        }
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Stripes"))
        session.selectTool(.brush)
        return session
    }

    private func push(_ session: EditorSession, at y: CGFloat) {
        session.beginBrush(at: CGPoint(x: 20, y: y))
        for x in stride(from: 25, through: 100, by: 5) { session.continueBrush(at: CGPoint(x: CGFloat(x), y: y)) }
        session.finishBrushImmediately()
    }

    @Test func theMenuPicksTheLiquifyBrushAndDoneKeepsTheStrokes() throws {
        let session = try session()
        let before = session.activeLayer?.asset?.image
        #expect(session.canLiquify)
        session.beginLiquify()
        #expect(session.tool == .liquify && session.tool.isBrushTool && !session.canLiquify)
        push(session, at: 40)
        #expect(session.brushError == nil && session.history.undoName == "Liquify")
        #expect(session.activeLayer?.asset?.image !== before)
        session.finishLiquify()
        #expect(session.tool == .brush)
        #expect(session.activeLayer?.asset?.image !== before && session.history.undoName == "Liquify")
    }

    @Test func cancelTakesBackEveryStrokeSinceLiquifyWasChosenAndRedoBringsThemBack() throws {
        let session = try session()
        session.brushSettings.diameter = 9
        push(session, at: 10)
        let painted = session.activeLayer?.asset?.image
        let steps = session.history.position
        session.selectTool(.eraser)
        session.beginLiquify()
        push(session, at: 30)
        push(session, at: 60)
        #expect(session.history.position == steps + 2)
        session.cancelLiquify()
        #expect(session.tool == .eraser)
        #expect(session.activeLayer?.asset?.image === painted, "the Brush stroke made before stays")
        #expect(session.history.position == steps && session.history.canRedo)
        session.redo()
        #expect(session.history.undoName == "Liquify")
    }

    /// Liquify keeps a tip of its own, and leaving it by picking another tool keeps its strokes too.
    @Test func itKeepsItsOwnTipAndAnyToolKeyLeavesIt() throws {
        let session = try session()
        session.brushSettings.diameter = 15
        session.beginLiquify()
        session.brushSettings.diameter = 120
        push(session, at: 40)
        let liquified = session.activeLayer?.asset?.image
        session.pressToolKey("v")
        #expect(session.tool == .move && session.liquifyEntry == nil)
        #expect(session.activeLayer?.asset?.image === liquified)
        session.selectTool(.brush)
        #expect(session.brushSettings.diameter == 15)
        session.beginLiquify()
        #expect(session.brushSettings.diameter == 120)
        session.cancelLiquify()
        #expect(session.tool == .brush && session.activeLayer?.asset?.image === liquified, "nothing to take back")
    }

    /// On the canvas, Escape is Cancel and Return is Done.
    @Test func escapeCancelsAndReturnIsDone() throws {
        let session = try session()
        let before = session.activeLayer?.asset?.image
        let canvas = CanvasView(session: session)
        func press(_ characters: String, code: UInt16) {
            canvas.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code)!)
        }
        session.beginLiquify()
        push(session, at: 40)
        press("\u{1b}", code: 53)
        #expect(session.tool == .brush && session.activeLayer?.asset?.image === before)
        session.beginLiquify()
        push(session, at: 40)
        press("\r", code: 36)
        #expect(session.tool == .brush && session.activeLayer?.asset?.image !== before)
    }

    /// Liquify needs a layer's own pixels: the menu item waits for one.
    @Test func itNeedsPixelsToPush() throws {
        let empty = EditorSession()
        empty.createDocument(width: 40, height: 40, emptyLayer: true)
        #expect(!empty.canLiquify)
        let masked = try session()
        masked.addLayerMask(revealing: true)
        #expect(masked.isMaskSelected && !masked.canLiquify)
        #expect(ShortcutDefinition.all.contains { $0.isMenu && $0.title == "Liquify" && $0.original == ShortcutChord("x", 9) })
    }
}
