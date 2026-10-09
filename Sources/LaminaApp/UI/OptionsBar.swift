import SwiftUI

/// The bar above the canvas: the active tool's icon, then that tool's settings. It is the same height for every tool,
/// so switching tools never moves the canvas.
struct OptionsBar<Settings: View>: View {
    let session: EditorSession
    @ViewBuilder var settings: Settings

    var body: some View {
        HStack(spacing: 0) {
            ToolIcon(tool: session.tool, size: 16)
                .foregroundStyle(ColorRole.text.color)
                .frame(width: OptionsBarStyle.iconSlotWidth)
                .help(session.tool.label)
                .accessibilityLabel(session.tool.label)
                .accessibilityIdentifier("optionsBarTool")
            OptionsBarDivider()
            settings.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ToolHeaderStyle.height)
    }
}

enum OptionsBarStyle {
    /// The toolbar's width in docs/DESIGN.md, so the icon sits over the column it was picked from.
    static let iconSlotWidth: CGFloat = 44
}

/// The 1 × 20 pt line between a bar's groups.
struct OptionsBarDivider: View {
    var body: some View { ColorRole.separator.color.frame(width: 1, height: 20) }
}

/// A bar's icon button, 24 × 22: the symbol alone, with its name as the help tag and accessibility label.
struct OptionsBarIconButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(title)
    }
}
