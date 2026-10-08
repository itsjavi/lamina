import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Pen pressure, simulated: what a tablet's events would carry. A real tablet still needs checking by hand.
@MainActor
struct PenPressureTests {
    private func session(hardness: CGFloat = 1) -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 300, height: 100)
        session.addBlankLayer()
        session.selectTool(.brush)
        session.brushSettings = BrushSettings(diameter: 40, hardness: hardness, red: 1, green: 0, blue: 0)
        return session
    }

    /// The canvas as exported.
    private func canvas(_ session: EditorSession) async throws -> NSBitmapImageRep {
        NSBitmapImageRep(cgImage: try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image)
    }
    private func alpha(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> Int {
        var pixel = [Int](repeating: 0, count: 4)
        bitmap.getPixel(&pixel, atX: x, y: y)
        return pixel[3]
    }
    /// How many rows of column `x` the stroke covers.
    private func thickness(_ bitmap: NSBitmapImageRep, _ x: Int) -> Int {
        (0..<bitmap.pixelsHigh).filter { alpha(bitmap, x, $0) > 127 }.count
    }

    /// A left-to-right stroke along y = 50, its pressure easing from `from` to `to`; nil is a mouse.
    private func stroke(_ session: EditorSession, from: CGFloat?, to: CGFloat?) {
        session.beginBrush(at: CGPoint(x: 30, y: 50), pressure: from)
        for step in 1...24 {
            let t = CGFloat(step) / 24
            session.continueBrush(at: CGPoint(x: 30 + 240 * t, y: 50), pressure: from.map { $0 + ((to ?? $0) - $0) * t })
        }
        session.finishBrushImmediately()
    }

    @Test func pressureSetsTheSizeWhenAsked() async throws {
        for hardness: CGFloat in [1, 0.8] {
            let session = session(hardness: hardness)
            session.brushSettings.pressureSize = true
            stroke(session, from: 1, to: 0.25)
            let bitmap = try await canvas(session)
            let start = thickness(bitmap, 40), end = thickness(bitmap, 260)
            #expect(abs(start - 40) <= 4, "full pressure paints the full size: \(start)")
            #expect(end < 16 && end >= 7, "a quarter of the pressure, about a quarter of the size: \(end)")
            #expect(thickness(bitmap, 150) < start && thickness(bitmap, 150) > end)
        }
    }

    @Test func pressureSetsTheOpacityAndTheStrokeNeverPassesItsFirmestPress() async throws {
        for hardness: CGFloat in [1, 0] {
            for flow: CGFloat in [1, 0.6] {
                let session = session(hardness: hardness)
                session.brushSettings.pressureOpacity = true
                session.brushSettings.flow = flow
                // Twice over the same line: it builds no further than the press.
                session.beginBrush(at: CGPoint(x: 30, y: 50), pressure: 0.5)
                for x in [270, 30, 270, 150] { session.continueBrush(at: CGPoint(x: CGFloat(x), y: 50), pressure: 0.5) }
                session.finishBrushImmediately()
                let bitmap = try await canvas(session)
                #expect(abs(alpha(bitmap, 150, 50) - 128) <= 4, "hardness \(hardness), flow \(flow): \(alpha(bitmap, 150, 50))")
                #expect((0..<300).allSatisfy { alpha(bitmap, $0, 50) <= 132 })
            }
        }
    }

    /// Mouse and trackpad strokes are unchanged whatever the buttons say, and a pen's pressure is ignored with them off.
    @Test func aMouseOrTheButtonsOffPaintAsBefore() async throws {
        for hardness: CGFloat in [1, 0.5] {
            for flow: CGFloat in [1, 0.4] {
                let plain = session(hardness: hardness)
                plain.brushSettings.flow = flow
                stroke(plain, from: nil, to: nil)
                let expected = try await canvas(plain).representation(using: .png, properties: [:])
                let mouse = session(hardness: hardness)
                mouse.brushSettings.flow = flow
                mouse.brushSettings.pressureSize = true
                mouse.brushSettings.pressureOpacity = true
                stroke(mouse, from: nil, to: nil)
                let pen = session(hardness: hardness)
                pen.brushSettings.flow = flow
                stroke(pen, from: 0.2, to: 0.6)
                for other in [try await canvas(mouse), try await canvas(pen)] {
                    #expect(other.representation(using: .png, properties: [:]) == expected, "hardness \(hardness), flow \(flow)")
                }
            }
        }
    }

    /// The release carries no pressure: the stroke ends at the last pen pressure, not a full-size blot.
    @Test func theReleaseKeepsTheLastPressure() async throws {
        let session = session()
        session.brushSettings.pressureSize = true
        session.brushSettings.smoothing = 30
        stroke(session, from: 0.25, to: 0.25)
        let bitmap = try await canvas(session)
        #expect((0..<300).map { thickness(bitmap, $0) }.max()! < 16)
    }

    /// Only a tablet's events carry a pressure to follow; a mouse's, even pressed hard on a Force Touch trackpad, don't.
    @Test func theCanvasReadsPressureFromATabletOnly() throws {
        func event(tablet: Bool, pressure: Double) throws -> NSEvent {
            let event = try #require(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                              mouseCursorPosition: .zero, mouseButton: .left))
            event.setDoubleValueField(.mouseEventPressure, value: pressure)
            if tablet { event.setIntegerValueField(.mouseEventSubtype, value: Int64(CGEventMouseSubtype.tabletPoint.rawValue)) }
            return try #require(NSEvent(cgEvent: event))
        }
        #expect(abs(try #require(CanvasView.penPressure(try event(tablet: true, pressure: 0.3))) - 0.3) < 0.01)
        #expect(CanvasView.penPressure(try event(tablet: false, pressure: 0.3)) == nil)
    }

    /// Without Metal, the dabs follow the pressure the same way: the size, and the firmest press as a cap.
    @Test func theSoftwareBrushFollowsThePressureToo() throws {
        func paint(_ configure: (inout BrushSettings) -> Void, pressure: (CGFloat) -> CGFloat) throws -> (NSBitmapImageRep, CGPoint) {
            let document = CanvasDocument(width: 300, height: 100)
            var settings = BrushSettings(diameter: 40, hardness: 1, red: 1, green: 0, blue: 0)
            configure(&settings)
            let layer = ImageLayer(name: "Blank", blankSize: document.size)
            let stroke = try BrushStroke(layer: layer, mask: false, settings: settings, canvas: document.size, useGPU: false)
            for step in 0...24 {
                let t = CGFloat(step) / 24
                try stroke.append(CGPoint(x: 30 + 240 * t, y: 50), pressure: pressure(t))
            }
            try stroke.flush()
            let snapshot = try stroke.paintSnapshot()
            return (NSBitmapImageRep(cgImage: snapshot.asset.image), snapshot.transform.origin)
        }
        // Painted only where the line went: a stroke that thins as it goes is taller at its start than its end.
        let (thinning, origin) = try paint({ $0.pressureSize = true }, pressure: { 1 - 0.75 * $0 })
        func rows(_ x: Int) -> Int { (0..<thinning.pixelsHigh).filter { alpha(thinning, x - Int(origin.x), $0) > 127 }.count }
        #expect(abs(rows(40) - 40) <= 3 && rows(260) < 16)
        for hardness: CGFloat in [1, 0] {
            let (faint, at) = try paint({ $0.pressureOpacity = true; $0.hardness = hardness }, pressure: { _ in 0.5 })
            #expect(abs(alpha(faint, 150 - Int(at.x), 50 - Int(at.y)) - 128) <= 3, "hardness \(hardness)")
        }
    }

    /// The pressure buttons belong to the Brush and carry over with its other settings.
    @Test func theButtonsBelongToTheBrushAndCarryOver() {
        let session = session()
        session.brushSettings.pressureSize = true
        session.brushSettings.pressureOpacity = true
        session.selectTool(.spotHealing)
        session.beginBrush(at: CGPoint(x: 100, y: 50), pressure: 0.2)
        #expect(session.brushStroke.map { !$0.settings.pressureSize && !$0.settings.pressureOpacity } == true)
        session.cancelBrush()
        let next = EditorSession()
        next.apply(session.brushDefaults)
        #expect(next.brushSettings.pressureSize && next.brushSettings.pressureOpacity)
    }
}
