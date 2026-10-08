import AppKit
import Testing
@testable import LaminaApp

/// Keys the canvas and the Layers panel have no use for end there instead of going up the responder chain, where
/// AppKit beeps at every one; ⌘ combinations still go up, to beep where no menu takes them, as anywhere on the Mac.
@MainActor
struct UnusedKeyTests {
    /// Stands at the end of the chain and notes what reaches it.
    private final class Recorder: NSResponder {
        var keys: [String] = []
        override func keyDown(with event: NSEvent) { keys.append(event.charactersIgnoringModifiers ?? "") }
    }
    private func key(_ characters: String, code: UInt16, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: code)!
    }
    private func session() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 100, height: 80, emptyLayer: true)
        session.selectTool(.marquee) // No opacity keys, no selection to nudge.
        return session
    }

    @Test func theCanvasKeepsKeysItHasNoUseFor() {
        let session = session()
        let canvas = CanvasView(session: session)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        let recorder = Recorder()
        canvas.nextResponder = recorder
        canvas.keyDown(with: key("f", code: 3))                     // no tool on F
        canvas.keyDown(with: key("1", code: 18))                    // the Marquee takes no opacity
        canvas.keyDown(with: key("\u{1b}", code: 53))               // nothing to cancel
        canvas.keyDown(with: key("\u{f703}", code: 124))            // no selection to nudge
        canvas.keyDown(with: key("f", code: 3, .option))
        #expect(recorder.keys.isEmpty)
        #expect(session.tool == .marquee)
        canvas.keyDown(with: key("k", code: 40, .command))
        #expect(recorder.keys == ["k"], "⌘ combinations still go up the chain")
    }

    @Test func theLayersPanelKeepsEscapeAndReturnItHasNoUseFor() {
        let table = LayerTableView()
        table.session = session()
        let recorder = Recorder()
        table.nextResponder = recorder
        table.keyDown(with: key("\u{1b}", code: 53))
        table.keyDown(with: key("\r", code: 36))
        #expect(recorder.keys.isEmpty)
    }
}
