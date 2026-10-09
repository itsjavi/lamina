import AppKit
import Testing
@testable import LaminaApp

/// Tools that familiar editors show apart are tools of their own, grouped in toolbar slots with one key each
/// (docs/DESIGN.md, Toolbar): the key picks the slot's last tool, Shift and the key the slot's next one.
@MainActor
struct ToolSlotTests {
    private func key(_ characters: String, code: UInt16, _ flags: NSEvent.ModifierFlags = [], repeat isARepeat: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: isARepeat, keyCode: code)!
    }

    @Test func everyToolbarToolHasOneSlotAndTheKeysFollowTheSpec() {
        let slotted = ToolSlot.allCases.flatMap(\.tools)
        #expect(slotted == NavigationTool.allCases.filter { $0 != .liquify && $0 != .idle }, "toolbar order, each tool once")
        #expect(NavigationTool.liquify.slot == nil && NavigationTool.idle.slot == nil)
        let keys = Dictionary(uniqueKeysWithValues: ToolSlot.allCases.map { ($0, $0.key) })
        #expect(keys == [.move: "v", .marquee: "m", .lasso: "l", .objectSelection: "w", .crop: "c", .eyedropper: "i",
                         .spotHealing: "j", .brush: "b", .cloneStamp: "s", .eraser: "e", .gradient: "g", .blur: "r",
                         .dodge: "o", .type: "t", .shapes: "u", .hand: "h", .zoom: "z"])
        #expect(Set(keys.values).count == keys.count)
        #expect(ToolSlot.marquee.tools == [.rectangularMarquee, .ellipticalMarquee])
        #expect(ToolSlot.lasso.tools == [.lasso, .polygonalLasso])
        #expect(ToolSlot.objectSelection.tools == [.objectSelection, .magicWand])
        #expect(ToolSlot.dodge.tools == [.dodge, .burn] && ToolSlot.blur.tools == [.blur, .smudge])
        #expect(ToolSlot.shapes.tools == [.rectangle, .ellipse, .line] && ToolSlot.gradient.tools == [.gradient, .paintBucket])
    }

    /// Help tags and accessibility labels read "Tool name (Key)"; every tool's hint is its own and none mentions Tab.
    @Test func labelsAndHintsNameEachTool() {
        #expect(NavigationTool.rectangularMarquee.label == "Rectangular Marquee Tool (M)")
        #expect(NavigationTool.polygonalLasso.label == "Polygonal Lasso Tool (L)")
        #expect(NavigationTool.magicWand.label == "Magic Wand Tool (W)")
        #expect(NavigationTool.eraser.label == "Eraser Tool (E)")
        #expect(NavigationTool.burn.label == "Burn Tool (O)")
        #expect(NavigationTool.smudge.label == "Smudge Tool (R)")
        #expect(NavigationTool.line.label == "Line Tool (U)")
        #expect(NavigationTool.liquify.label == "Liquify (⇧⌘X)" && NavigationTool.idle.label == "No Tool (A)")
        let hints = NavigationTool.allCases.map(\.hint)
        #expect(Set(hints).count == hints.count)
        #expect(!hints.contains { $0.contains("Tab") })
        for slot in ToolSlot.allCases where slot.tools.count > 1 {
            for tool in slot.tools { #expect(tool.hint.contains("Shift-\(slot.key.uppercased())"), "\(tool)") }
        }
    }

    /// Every slot: its key picks the first tool, Shift steps through the rest and round, and the key alone then picks
    /// the one left there. Shift from another slot's tool picks the slot's tool without stepping.
    @Test func aKeyPicksTheSlotsLastToolAndShiftStepsThroughTheSlot() {
        let session = EditorSession()
        for slot in ToolSlot.allCases {
            session.selectTool(.idle)
            session.pressToolKey(slot.key)
            #expect(session.tool == slot.tools[0], "\(slot)")
            var seen = [session.tool]
            for _ in slot.tools.indices { session.pressToolKey(slot.key, shift: true); seen.append(session.tool) }
            #expect(seen == slot.tools + [slot.tools[0]], "\(slot)")
            session.pressToolKey(slot.key, shift: true)
            session.selectTool(.idle)
            session.pressToolKey(slot.key, shift: true)
            #expect(session.tool == slot.tools[1 % slot.tools.count], "\(slot): Shift from elsewhere doesn't step")
            session.pressToolKey(slot.key)
            #expect(session.tool(in: slot) == session.tool)
        }
        session.pressToolKey("a")
        #expect(session.tool == .idle)
    }

    /// E is the Eraser and B the Brush, from the canvas and from the Layers panel alike; Shift-O, Shift-R and Shift-W
    /// reach Burn, Smudge and the Magic Wand; Tab changes nothing.
    @Test func theCanvasAndTheLayersPanelTakeTheSameKeys() {
        let session = EditorSession()
        session.createDocument(width: 40, height: 40, emptyLayer: true)
        let canvas = CanvasView(session: session)
        let table = LayerTableView()
        table.session = session
        for responder in [canvas, table] as [NSResponder] {
            session.selectTool(.move)
            responder.keyDown(with: key("e", code: 14))
            #expect(session.tool == .eraser)
            responder.keyDown(with: key("b", code: 11))
            #expect(session.tool == .brush)
            responder.keyDown(with: key("o", code: 31))
            responder.keyDown(with: key("O", code: 31, .shift))
            #expect(session.tool == .burn)
            responder.keyDown(with: key("O", code: 31, .shift, repeat: true))
            #expect(session.tool == .burn, "a held key steps once")
            responder.keyDown(with: key("\t", code: 48))
            #expect(session.tool == .burn)
            responder.keyDown(with: key("r", code: 15))
            responder.keyDown(with: key("R", code: 15, .shift))
            #expect(session.tool == .smudge)
            responder.keyDown(with: key("w", code: 13))
            responder.keyDown(with: key("W", code: 13, .shift))
            #expect(session.tool == .magicWand)
            responder.keyDown(with: key("a", code: 0))
            #expect(session.tool == .idle)
            // Back to the first of each slot for the next responder.
            for tool in [NavigationTool.dodge, .blur, .objectSelection] { session.selectTool(tool) }
        }
    }

    /// A key someone set for a tool entry before it was renamed still applies to it.
    @Test func keysSavedForRenamedToolEntriesCarryOver() throws {
        let defaults = UserDefaults(suiteName: "ToolSlotTests-\(UUID().uuidString)")!
        let saved = ["Canvas & Layers:Magic": ShortcutChord("q"), "Canvas & Layers:Cycle shape kind": ShortcutChord("y", 8)]
        defaults.set(try JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        let wand = try #require(ShortcutDefinition.all.first { $0.title == "Object Selection / Magic Wand" })
        let shapes = try #require(ShortcutDefinition.all.first { $0.title == "Next shape tool" })
        #expect(settings.chord(wand) == ShortcutChord("q") && settings.chord(shapes) == ShortcutChord("y", 8))
        #expect(!ShortcutDefinition.all.contains { $0.original == ShortcutChord("\t") }, "Tab picks nothing")
        #expect(ShortcutDefinition.all.contains { $0.title == "Dodge / Burn" && $0.original == ShortcutChord("o") })
    }
}
