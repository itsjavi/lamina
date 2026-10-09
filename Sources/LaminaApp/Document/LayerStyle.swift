import Foundation
import LaminaCore

extension LayerEffectKind {
    /// The order the Layer Style dialog, its menu and the fx menu list the effects in: Photoshop's, less the ones
    /// Lamina doesn't have (docs/DESIGN.md, Dialogs).
    static let layerStyleOrder: [LayerEffectKind] = [.stroke, .innerShadow, .innerGlow, .colorOverlay, .outerGlow, .shadow]
}

/// A page of the Layer Style dialog: Blending Options, then one per effect.
enum LayerStylePage: Hashable {
    case blendingOptions
    case effect(LayerEffectKind)

    static let all: [LayerStylePage] = [.blendingOptions] + LayerEffectKind.layerStyleOrder.map { .effect($0) }
    var title: String {
        switch self {
        case .blendingOptions: return "Blending Options"
        case .effect(let kind): return kind.rawValue
        }
    }
    var kind: LayerEffectKind? {
        if case .effect(let kind) = self { return kind }
        return nil
    }
}

/// What the Layer Style dialog edits on its layer: the effects, and the blend mode and opacity Blending Options shows.
struct LayerStyleValues: Equatable {
    var effects: LayerEffects
    var blendMode: LayerBlendMode
    var opacity: Double

    init(effects: LayerEffects, blendMode: LayerBlendMode, opacity: Double) {
        self.effects = effects
        self.blendMode = blendMode
        self.opacity = opacity
    }
    init(_ layer: ImageLayer) {
        self.init(effects: layer.effects ?? LayerEffects(), blendMode: layer.blendMode, opacity: layer.opacity)
    }
}

/// The open Layer Style dialog. The working style is written straight into the document while Preview is on, so the
/// canvas shows it; nothing reaches the history until OK.
struct LayerStyleEdit: Equatable {
    let layerID: UUID
    var page: LayerStylePage
    let original: LayerStyleValues
    var working: LayerStyleValues
    var preview = true

    /// What OK applies: the working style, less the effects turned on and off again in the dialog (they were never
    /// part of the layer). An effect the layer had and the dialog turned off stays, hidden, as its eye would leave it.
    var result: LayerStyleValues {
        var result = working
        for kind in LayerEffectKind.allCases where !original.effects.contains(kind) && !working.effects.isEnabled(kind) {
            result.effects.remove(kind)
        }
        return result
    }
}

extension EditorSession {
    var canOpenLayerStyle: Bool { layerStyle == nil && canEditEffects }

    /// Layer ▸ Layer Style ▸ Blending Options… or an effect's item, the fx menu, or a double-click on an effect row:
    /// the dialog on `page` for the active layer. An effect's page turns that effect on, as choosing it from
    /// Photoshop's menus does.
    func openLayerStyle(_ page: LayerStylePage = .blendingOptions) {
        guard canOpenLayerStyle, let layer = activeLayer else { return }
        finishOpacityEdit()
        if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: false) }
        let values = LayerStyleValues(layer)
        layerStyle = LayerStyleEdit(layerID: layer.id, page: .blendingOptions, original: values, working: values)
        selectLayerStylePage(page)
    }

    /// A click on a row of the dialog's list: shows its settings, turning an effect on as a click on its name does
    /// in Photoshop.
    func selectLayerStylePage(_ page: LayerStylePage) {
        guard layerStyle != nil else { return }
        layerStyle?.page = page
        if let kind = page.kind, layerStyle?.working.effects.isEnabled(kind) == false { setLayerStyleEffect(kind, enabled: true) }
    }

    /// An effect's checkbox. Turning one on keeps settings it already had and otherwise starts from today's defaults.
    func setLayerStyleEffect(_ kind: LayerEffectKind, enabled: Bool) {
        changeLayerStyle { values in
            if enabled, !values.effects.contains(kind) { values.effects = adding(kind, to: values.effects) }
            else { values.effects.setEnabled(enabled, for: kind) }
        }
    }

    /// Changes the working style and shows it on the canvas.
    func changeLayerStyle(_ change: (inout LayerStyleValues) -> Void) {
        guard var edit = layerStyle else { return }
        var values = edit.working
        change(&values)
        values.opacity = min(1, max(0, values.opacity.isFinite ? values.opacity : edit.working.opacity))
        guard values.effects.isValid else { return }
        edit.working = values
        layerStyle = edit
        showLayerStyle()
    }

    /// The Preview checkbox: off shows the layer as it was, on shows the working style.
    func setLayerStylePreview(_ preview: Bool) {
        guard layerStyle != nil else { return }
        layerStyle?.preview = preview
        showLayerStyle()
    }

    /// OK applies the style as one undo step; Cancel puts the layer back exactly as it was.
    func finishLayerStyle(commit: Bool) {
        guard layerStyle != nil else { return }
        // First, so OK keeps the color the picker was showing.
        if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: commit) }
        guard let edit = layerStyle else { return }
        // Applied from the original, so the step's before is the layer as the dialog found it.
        write(edit.original, to: edit.layerID)
        layerStyle = nil
        if commit {
            beginEdit("Layer Style")
            write(edit.result, to: edit.layerID)
            endEdit()
        }
        if selectedEffect == nil { effectSelection = nil }
    }

    private func showLayerStyle() {
        guard let edit = layerStyle else { return }
        write(edit.preview ? edit.working : edit.original, to: edit.layerID)
    }

    /// Writes a style into the document outside the history: the dialog's preview, and its two ends.
    private func write(_ values: LayerStyleValues, to id: UUID) {
        guard let index = document?.layers.firstIndex(where: { $0.id == id }) else { return }
        let effects = values.effects.isEmpty ? nil : values.effects
        if document?.layers[index].effects != effects { document?.layers[index].effects = effects }
        if document?.layers[index].blendMode != values.blendMode { document?.layers[index].blendMode = values.blendMode }
        if document?.layers[index].opacity != values.opacity { document?.layers[index].opacity = values.opacity }
    }

    /// `effects` with `kind` added at its defaults. A new stroke or overlay takes the background color: the foreground
    /// is usually what the layer is painted in.
    func adding(_ kind: LayerEffectKind, to effects: LayerEffects) -> LayerEffects {
        var effects = effects
        let color = backgroundColor
        switch kind {
        case .stroke: effects.stroke = StrokeEffect(red: color.red, green: color.green, blue: color.blue)
        case .shadow: effects.shadow = ShadowEffect()
        case .colorOverlay: effects.colorOverlay = ColorOverlayEffect(red: color.red, green: color.green, blue: color.blue)
        case .innerShadow: effects.innerShadow = InnerShadowEffect()
        case .outerGlow: effects.outerGlow = OuterGlowEffect()
        case .innerGlow: effects.innerGlow = InnerGlowEffect()
        }
        return effects
    }
}
