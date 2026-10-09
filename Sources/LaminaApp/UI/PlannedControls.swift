import SwiftUI

// Placeholders for planned features (docs/DESIGN.md, In-progress placeholders): drawn as the shipping controls will be,
// enabled, with help tags ending "In progress". Each only shows its message (`EditorSession.showInProgress`).

/// A menu item of a planned feature. Its key, if the person gave it one, comes from Keyboard Shortcuts like any other.
struct PlannedMenuItem: View {
    let feature: PlannedFeature
    let session: EditorSession

    var body: some View {
        let item = Button(feature.title) { session.showInProgress(feature) }.help(feature.helpTag)
        if let path = feature.menuPath, PlannedFeature.assignableMenuCommands.contains(path) {
            item.assignableShortcut(path)
        } else {
            item
        }
    }
}

/// The Brush bar's bristle presets, until TASK-57 moves them into the brush picker.
struct BristlePresetsMenu: View {
    let session: EditorSession

    var body: some View {
        Menu("Presets") {
            ForEach(PlannedFeature.bristlePresets) { feature in
                Button(feature.title) { session.showInProgress(feature) }.help(feature.helpTag)
            }
        }
        .fixedSize()
        .help("Bristle brush presets · In progress")
        .accessibilityIdentifier("brushPresets")
    }
}

/// The shape bars' stroke (swatch, width and options), then path operations: what TASK-32 and TASK-34 bring.
struct ShapeStrokePlaceholders: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 6) {
            // No colon, like the bar's other labels until TASK-57 gives them all one.
            Text("Stroke")
            Button { session.showInProgress(.shapeStroke) } label: {
                // No stroke: an empty well crossed by a line, as color wells show "none".
                let swatch = RoundedRectangle(cornerRadius: 3, style: .continuous)
                swatch.fill(ColorRole.field.color)
                    .overlay {
                        Path { path in
                            path.move(to: CGPoint(x: 2, y: 16))
                            path.addLine(to: CGPoint(x: 34, y: 2))
                        }
                        .stroke(ColorRole.secondaryText.color, lineWidth: 1.5)
                    }
                    .overlay { swatch.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                    .frame(width: 36, height: 18)
                    .contentShape(swatch)
            }
            .buttonStyle(.plain)
            .help(PlannedFeature.shapeStroke.helpTag)
            .accessibilityLabel("Stroke color")
            Button { session.showInProgress(.shapeStroke) } label: {
                Text("1 px").monospacedDigit().frame(minWidth: 34, alignment: .trailing)
            }
            .help(PlannedFeature.shapeStroke.helpTag)
            .accessibilityLabel("Stroke width, 1 pixel")
            Button { session.showInProgress(.strokeOptions) } label: {
                Image(systemName: PlannedFeature.strokeOptions.symbol)
            }
            .help(PlannedFeature.strokeOptions.helpTag)
            .accessibilityLabel(PlannedFeature.strokeOptions.name)
        }
        .fixedSize()
        OptionsBarDivider()
        Button { session.showInProgress(.pathOperations) } label: {
            Image(systemName: PlannedFeature.pathOperations.symbol)
        }
        .help(PlannedFeature.pathOperations.helpTag)
        .accessibilityLabel(PlannedFeature.pathOperations.name)
        OptionsBarDivider()
    }
}
