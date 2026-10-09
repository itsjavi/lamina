import AppKit
import SwiftUI
import Testing
@testable import LaminaApp

/// The toolbar (docs/DESIGN.md, Toolbar): one slot per `ToolSlot` in its groups, showing the active or last-used item,
/// with a flyout of the slot's items; and every item's icon (Iconography).
@MainActor
struct ToolbarTests {
    private func descendants(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap { descendants($0) } }

    /// The toolbar in a window that's never put on screen, and its slots' controls in toolbar order.
    private func toolbar(_ session: EditorSession) -> (NSHostingView<ToolbarColumn>, () -> [ToolSlotControl]) {
        let host = NSHostingView(rootView: ToolbarColumn(session: session))
        host.frame = CGRect(x: 0, y: 0, width: ToolbarColumn.width, height: 900)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return (host, {
            host.layoutSubtreeIfNeeded()
            return self.descendants(host).compactMap { $0 as? ToolSlotControl }
                .sorted { $0.convert(NSPoint.zero, to: nil).y > $1.convert(NSPoint.zero, to: nil).y }
        })
    }

    /// A flyout entry's name, without the icon in front of it.
    private func name(_ entry: NSMenuItem) -> String { entry.title.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FFFC} ")) }

    /// Let SwiftUI apply a change to the session.
    private func settle() async throws { try await Task.sleep(for: .milliseconds(50)) }

    @Test func separatorsSplitTheSlotsIntoTheSpecsGroups() {
        #expect(ToolSlot.allCases.filter(\.startsGroup) == [.crop, .eyedropper, .spotHealing, .pen, .hand])
    }

    /// A slot shows the active tool when it's the slot's, else the one last used there, else its first item; choosing a
    /// planned item changes neither.
    @Test func aSlotShowsTheActiveOrLastUsedItem() {
        let session = EditorSession()
        session.selectTool(.move)
        #expect(session.shownItem(in: .marquee) == .tool(.rectangularMarquee))
        session.selectTool(.ellipticalMarquee)
        #expect(session.shownItem(in: .marquee) == .tool(.ellipticalMarquee))
        session.selectTool(.brush)
        #expect(session.shownItem(in: .marquee) == .tool(.ellipticalMarquee), "the last used, while another slot's tool is active")
        session.choose(.planned(.mixerBrushTool))
        #expect(session.tool == .brush && session.shownItem(in: .brush) == .tool(.brush))
        #expect(session.shownItem(in: .pen) == .planned(.penTool) && session.shownItem(in: .pathSelection) == .planned(.pathSelectionTool))
        session.selectTool(.line)
        session.choose(.tool(.rectangle))
        #expect(session.shownItem(in: .shapes) == .tool(.rectangle))
    }

    /// One control per slot, in toolbar order, labeled "Tool name (Key)" with the active one selected; they follow the
    /// session as tools change, and a click chooses what the slot shows.
    @Test func slotsAreLabeledButtonsThatFollowTheActiveTool() async throws {
        let session = EditorSession()
        session.selectTool(.move)
        let (host, controls) = toolbar(session)
        var slots = controls()
        #expect(slots.map(\.slot) == ToolSlot.allCases)
        #expect(slots.map { $0.accessibilityLabel() ?? "" }.prefix(3) == ["Move Tool (V)", "Rectangular Marquee Tool (M)", "Lasso Tool (L)"])
        #expect(slots.first { $0.slot == .pen }?.accessibilityLabel() == "Pen Tool (P)")
        #expect(slots.first { $0.slot == .pen }?.toolTip == "Pen Tool (P) · In progress")
        #expect(slots.filter { $0.isAccessibilitySelected() }.map(\.slot) == [.move])
        #expect(slots.allSatisfy { $0.accessibilityRole() == .button })
        for slot in slots {
            let center = slot.convert(NSPoint(x: slot.bounds.midX, y: slot.bounds.midY), to: nil)
            let hit = host.window?.contentView?.hitTest(center)
            #expect(hit === slot, "clicks reach \(slot.slot)'s control, not \(String(describing: hit))")
        }

        session.selectTool(.ellipticalMarquee)
        session.selectTool(.paintBucket)
        try await settle()
        slots = controls()
        let marquee = try #require(slots.first { $0.slot == .marquee })
        #expect(marquee.accessibilityLabel() == "Elliptical Marquee Tool (M)" && !marquee.isAccessibilitySelected())
        #expect(slots.filter { $0.isAccessibilitySelected() }.map(\.slot) == [.gradient])
        #expect(slots.first { $0.slot == .gradient }?.toolTip == "Paint Bucket Tool (G)")

        marquee.choose()
        #expect(session.tool == .ellipticalMarquee, "a click picks the slot's last-used tool")
        #expect(marquee.accessibilityPerformPress())
        let pen = try #require(slots.first { $0.slot == .pen })
        pen.choose()
        #expect(session.tool == .ellipticalMarquee && session.inProgressNotice?.feature == .penTool)
    }

    /// The flyout lists the slot's items in order with icon, name and key, the shown one checked, planned ones saying
    /// they're in progress; choosing from it goes through `choose(_:)`.
    @Test func theFlyoutListsTheSlotsItems() throws {
        let session = EditorSession()
        session.selectTool(.ellipse)
        let control = ToolSlotControl(session: session, slot: .shapes)
        let menu = try #require(control.flyoutMenu())
        #expect(menu.items.map(name) == ["Rectangle Tool", "Ellipse Tool", "Polygon Tool", "Star Tool", "Line Tool"])
        #expect(menu.items.allSatisfy { $0.keyEquivalent == "u" && $0.keyEquivalentModifierMask.isEmpty })
        for entry in menu.items {
            let title = try #require(entry.attributedTitle)
            #expect(entry.accessibilityLabel() == "\(name(entry)) (U)", "VoiceOver hears the name and key, not the icon")
            #expect(title.attribute(.attachment, at: 0, effectiveRange: nil) is NSTextAttachment, "\(name(entry)) has its icon")
        }
        #expect(menu.items.map(\.state) == [.off, .on, .off, .off, .off])
        #expect(menu.items[2].toolTip == "Polygon Tool (U) · In progress" && menu.items[0].toolTip == nil)

        control.chooseItem(menu.items[3])
        #expect(session.tool == .ellipse && session.inProgressNotice?.feature == .starTool, "a planned item only shows its message")
        control.chooseItem(menu.items[4])
        #expect(session.tool == .line && session.inProgressNotice == nil)
        #expect(control.flyoutMenu()?.items.last?.state == .on)

        let brush = try #require(ToolSlotControl(session: session, slot: .brush).flyoutMenu())
        #expect(brush.items.map(name) == ["Brush Tool", "Mixer Brush Tool", "Palette Knife Tool"])
        #expect(brush.items.map(\.state) == [.on, .off, .off], "the slot's last-used tool, while another slot's is active")
        let path = try #require(ToolSlotControl(session: session, slot: .pathSelection).flyoutMenu())
        #expect(path.items.map(name) == ["Path Selection Tool", "Direct Selection Tool"])
        #expect(path.items.allSatisfy { $0.keyEquivalent.isEmpty }, "no key until TASK-28 ships")
    }

    /// Every item has an icon: a symbol that exists, or its own drawing; Move is the four-headed arrow.
    @Test func everyToolHasAnIcon() {
        #expect(ToolIcon.symbol(for: .tool(.move)) == "arrow.up.and.down.and.arrow.left.and.right")
        #expect(ToolIcon.symbol(for: .tool(.hand)) == "hand.raised")
        for tool in [NavigationTool.dodge, .burn, .type, .gradient, .paintBucket, .cloneStamp, .polygonalLasso, .objectSelection] {
            #expect(ToolIcon.symbol(for: .tool(tool)) == nil, "\(tool) is drawn")
        }
        let items = ToolSlot.allCases.flatMap(\.items) + [.tool(.liquify), .tool(.idle)]
        for item in items {
            if let symbol = ToolIcon.symbol(for: item) {
                #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)")
            }
            #expect(ToolIcon.menuImage(for: item) != nil, "\(item)")
        }
    }

    /// Every slot and the colors fit an 860 pt window under the title bar and the options bar, without scrolling.
    @Test func theToolbarFitsAn860PointWindow() {
        let host = NSHostingView(rootView: ToolbarColumn(session: EditorSession()))
        host.frame = CGRect(x: 0, y: 0, width: ToolbarColumn.width, height: 400)
        host.layoutSubtreeIfNeeded()
        let content = descendants(host).compactMap { $0 as? NSScrollView }.first?.documentView
        let height = content?.fittingSize.height ?? .infinity
        // 860 less the title bar (about 40), the options bar (36) and the line under it.
        #expect(height <= 860 - 40 - 36 - 1, "\(height)")
        #expect(content?.fittingSize.width == ToolbarColumn.width)
    }
}
