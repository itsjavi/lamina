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
                TwoColumnToolbarPlaceholder(session: session)
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

/// What a click on a slot does (`ToolSlotControl.click`).
enum SlotClick: Equatable {
    /// Choose the item the slot shows: the slot's tool becomes the active one (a planned item shows its message).
    case choose
    case openFlyout
    case closeFlyout
    /// The slot's only tool is already active.
    case nothing
}

/// A slot's clicks, in AppKit over the SwiftUI drawing. A click on a slot whose tool isn't active chooses it; a click on
/// the active slot opens its flyout when it holds more than one item, and a click while the flyout is open closes it.
/// A slot showing a planned item (Pen, Path Selection) has no tool to make active, so a click opens its flyout straight
/// away when it lists more than one item. Right-clicking or Control-clicking opens the flyout too. The flyout is a
/// popover beside the slot listing the slot's items (`ToolFlyout`). To VoiceOver the slot is a button "Tool name (Key)",
/// selected when it's the active tool's, whose Show Menu action opens the flyout.
final class ToolSlotControl: NSView, NSPopoverDelegate {
    weak var session: EditorSession?
    var slot: ToolSlot
    var onHover: (Bool) -> Void = { _ in }
    private var popover: NSPopover?
    /// The click that closed the flyout from outside it. A transient popover closes on the mouse-down before the slot
    /// sees it, so a click on the slot while its flyout is open would otherwise open it again at once.
    private var closingClick: TimeInterval?

    init(session: EditorSession, slot: ToolSlot) {
        self.session = session
        self.slot = slot
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    var isFlyoutShown: Bool { popover?.isShown == true }
    /// The open flyout's window, for tests.
    var flyoutWindow: NSWindow? { popover?.contentViewController?.view.window }

    /// The first click makes the slot's tool active, the next opens the flyout, the one after closes it.
    static func click(shown: SlotItem, activeTool: NavigationTool, itemCount: Int, flyoutShown: Bool) -> SlotClick {
        if flyoutShown { return .closeFlyout }
        switch shown {
        case .tool(let tool) where tool == activeTool: return itemCount > 1 ? .openFlyout : .nothing
        case .planned: return itemCount > 1 ? .openFlyout : .choose
        case .tool: return .choose
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { toggleFlyout(); return }
        if let closingClick, closingClick == event.timestamp { self.closingClick = nil; return }
        guard let session else { return }
        switch Self.click(shown: session.shownItem(in: slot), activeTool: session.tool, itemCount: slot.items.count,
                          flyoutShown: isFlyoutShown) {
        case .choose: choose()
        case .openFlyout: showFlyout()
        case .closeFlyout: closeFlyout()
        case .nothing: break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let closingClick, closingClick == event.timestamp { self.closingClick = nil; return }
        toggleFlyout()
    }

    func choose() {
        guard let session else { return }
        session.choose(session.shownItem(in: slot))
    }

    private func toggleFlyout() { isFlyoutShown ? closeFlyout() : showFlyout() }

    /// The flyout, beside the slot's right edge.
    func showFlyout() {
        guard let session, !isFlyoutShown else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let content = NSHostingController(rootView: ToolFlyout(session: session, slot: slot) { [weak self] item in
            self?.chooseItem(item)
        })
        content.sizingOptions = [.preferredContentSize]
        popover.contentViewController = content
        // Sized before it's shown: placed at a default size and shrunk afterwards, it would end up off its slot.
        popover.contentSize = content.view.fittingSize
        self.popover = popover
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
    }

    func closeFlyout() { popover?.performClose(nil) }

    func popoverWillClose(_ notification: Notification) {
        if let event = NSApp.currentEvent, [.leftMouseDown, .rightMouseDown].contains(event.type) {
            closingClick = event.timestamp
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover = nil
        // The popover took the mouse's exit; say whether it's still here.
        if let window { onHover(bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))) }
    }

    /// Chooses an item from the flyout, which then closes.
    func chooseItem(_ item: SlotItem) {
        session?.choose(item)
        closingClick = nil
        closeFlyout()
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

private extension SlotItem {
    var isPlanned: Bool { if case .planned = self { true } else { false } }
}

/// One line of a slot's flyout.
struct ToolFlyoutRow: Equatable {
    let item: SlotItem
    /// What the slot shows now, marked with a checkmark.
    let isShown: Bool
    /// The slot's key, the same for every row: "U".
    let key: String?
}

/// A slot's flyout: its items in flyout order, each with its 16 pt icon, its name ("Elliptical Marquee Tool") and the
/// slot's key at the right, a checkmark on the shown one; planned items carry the "· In progress" help tag. Drawn in
/// SwiftUI with the color roles, so every icon (symbols and drawings alike) takes the appearance's colors; the row under
/// the pointer is highlighted in the accent color, as a menu's would be.
struct ToolFlyout: View {
    let session: EditorSession
    let slot: ToolSlot
    let onChoose: (SlotItem) -> Void
    @State private var hovered: SlotItem?

    static func rows(session: EditorSession, slot: ToolSlot) -> [ToolFlyoutRow] {
        let shown = session.shownItem(in: slot)
        return slot.items.map { ToolFlyoutRow(item: $0, isShown: $0 == shown, key: slot.key?.uppercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.rows(session: session, slot: slot), id: \.item) { row in
                rowView(row)
            }
        }
        .padding(5)
        .frame(minWidth: 220)
    }

    private func rowView(_ row: ToolFlyoutRow) -> some View {
        let highlighted = hovered == row.item
        return Button { onChoose(row.item) } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
                    .opacity(row.isShown ? 1 : 0)
                    .frame(width: 12)
                ToolIcon(item: row.item, size: 16)
                    .foregroundStyle(highlighted ? Color.white : ColorRole.icon.color)
                Text(row.item.name)
                Spacer(minLength: 16)
                if let key = row.key {
                    Text(key).foregroundStyle(highlighted ? Color.white : ColorRole.secondaryText.color)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(highlighted ? Color.white : ColorRole.text.color)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(highlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? row.item : (hovered == row.item ? nil : hovered) }
        .help(row.item.isPlanned ? row.item.helpTag : "")
        .accessibilityLabel(row.item.label)
        .accessibilityAddTraits(row.isShown ? .isSelected : [])
    }
}
