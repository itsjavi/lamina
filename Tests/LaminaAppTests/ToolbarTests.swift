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

    /// The flyout lists the slot's items in order with name and key, the shown one checked, planned ones labeled as in
    /// progress; choosing from it goes through `choose(_:)`.
    @Test func theFlyoutListsTheSlotsItems() throws {
        let session = EditorSession()
        session.selectTool(.ellipse)
        let control = ToolSlotControl(session: session, slot: .shapes)
        var rows = ToolFlyout.rows(session: session, slot: .shapes)
        #expect(rows.map(\.item.name) == ["Rectangle Tool", "Ellipse Tool", "Polygon Tool", "Star Tool", "Line Tool"])
        #expect(rows.allSatisfy { $0.key == "U" })
        #expect(rows.map(\.item.label) == rows.map { "\($0.item.name) (U)" }, "VoiceOver hears the name and key")
        #expect(rows.map(\.isShown) == [false, true, false, false, false])
        #expect(rows[2].item.helpTag == "Polygon Tool (U) · In progress")

        control.chooseItem(rows[3].item)
        #expect(session.tool == .ellipse && session.inProgressNotice?.feature == .starTool, "a planned item only shows its message")
        control.chooseItem(rows[4].item)
        #expect(session.tool == .line && session.inProgressNotice == nil)
        rows = ToolFlyout.rows(session: session, slot: .shapes)
        #expect(rows.last?.isShown == true)

        let brush = ToolFlyout.rows(session: session, slot: .brush)
        #expect(brush.map(\.item.name) == ["Brush Tool", "Mixer Brush Tool", "Palette Knife Tool"])
        #expect(brush.map(\.isShown) == [true, false, false], "the slot's last-used tool, while another slot's is active")
        let path = ToolFlyout.rows(session: session, slot: .pathSelection)
        #expect(path.map(\.item.name) == ["Path Selection Tool", "Direct Selection Tool"])
        #expect(path.allSatisfy { $0.key == nil }, "no key until TASK-28 ships")
    }

    /// The first click on a slot makes its tool active, the next opens the flyout, the one after closes it; a slot of one
    /// tool has no flyout, and a slot showing a planned item opens its flyout at once when it lists more than one.
    @Test func clicksChooseThenOpenThenCloseTheFlyout() {
        let marquee = SlotItem.tool(.rectangularMarquee)
        #expect(ToolSlotControl.click(shown: marquee, activeTool: .brush, itemCount: 2, flyoutShown: false) == .choose)
        #expect(ToolSlotControl.click(shown: marquee, activeTool: .rectangularMarquee, itemCount: 2, flyoutShown: false) == .openFlyout)
        #expect(ToolSlotControl.click(shown: marquee, activeTool: .rectangularMarquee, itemCount: 2, flyoutShown: true) == .closeFlyout)
        #expect(ToolSlotControl.click(shown: .tool(.crop), activeTool: .crop, itemCount: 1, flyoutShown: false) == .nothing)
        #expect(ToolSlotControl.click(shown: .tool(.crop), activeTool: .move, itemCount: 1, flyoutShown: false) == .choose)
        #expect(ToolSlotControl.click(shown: .planned(.penTool), activeTool: .move, itemCount: 1, flyoutShown: false) == .choose,
                "the Pen slot shows its message")
        #expect(ToolSlotControl.click(shown: .planned(.pathSelectionTool), activeTool: .move, itemCount: 2, flyoutShown: false) == .openFlyout)
    }

    /// The flyout opens beside its own slot, in a toolbar taller than its slots (as in the app, where the column has room
    /// to spare below the colors), and a second call closes it.
    @Test(.showsWindows) func theFlyoutOpensBesideItsSlot() async throws {
        let session = EditorSession()
        session.selectTool(.gradient)
        let host = NSHostingView(rootView: ToolbarColumn(session: session))
        host.frame = CGRect(x: 0, y: 0, width: ToolbarColumn.width, height: 784)
        let window = NSWindow(contentRect: CGRect(x: 200, y: 100, width: ToolbarColumn.width, height: 784),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        try await settle()
        let control = try #require(descendants(host).compactMap { $0 as? ToolSlotControl }.first { $0.slot == .gradient })
        control.showFlyout()
        try await settle()
        let popoverWindow = try #require(control.flyoutWindow)
        let slot = window.convertToScreen(control.convert(control.bounds, to: nil))
        #expect(abs(popoverWindow.frame.midY - slot.midY) < 4, "popover \(popoverWindow.frame) beside slot \(slot)")
        #expect(popoverWindow.frame.minX >= slot.maxX - 1)
        control.closeFlyout()
        try await settle()
        #expect(!control.isFlyoutShown)
    }

    /// Whether a rendered icon has any visible pixel.
    private func hasInk(_ item: SlotItem) -> Bool {
        let renderer = ImageRenderer(content: ToolIcon(item: item, size: 16).foregroundStyle(.black))
        renderer.scale = 2
        guard let image = renderer.cgImage, let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return false }
        return stride(from: 3, to: image.width * image.height * 4, by: 4).contains { data[$0] > 0 }
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
            #expect(hasInk(item), "\(item) draws something")
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
