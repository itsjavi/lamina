import Foundation
import Observation

/// A panel of the right-hand dock or its icon column (docs/DESIGN.md, Dock and panels).
enum DockPanel: String, CaseIterable, Identifiable {
    case properties, adjustments, layers, history
    var id: Self { self }
    var title: String {
        switch self {
        case .properties: "Properties"
        case .adjustments: "Adjustments"
        case .layers: "Layers"
        case .history: "History"
        }
    }
    /// The dock's tab groups, top to bottom. History has none: it lives in the icon column.
    static let topGroup: [DockPanel] = [.properties, .adjustments]
    static let bottomGroup: [DockPanel] = [.layers]
}

/// The Essentials workspace as the person left it: the dock's width, the split between its groups, which panels are
/// open, and whether History is out. Shared by the window and the Window menu, and remembered in UserDefaults (History
/// excepted: it floats over the canvas, so it starts closed).
@MainActor @Observable final class DockLayout {
    static let shared = DockLayout(defaults: .standard)

    static let widths: ClosedRange<Double> = 240...360
    static let defaultWidth = 292.0
    /// The Properties | Adjustments group's height, tab row included.
    static let defaultTopHeight = 340.0
    /// The least either group keeps while the split is dragged: a tab row and a few rows of content.
    static let minimumTopHeight = 120.0
    static let minimumBottomHeight = 160.0
    static let iconColumnWidth = 34.0
    static let tabRowHeight = 26.0

    /// The dock's width, kept within `widths`.
    var width: Double {
        didSet {
            let clamped = Self.clampedWidth(width)
            if clamped != width { width = clamped; return }
            defaults.set(width, forKey: Keys.width)
        }
    }
    /// The top group's height as the person set it; `topHeight(in:)` fits it to the dock's height.
    var topHeight: Double {
        didSet {
            let clamped = max(Self.minimumTopHeight, topHeight)
            if clamped != topHeight { topHeight = clamped; return }
            defaults.set(topHeight, forKey: Keys.topHeight)
        }
    }
    /// Dock panels closed from the Window menu or a panel menu.
    private(set) var closedPanels: Set<DockPanel> {
        didSet { defaults.set(closedPanels.map(\.rawValue).sorted(), forKey: Keys.closedPanels) }
    }
    /// The top group's front tab.
    var topSelection: DockPanel {
        didSet { defaults.set(topSelection.rawValue, forKey: Keys.topSelection) }
    }
    /// History's panel, open beside the dock.
    var showsHistory = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        width = Self.clampedWidth(defaults.object(forKey: Keys.width) as? Double ?? Self.defaultWidth)
        topHeight = max(Self.minimumTopHeight, defaults.object(forKey: Keys.topHeight) as? Double ?? Self.defaultTopHeight)
        closedPanels = Set((defaults.stringArray(forKey: Keys.closedPanels) ?? [])
            .compactMap(DockPanel.init(rawValue:)).filter { $0 != .history })
        let selection = defaults.string(forKey: Keys.topSelection).flatMap(DockPanel.init(rawValue:))
        topSelection = selection.flatMap { DockPanel.topGroup.contains($0) ? $0 : nil } ?? .properties
    }

    /// A group's open panels, in tab order.
    func openPanels(of group: [DockPanel]) -> [DockPanel] { group.filter { !closedPanels.contains($0) } }
    /// Whether the dock has anything to show; closing every panel gives its width to the canvas.
    var showsDock: Bool { !openPanels(of: DockPanel.topGroup).isEmpty || !openPanels(of: DockPanel.bottomGroup).isEmpty }

    /// The front tab of the top group, among the panels still open.
    var topFront: DockPanel? {
        let open = openPanels(of: DockPanel.topGroup)
        return open.contains(topSelection) ? topSelection : open.first
    }

    /// Whether `panel` is on screen: open and in front of its group. The Window menu checks these, as familiar editors
    /// do; a panel behind another tab is unchecked, and choosing it brings it to the front.
    func isVisible(_ panel: DockPanel) -> Bool {
        switch panel {
        case .history: showsHistory
        case .layers: !closedPanels.contains(.layers)
        case .properties, .adjustments: topFront == panel
        }
    }

    /// Opens `panel` and brings it to the front of its group.
    func show(_ panel: DockPanel) {
        if panel == .history { showsHistory = true; return }
        closedPanels.remove(panel)
        if DockPanel.topGroup.contains(panel) { topSelection = panel }
    }

    /// Closes `panel`; the next open tab in its group comes to the front, and an empty group gives its space away.
    func close(_ panel: DockPanel) {
        if panel == .history { showsHistory = false; return }
        closedPanels.insert(panel)
        if panel == topSelection, let next = openPanels(of: DockPanel.topGroup).first { topSelection = next }
    }

    /// The Window menu's items: a visible panel closes, any other comes to the front.
    func toggle(_ panel: DockPanel) {
        isVisible(panel) ? close(panel) : show(panel)
    }

    /// Window ▸ Workspace ▸ Reset Essentials: default widths and split, every dock panel open with Properties in
    /// front, History closed.
    func reset() {
        width = Self.defaultWidth
        topHeight = Self.defaultTopHeight
        closedPanels = []
        topSelection = .properties
        showsHistory = false
    }

    /// The top group's height in a dock `available` points high with both groups showing: as set, but never so tall
    /// that Layers falls below its minimum, nor shorter than the top group's own.
    static func topHeight(_ height: Double, in available: Double) -> Double {
        min(max(minimumTopHeight, height), max(minimumTopHeight, available - minimumBottomHeight))
    }

    private static func clampedWidth(_ width: Double) -> Double { min(widths.upperBound, max(widths.lowerBound, width)) }

    private enum Keys {
        static let width = "dockWidth"
        static let topHeight = "dockTopHeight"
        static let closedPanels = "dockClosedPanels"
        static let topSelection = "dockTopTab"
    }
}
