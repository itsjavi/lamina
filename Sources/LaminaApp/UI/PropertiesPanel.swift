import SwiftUI

/// The Properties panel: what is selected, in the dock's top group (docs/DESIGN.md, Dock and panels). Empty for now.
struct PropertiesPanel: View {
    @Bindable var session: EditorSession

    var body: some View {
        DockEmptyState(symbol: "slider.horizontal.3", title: "No properties")
    }
}

/// A panel with nothing to show: an icon and a line, centered, in the style of the Layers and History panels' own.
struct DockEmptyState: View {
    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 25, weight: .light))
            Text(title).font(.callout.weight(.medium))
            if let message { Text(message).font(.caption).multilineTextAlignment(.center) }
        }
        .foregroundStyle(.secondary).padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
