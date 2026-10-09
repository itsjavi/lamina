import Foundation
import Testing
@testable import LaminaApp

/// The dock's layout model: what the Window menu checks and toggles, what Reset Essentials restores, and what is
/// remembered. Each test gets its own defaults suite, so nothing touches the person's settings.
@MainActor struct DockLayoutTests {
    private let defaults: UserDefaults
    init() {
        let suite = "DockLayoutTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func startsAsEssentials() {
        let layout = DockLayout(defaults: defaults)
        #expect(layout.width == 292)
        #expect(layout.topHeight == 340)
        #expect(layout.showsDock)
        #expect(layout.topFront == .properties)
        #expect(DockPanel.windowMenuOrder.filter(layout.isVisible) == [.layers, .properties])
    }

    @Test func widthStaysInRange() {
        let layout = DockLayout(defaults: defaults)
        layout.width = 500
        #expect(layout.width == 360)
        layout.width = 100
        #expect(layout.width == 240)
    }

    @Test func splitLeavesLayersItsRoom() {
        // 783 pt is the dock at 1500 × 860: the window less the title bar and options bar.
        #expect(DockLayout.topHeight(340, in: 783) == 340)
        #expect(DockLayout.topHeight(700, in: 783) == 783 - DockLayout.minimumBottomHeight)
        #expect(DockLayout.topHeight(50, in: 783) == DockLayout.minimumTopHeight)
        #expect(DockLayout.topHeight(340, in: 200) == DockLayout.minimumTopHeight)
    }

    @Test func windowMenuBringsAHiddenTabForwardAndClosesAVisibleOne() {
        let layout = DockLayout(defaults: defaults)
        #expect(!layout.isVisible(.adjustments))
        layout.toggle(.adjustments)
        #expect(layout.isVisible(.adjustments) && !layout.isVisible(.properties))
        #expect(layout.openPanels(of: DockPanel.topGroup) == [.properties, .adjustments])
        layout.toggle(.adjustments)
        #expect(layout.openPanels(of: DockPanel.topGroup) == [.properties])
        #expect(layout.topFront == .properties)
    }

    @Test func closedGroupsCollapseAndEmptyDockGoes() {
        let layout = DockLayout(defaults: defaults)
        layout.close(.properties)
        layout.close(.adjustments)
        #expect(layout.topFront == nil)
        #expect(layout.showsDock)
        layout.close(.layers)
        #expect(!layout.showsDock)
        layout.toggle(.layers)
        #expect(layout.showsDock && layout.isVisible(.layers))
    }

    @Test func historyTogglesBesideTheDock() {
        let layout = DockLayout(defaults: defaults)
        #expect(!layout.isVisible(.history))
        layout.toggle(.history)
        #expect(layout.showsHistory)
        layout.toggle(.history)
        #expect(!layout.showsHistory)
    }

    @Test func resetEssentialsRestoresTheLayout() {
        let layout = DockLayout(defaults: defaults)
        layout.width = 360
        layout.topHeight = 500
        layout.show(.adjustments)
        layout.close(.layers)
        layout.show(.history)
        layout.reset()
        #expect(layout.width == 292 && layout.topHeight == 340)
        #expect(layout.topFront == .properties && layout.openPanels(of: DockPanel.topGroup) == [.properties, .adjustments])
        #expect(layout.isVisible(.layers) && !layout.showsHistory)
    }

    @Test func layoutIsRememberedExceptHistory() {
        let layout = DockLayout(defaults: defaults)
        layout.width = 320
        layout.topHeight = 420
        layout.show(.adjustments)
        layout.close(.properties)
        layout.show(.history)
        let reopened = DockLayout(defaults: defaults)
        #expect(reopened.width == 320 && reopened.topHeight == 420)
        #expect(reopened.topFront == .adjustments && reopened.openPanels(of: DockPanel.topGroup) == [.adjustments])
        #expect(!reopened.showsHistory)
    }

    @Test func windowMenuItemsCanTakeShortcuts() {
        for title in ["Window › Workspace › Reset Essentials", "Window › Adjustments", "Window › History",
                      "Window › Layers", "Window › Properties"] {
            #expect(ShortcutDefinition.assignableMenuCommands.contains(title))
        }
    }
}
