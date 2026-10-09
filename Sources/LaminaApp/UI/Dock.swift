import SwiftUI

/// Everything right of the canvas: the panel icon column, then the dock, whose left edge resizes it. With every dock
/// panel closed only the icon column stays, and the canvas takes the dock's width.
struct DockArea: View {
    @Bindable var session: EditorSession
    @Bindable var layout: DockLayout

    var body: some View {
        HStack(spacing: 0) {
            PanelIconColumn(layout: layout)
            if layout.showsDock {
                DockResizeEdge(axis: .horizontal, value: $layout.width, range: DockLayout.widths)
                Dock(session: session, layout: layout)
            }
        }
        // Renaming a layer and editing an adjustment happen in the Layers panel (Layer › Rename Layer…, Edit
        // Adjustment…), so it opens for them.
        .onChange(of: session.renamingLayerID != nil || session.adjustmentEditingID != nil) { _, needsLayers in
            if needsLayers { layout.show(.layers) }
        }
    }
}

/// The dock's two tab groups: Properties | Adjustments over Layers, with the split between them draggable. A group
/// whose panels are all closed collapses and leaves its height to the other.
struct Dock: View {
    @Bindable var session: EditorSession
    @Bindable var layout: DockLayout

    var body: some View {
        let showsLayers = !layout.openPanels(of: DockPanel.bottomGroup).isEmpty
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let front = layout.topFront {
                    DockGroup(tabs: layout.openPanels(of: DockPanel.topGroup),
                              selection: Binding(get: { front }, set: { layout.topSelection = $0 }), layout: layout) { panel in
                        if panel == .adjustments { AdjustmentsPanel(session: session) } else { PropertiesPanel(session: session) }
                    }
                    .frame(height: showsLayers ? DockLayout.topHeight(layout.topHeight, in: proxy.size.height) : nil)
                    if showsLayers {
                        DockResizeEdge(axis: .vertical, value: $layout.topHeight,
                                       range: DockLayout.minimumTopHeight...DockLayout.topHeight(.infinity, in: proxy.size.height))
                    }
                }
                if showsLayers {
                    DockGroup(tabs: [.layers], selection: .constant(.layers), layout: layout) { _ in
                        LayersPanel(session: session, width: layout.width)
                    }
                }
            }
        }
        .frame(width: layout.width)
        .background(ColorRole.panel.color)
    }
}

/// A tab group: a 26 pt row of tabs on `panelHeader` with the panel menu (≡) at its right, then the front tab's panel.
/// `content` draws the panel for a tab; the Properties, Adjustments and Layers panels fill their tabs through it.
struct DockGroup<Content: View>: View {
    let tabs: [DockPanel]
    @Binding var selection: DockPanel
    let layout: DockLayout
    @ViewBuilder let content: (DockPanel) -> Content

    var body: some View {
        VStack(spacing: 0) {
            DockTabRow(tabs: tabs, selection: $selection, layout: layout)
            content(selection).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(ColorRole.panel.color)
    }
}

private struct DockTabRow: View {
    let tabs: [DockPanel]
    @Binding var selection: DockPanel
    let layout: DockLayout

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isFront = tab == selection
                Button { selection = tab } label: {
                    Text(tab.title).font(.system(size: 12)).lineLimit(1)
                        .foregroundStyle(isFront ? ColorRole.text.color : ColorRole.secondaryText.color)
                        .padding(.horizontal, 9).frame(maxHeight: .infinity)
                        .overlay(alignment: .bottom) {
                            if isFront { ColorRole.text.color.frame(height: 2) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isFront ? [.isSelected, .isHeader] : [])
                .accessibilityIdentifier("dockTab.\(tab.rawValue)")
            }
            Spacer(minLength: 0)
            Menu {
                Button("Close") { layout.close(selection) }
                Button("Close Tab Group") { tabs.forEach(layout.close) }
            } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 12))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .foregroundStyle(ColorRole.secondaryText.color)
            .frame(width: 22)
            .help("Panel menu").accessibilityLabel("\(selection.title) panel menu")
        }
        .padding(.horizontal, 4)
        .frame(height: DockLayout.tabRowHeight)
        .background(ColorRole.panelHeader.color)
    }
}

/// The column of collapsed panels between the canvas and the dock. Clicking an icon opens its panel beside the dock;
/// clicking it again closes it.
struct PanelIconColumn: View {
    @Bindable var layout: DockLayout

    var body: some View {
        VStack(spacing: 3) {
            Button { layout.toggle(.history) } label: {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(layout.showsHistory ? ColorRole.activeTool.color : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(layout.showsHistory ? ColorRole.text.color : ColorRole.icon.color)
            .help("History").accessibilityLabel("History")
            .accessibilityAddTraits(layout.showsHistory ? .isSelected : [])
            .accessibilityIdentifier("historyPanelIcon")
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .frame(width: DockLayout.iconColumnWidth)
        .frame(maxHeight: .infinity)
        .background(ColorRole.chrome.color)
    }
}

/// History, open from the icon column: a floating panel at the canvas column's top right, against the icon column,
/// over the canvas. It stays open while the person works and closes from its icon, its panel menu or the Window menu.
struct HistoryFlyout: ViewModifier {
    let session: EditorSession
    let layout: DockLayout
    static let width: CGFloat = 240
    static let maximumHeight: CGFloat = 420

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if layout.showsHistory {
                DockGroup(tabs: [.history], selection: .constant(.history), layout: layout) { _ in
                    HistoryPanel(session: session)
                }
                .frame(width: Self.width)
                .frame(maxHeight: Self.maximumHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ColorRole.edge.color))
                .shadow(radius: 10, y: 4)
                .padding(6)
            }
        }
    }
}

/// A divider that resizes a dock region by dragging, within `range`: horizontally the view to its right (drag left to
/// widen), vertically the view above it (drag down to make it taller).
struct DockResizeEdge: View {
    let axis: Axis
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var start: Double?

    var body: some View {
        Divider().overlay {
            Color.clear
                .frame(width: axis == .horizontal ? 8 : nil, height: axis == .vertical ? 8 : nil)
                .contentShape(Rectangle())
                .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        // From where the edge is drawn: a split set in a taller window shows clamped in this one.
                        let origin = start ?? min(range.upperBound, max(range.lowerBound, value))
                        start = origin
                        let moved = axis == .horizontal ? origin - drag.translation.width : origin + drag.translation.height
                        value = min(range.upperBound, max(range.lowerBound, moved.rounded()))
                    }
                    .onEnded { _ in start = nil })
                .help(axis == .horizontal ? "Drag to resize the dock" : "Drag to resize the panels")
        }
        // The 8 pt grab area overhangs the line on both sides; above its neighbors, the region after it (the Layers
        // tab row, the dock) doesn't take the clicks on its half.
        .zIndex(1)
    }
}
