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

/// The bristle presets at the foot of the Brush's brush picker (TASK-46).
struct BristlePresetList: View {
    let session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bristle Presets").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(PlannedFeature.bristlePresets) { feature in
                Button(feature.title) { session.showInProgress(feature) }
                    .buttonStyle(.borderless)
                    .help(feature.helpTag)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("brushPresets")
    }
}

/// The shape bars' stroke (swatch, width and options), then path operations: what TASK-32 and TASK-34 bring.
struct ShapeStrokePlaceholders: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 6) {
            Text("Stroke:")
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
                PlannedFeatureIcon(feature: .strokeOptions)
            }
            .help(PlannedFeature.strokeOptions.helpTag)
            .accessibilityLabel(PlannedFeature.strokeOptions.name)
        }
        .fixedSize()
        OptionsBarDivider()
        Button { session.showInProgress(.pathOperations) } label: {
            PlannedFeatureIcon(feature: .pathOperations)
        }
        .help(PlannedFeature.pathOperations.helpTag)
        .accessibilityLabel(PlannedFeature.pathOperations.name)
    }
}

/// "Fill:" under Opacity in the Layers panel (TASK-83). Its field reads 100%, the fill every layer has today; taking
/// focus shows the message and hands focus back to the canvas.
struct FillOpacityPlaceholder: View {
    let session: EditorSession
    @FocusState private var focused: Bool

    var body: some View {
        let feature = PlannedFeature.fillOpacity
        HStack(spacing: 4) {
            Text("Fill:").foregroundStyle(.secondary)
            HStack(spacing: 0) {
                TextField("Fill", text: .constant("100%"))
                    .textFieldStyle(.roundedBorder).frame(width: 48).focused($focused)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: focused) { _, isFocused in
                        guard isFocused else { return }
                        focused = false
                        session.showInProgress(feature)
                        session.canvasFocusRequest += 1
                    }
                Button { session.showInProgress(feature) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                        .frame(width: 14, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(ColorRole.icon.color)
                .accessibilityLabel("Fill slider")
            }
        }
        .help(feature.helpTag)
    }
}

/// The double arrow at the top of the toolbar that switches it between one column and two (TASK-86).
struct TwoColumnToolbarPlaceholder: View {
    let session: EditorSession

    var body: some View {
        let feature = PlannedFeature.twoColumnToolbar
        Button { session.showInProgress(feature) } label: {
            PlannedFeatureIcon(feature: feature).font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ColorRole.icon.color)
                .frame(width: 32, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(feature.helpTag)
        .accessibilityLabel(feature.name)
    }
}
