import SwiftUI

/// The Move tool's bar while nothing is being transformed: Auto-Select, Show Transform Controls, then Align and
/// Distribute. The numbers (X, Y, W, H, angle, Interpolation) show in the Free Transform bar while transforming.
struct MoveToolBar: View {
    @Bindable var session: EditorSession

    /// The bar's align buttons, as familiar editors lay them out: the horizontal three, then the vertical three.
    static let horizontalAlignments: [LayerAlignment] = [.left, .horizontalCenter, .right]
    static let verticalAlignments: [LayerAlignment] = [.top, .verticalCenter, .bottom]

    var body: some View {
        HStack(spacing: 10) {
            // Command flips Auto-Select while it's held, and the box shows it flipped (see HeldModifiers).
            Toggle("Auto-Select", isOn: Binding(get: { session.transformAutoSelect != held.contains(.command) },
                                                set: { session.transformAutoSelect = $0 != held.contains(.command) }))
                .toggleStyle(.checkbox)
                .help("Select layers by clicking the canvas. Hold Command to turn it the other way while you click.")
                .accessibilityIdentifier("transformAutoSelect")
            Toggle("Show Transform Controls", isOn: $session.showsTransformControls)
                .toggleStyle(.checkbox)
                .help("Show the transform box and handles. When hidden, drag anywhere to move the layer.")
                .accessibilityIdentifier("showTransformControls")
            OptionsBarDivider()
            HStack(spacing: 0) {
                alignButtons(Self.horizontalAlignments)
                distributeButton(.verticalSpacing, title: "Distribute Vertically")
                alignButtons(Self.verticalAlignments)
                distributeButton(.horizontalSpacing, title: "Distribute Horizontally")
            }
            Menu {
                Section("Align") {
                    ForEach(LayerAlignment.allCases, id: \.self) { alignment in
                        Button { session.alignLayers(alignment) } label: { Label(alignment.rawValue, systemImage: alignment.symbol) }
                    }
                }
                Section("Distribute") {
                    ForEach(LayerDistribution.allCases, id: \.self) { distribution in
                        Button { session.distributeLayers(distribution) } label: {
                            Label(distribution.rawValue, systemImage: distribution.symbol)
                        }
                        .disabled(!session.canDistributeLayers)
                    }
                }
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Align & Distribute: one layer lines up with the canvas, or with the selection")
                .accessibilityLabel("Align & Distribute")
                .accessibilityIdentifier("alignAndDistribute")
                .disabled(!session.canAlignLayers)
            Spacer()
        }
        .padding(.horizontal, 12).toolHeaderBar()
        .disabled(session.document == nil)
    }

    private var held: NSEvent.ModifierFlags { HeldModifiers.shared.flags }

    /// Like the ••• menu and the Properties panel: one layer lines up with the canvas (or a selection), several with
    /// their bounds.
    private func alignButtons(_ alignments: [LayerAlignment]) -> some View {
        ForEach(alignments, id: \.self) { alignment in
            OptionsBarIconButton(title: "Align " + alignment.rawValue, symbol: alignment.symbol) { session.alignLayers(alignment) }
                .disabled(!session.canAlignLayers)
        }
    }

    private func distributeButton(_ distribution: LayerDistribution, title: String) -> some View {
        OptionsBarIconButton(title: title, symbol: distribution.symbol) { session.distributeLayers(distribution) }
            .disabled(!session.canDistributeLayers)
    }
}
