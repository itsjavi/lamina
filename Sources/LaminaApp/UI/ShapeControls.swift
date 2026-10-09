import SwiftUI
import LaminaCore

/// The shape tools' bar: Fill, then the stroke and path operations to come (placeholders), then the shape's own
/// setting, Radius for rectangles and Weight for lines.
struct ShapeControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        OptionsBarRow {
            HStack(spacing: 6) {
                Text("Fill:")
                Button { session.openColorPicker(background: false) } label: {
                    let swatch = RoundedRectangle(cornerRadius: 3, style: .continuous)
                    swatch.fill(Color(nsColor: session.foregroundColor.nsColor))
                        .overlay { swatch.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                        .frame(width: 36, height: 18)
                }
                .buttonStyle(.plain)
                .help("Shapes fill with the foreground color; click to change it")
                .accessibilityLabel("Fill color")
            }
            ShapeStrokePlaceholders(session: session)
            if session.tool == .rectangle {
                OptionsBarDivider()
                OptionsBarField(label: "Radius", value: $session.shapeCornerRadius, range: 0...5000, unit: "px", width: 48)
                    .help("Round the rectangle's corners by this many pixels; 0 keeps them square")
            }
            if session.tool == .line {
                OptionsBarDivider()
                OptionsBarField(label: "Weight", value: $session.shapeLineWidth, range: 1...5000, unit: "px", width: 48)
                    .help("How thick the line is, in pixels")
            }
        }
        .releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }
}
