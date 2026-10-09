import SwiftUI

/// Window ▸ Workspace and the dock's panels, after Bring All to Front and before the open windows. A panel is checked
/// while it is on screen; choosing a checked panel closes it, any other comes to the front. The Navigator sits among
/// them and the Contextual Task Bar follows them (in progress, TASK-80 and TASK-67).
struct DockCommands: Commands {
    let layout: DockLayout
    let session: EditorSession

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Divider()
            Menu("Workspace") {
                // The only workspace, so choosing it keeps the layout as it is.
                Toggle("Essentials (Default)", isOn: .constant(true))
                    .assignableShortcut("Window › Workspace › Essentials (Default)")
                Divider()
                Button("Reset Essentials") { layout.reset() }
                    .assignableShortcut("Window › Workspace › Reset Essentials")
            }
            Divider()
            // Alphabetical, the Navigator (in progress, TASK-80) among them.
            ForEach(DockPanel.windowMenuOrder.filter { $0.title < PlannedFeature.navigator.name }) { panelToggle($0) }
            PlannedMenuItem(feature: .navigator, session: session)
            ForEach(DockPanel.windowMenuOrder.filter { $0.title > PlannedFeature.navigator.name }) { panelToggle($0) }
            Divider()
            PlannedMenuItem(feature: .contextualTaskBar, session: session)
        }
    }

    private func panelToggle(_ panel: DockPanel) -> some View {
        Toggle(panel.title, isOn: Binding(get: { layout.isVisible(panel) }, set: { _ in layout.toggle(panel) }))
            .assignableShortcut("Window › \(panel.title)")
    }
}

extension DockPanel {
    /// Familiar editors list their panels alphabetically.
    static let windowMenuOrder = allCases.sorted { $0.title < $1.title }
}
