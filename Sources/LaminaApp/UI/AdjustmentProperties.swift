import SwiftUI
import LaminaCore

/// An adjustment layer's settings in Properties, live: the same controls Image ▸ Adjustments' dialogs use, without
/// their buttons, writing straight to the layer, one undo step per change (`changeAdjustment`).
struct AdjustmentProperties: View {
    @Bindable var session: EditorSession
    let layerID: UUID
    /// What a Levels layer's histogram counts, worked out for the layers below it as they are now.
    @State private var histogram: [[Double]]?

    private var layer: ImageLayer? { session.document?.layers.first { $0.id == layerID } }
    private var adjustment: LayerAdjustment { layer?.adjustment ?? LayerAdjustment(kind: .invert) }

    private func binding<Value>(_ key: WritableKeyPath<LayerAdjustment, Value>) -> Binding<Value> {
        Binding(get: { adjustment[keyPath: key] }, set: { value in session.changeAdjustment(layerID) { $0[keyPath: key] = value } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch adjustment.kind {
            case .levels:
                LevelsControls(settings: binding(\.levels), histogram: histogram)
                LevelsAutoButton(enabled: histogram != nil) { mode in
                    guard let histogram else { return }
                    session.changeAdjustment(layerID) { $0.levels = mode.settings(histogram: histogram) }
                }
                .fixedSize()
                Text("Counts the layers below · alpha-weighted histogram")
                    .font(.caption).foregroundStyle(ColorRole.secondaryText.color)
            case .hsv:
                HueSaturationControls(settings: Binding(get: { adjustment.resolvedHSV }, set: { value in
                    session.changeAdjustment(layerID) { $0.hsvSettings = value }
                }))
            case .invert:
                Text("Invert has no settings: it turns over the colors of the layers below.")
                    .foregroundStyle(ColorRole.secondaryText.color).fixedSize(horizontal: false, vertical: true)
            case .curves, .exposure, .gradientMap, .grain, .blackWhite, .colorBalance, .gaussianBlur, .motionBlur, .addNoise:
                if let kind = adjustment.kind.filterKind {
                    FilterControls(kind: kind, settings: Binding(get: { adjustment.filterSettings }, set: { settings in
                        session.changeAdjustment(layerID) { $0.take(settings) }
                    }), session: session, compact: true,
                    pickGradientMapColor: { session.openAdjustmentColorPicker(layerID, highlights: $0) })
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(!session.canEditLayers)
        .task(id: HistogramSource(session: session, layerID: layerID)) {
            guard adjustment.kind == .levels else { return }
            histogram = await session.adjustmentInputHistogram(layerID)
        }
        // A Gradient Map end follows the picker's working color.
        .onChange(of: session.colorPicker?.color) { _, _ in session.previewDialogColor() }
        .onDisappear { DialogColorSwatch.closePicker(session) }
    }
}

/// What a Levels layer's histogram depends on: every layer but the adjustment itself, so its own changes don't count
/// the tones again.
private struct HistogramSource: Equatable {
    let layerID: UUID
    let others: [ImageLayer]
    init(session: EditorSession, layerID: UUID) {
        self.layerID = layerID
        others = session.document?.layers.filter { $0.id != layerID } ?? []
    }
}

/// An adjustment layer's footer: clip it to the layer below, reset it, show or hide it, delete it.
struct AdjustmentFooter: View {
    @Bindable var session: EditorSession
    let layerID: UUID

    private var layer: ImageLayer? { session.document?.layers.first { $0.id == layerID } }

    var body: some View {
        let clipped = layer?.maskSourceID != nil
        let visible = layer?.isVisible ?? true
        PropertiesFooter {
            PropertiesFooterButton(title: clipped ? "Release Clipping Mask" : "Clip to Layer Below", symbol: "arrow.turn.left.down",
                                   isOn: clipped) {
                session.toggleClippingMask(layerID)
            }
            .disabled(!session.canToggleClippingMask(layerID))
            PropertiesFooterButton(title: "Reset to Adjustment Defaults", symbol: "arrow.counterclockwise") {
                session.resetAdjustment(layerID)
            }
            .disabled(!session.canEditLayers || layer?.adjustment?.kind.isEditable != true)
            PropertiesFooterButton(title: visible ? "Hide Layer" : "Show Layer", symbol: visible ? "eye" : "eye.slash") {
                session.toggleLayerVisibility(layerID)
            }
            .disabled(!session.canEditLayers)
            PropertiesFooterButton(title: "Delete Layer", symbol: "trash") { session.deleteLayer(layerID) }
                .disabled(!session.canEditLayers)
        }
    }
}
