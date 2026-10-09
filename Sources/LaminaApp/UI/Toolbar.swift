import AppKit
import SwiftUI

/// The toolbar (docs/DESIGN.md, Toolbar): one 44 pt column of tool slots in their groups, the colors at its foot.
struct ToolbarColumn: View {
    let session: EditorSession
    static let width: CGFloat = 44

    var body: some View {
        // Scrolls only when the window is too short for every slot, rather than pushing the bars above and below away.
        IndicatorlessScrollView {
            VStack(spacing: 1) {
                ForEach(ToolSlot.allCases, id: \.self) { slot in
                    if slot.startsGroup {
                        ColorRole.separator.color.frame(width: 22, height: 1).padding(.vertical, 4)
                    }
                    ToolbarSlot(session: session, slot: slot)
                }
                ColorPaletteControls(session: session).padding(.top, 10)
            }
            .padding(.top, 6).padding(.bottom, 10)
            .frame(width: Self.width)
        }
        .frame(width: Self.width)
    }
}

/// One slot, 32 × 30: what it shows (`EditorSession.shownItem(in:)`) on the active tool's or the hover background, with
/// a corner triangle when the slot holds more than one item. `ToolSlotControl` takes its clicks.
private struct ToolbarSlot: View {
    let session: EditorSession
    let slot: ToolSlot
    @State private var hovered = false

    var body: some View {
        let item = session.shownItem(in: slot)
        let active = item == .tool(session.tool)
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? ColorRole.activeTool.color : hovered ? ColorRole.hover.color : .clear)
            ToolIcon(item: item)
                .foregroundStyle(active ? ColorRole.text.color : ColorRole.icon.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if slot.items.count > 1 {
                SlotGroupTriangle().fill(ColorRole.secondaryText.color).frame(width: 4, height: 4).padding(3)
            }
        }
        .frame(width: 32, height: 30)
        .accessibilityHidden(true)
        .overlay {
            ToolSlotInteraction(session: session, slot: slot, item: item, active: active) { hovered = $0 }
        }
    }
}

/// The small triangle in the bottom-right corner of a slot whose flyout lists more than one item.
private struct SlotGroupTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines([CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY),
                           CGPoint(x: rect.minX, y: rect.maxY)])
            path.closeSubpath()
        }
    }
}

private struct ToolSlotInteraction: NSViewRepresentable {
    let session: EditorSession
    let slot: ToolSlot
    let item: SlotItem
    let active: Bool
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> ToolSlotControl { ToolSlotControl(session: session, slot: slot) }

    func updateNSView(_ view: ToolSlotControl, context: Context) {
        view.session = session
        view.slot = slot
        view.onHover = onHover
        view.toolTip = item.helpTag
        view.setAccessibilityLabel(item.label)
        view.setAccessibilitySelected(active)
    }
}

/// A slot's clicks, in AppKit so a held press can open the flyout: a click chooses what the slot shows; holding the
/// mouse `holdDelay`, right-clicking or Control-clicking opens the flyout, a native menu of the slot's items with their
/// icons, names and key, the shown one checked. To VoiceOver it's a button "Tool name (Key)", selected when it's the
/// active tool's, whose Show Menu action opens the flyout.
final class ToolSlotControl: NSView {
    weak var session: EditorSession?
    var slot: ToolSlot
    var onHover: (Bool) -> Void = { _ in }
    /// How long a press waits before it opens the flyout instead of choosing.
    static let holdDelay: TimeInterval = 0.35

    init(session: EditorSession, slot: ToolSlot) {
        self.session = session
        self.slot = slot
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { showFlyout(); return }
        guard let window else { choose(); return }
        // Up before the delay is a click (if it's still over the slot); held past it, the flyout opens under the mouse,
        // so dragging onto an item and letting go chooses it, as in a pop-up menu.
        let deadline = Date(timeIntervalSinceNow: Self.holdDelay)
        while let next = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: deadline,
                                          inMode: .eventTracking, dequeue: true) {
            guard next.type == .leftMouseUp else { continue }
            if bounds.contains(convert(next.locationInWindow, from: nil)) { choose() }
            return
        }
        showFlyout()
    }

    override func rightMouseDown(with event: NSEvent) { showFlyout() }

    func choose() {
        guard let session else { return }
        session.choose(session.shownItem(in: slot))
    }

    /// The flyout, beside the slot's top right corner.
    func showFlyout() {
        guard let menu = flyoutMenu() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: bounds.maxX + 4, y: isFlipped ? bounds.minY : bounds.maxY), in: self)
        // The menu took the mouse's exit; say whether it's still here.
        if let window { onHover(bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))) }
    }

    /// The slot's items in flyout order: icon, name, the slot's key, the shown one checked; a planned item's tool tip
    /// says it's in progress.
    func flyoutMenu() -> NSMenu? {
        guard let session else { return nil }
        let shown = session.shownItem(in: slot)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in slot.items {
            let entry = NSMenuItem(title: item.name, action: #selector(chooseItem(_:)), keyEquivalent: slot.key ?? "")
            entry.keyEquivalentModifierMask = []
            entry.target = self
            entry.representedObject = item
            entry.attributedTitle = Self.flyoutTitle(item)
            entry.state = item == shown ? .on : .off
            if case .planned = item { entry.toolTip = item.helpTag }
            entry.setAccessibilityLabel(item.label)
            menu.addItem(entry)
        }
        return menu
    }

    /// The icon, then the name. The icon goes in the title rather than the item's `image`, which macOS 27 leaves out
    /// of menus.
    static func flyoutTitle(_ item: SlotItem) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let title = NSMutableAttributedString()
        if let image = ToolIcon.menuImage(for: item) {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - 16) / 2, width: 16, height: 16)
            title.append(NSAttributedString(attachment: attachment))
            title.append(NSAttributedString(string: "  "))
        }
        title.append(NSAttributedString(string: item.name))
        title.addAttribute(.font, value: font, range: NSRange(location: 0, length: title.length))
        return title
    }

    @objc func chooseItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? SlotItem else { return }
        session?.choose(item)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityPerformPress() -> Bool { choose(); return true }
    override func accessibilityPerformShowMenu() -> Bool { showFlyout(); return true }
}
