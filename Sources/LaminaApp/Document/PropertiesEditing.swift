import AppKit
import LaminaCore

/// What the Properties panel shows: the settings of whatever is selected (docs/DESIGN.md, Dock and panels ▸ Properties).
enum PropertiesKind: Equatable {
    /// No document yet.
    case none
    /// Nothing selected: the document's canvas, rulers and grids.
    case document
    case pixel, shape, type, group
    /// More than one layer selected: the box around them, and lining them up.
    case layers(Int)
    case adjustment(AdjustmentKind)
    /// A layer's mask targeted in the Layers panel.
    case mask

    var title: String {
        switch self {
        case .none, .document: "Document"
        case .pixel: "Pixel Layer"
        case .shape: "Shape Layer"
        case .type: "Type Layer"
        case .group: "Layer Group"
        case .layers(let count): "\(count) Layers"
        case .adjustment(let kind): kind.rawValue
        case .mask: "Layer Mask"
        }
    }
    var symbol: String {
        switch self {
        case .none, .document: "doc"
        case .pixel: "photo"
        case .shape: "square.on.circle"
        case .type: "textformat"
        case .group: "folder"
        case .layers: "square.stack"
        // As the Adjustments panel shows it.
        case .adjustment(let kind): kind.panelSymbol
        case .mask: "rectangle.inset.filled"
        }
    }
}

extension EditorSession {
    var propertiesKind: PropertiesKind {
        guard document != nil else { return .none }
        guard let layer = activeLayer else { return .document }
        if selectedLayerIDs.count > 1 { return .layers(selectedLayerIDs.count) }
        if isMaskSelected, layer.mask != nil { return .mask }
        if layer.isGroup { return .group }
        if let adjustment = layer.adjustment { return .adjustment(adjustment.kind) }
        if layer.liveText != nil { return .type }
        if layer.liveShape != nil { return .shape }
        return .pixel
    }

    /// Brings Properties forward in the dock, opening it if it was closed: a new adjustment layer, a double-click on
    /// one, Layer ▸ Layer Content Options….
    func showProperties() { propertiesRequest += 1 }

    /// Applies a Properties edit as one undo step named `name`. While the mouse button is held (a slider or a label
    /// being dragged, a curve point moving) the step stays open and the drag's later changes join it; it closes when
    /// the button comes up, so the whole drag undoes at once. A change to another setting starts a step of its own.
    /// `held` keeps the step open for a field that applies as it is typed in, until it calls `finishPropertyChange()`.
    func changeProperty(_ name: String, held: Bool = false, _ change: () -> Void) {
        if propertyEdit != nil, propertyEdit != name { finishPropertyChange() }
        if propertyEdit == nil {
            finishOpacityEdit()
            beginEdit(name)
            propertyEdit = name
        }
        change()
        if held { return }
        if isPointerHeld() { finishPropertyChangeOnRelease() } else { finishPropertyChange() }
    }

    /// Closes the step a drag held open, if one is.
    func finishPropertyChange() {
        guard propertyEdit != nil else { return }
        propertyEdit = nil
        propertyRelease?.cancel()
        propertyRelease = nil
        endEdit()
    }

    // MARK: Transform

    enum TransformProperty { case width, height, x, y, angle }

    /// Properties' Transform fields. W and H are the box's own size in pixels, kept at its top left (and in proportion
    /// while linked); X and Y the top left of the upright bounds around it, as familiar editors give them; the angle
    /// turns it about its middle. Each goes through the Move tool's transform, so it joins a Free Transform in
    /// progress, or is applied as one undo step by `finishTransformValues` once the field is done.
    func changeTransform(_ property: TransformProperty, to number: CGFloat) {
        guard number.isFinite else { return }
        changeTransformValue { value in
            switch property {
            case .width, .height:
                var size = value.size
                if property == .width {
                    size.width = number
                    if locksTransformRatio { size.height = value.size.height * number / value.size.width }
                } else {
                    size.height = number
                    if locksTransformRatio { size.width = value.size.width * number / value.size.height }
                }
                guard size.width >= 1, size.height >= 1 else { return }
                value = value.resized(to: size, keeping: .zero)
            case .x: value.origin.x += number - Self.bounds(of: value).minX
            case .y: value.origin.y += number - Self.bounds(of: value).minY
            case .angle: value = value.rotated(to: number.truncatingRemainder(dividingBy: 360), about: LayerTransform.centerReference)
            }
        }
    }

    /// The upright box around a turned layer, whose top left Properties' X and Y give.
    static func bounds(of transform: LayerTransform) -> CGRect {
        let corners = DistortWarp.corners(of: transform)
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let minX = xs.min() ?? 0, minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }

    /// Properties' Interpolation: the layer's sampling, applied at once (or with the Free Transform in progress).
    func changeInterpolation(_ sampling: LayerSampling) {
        changeTransformValue { $0.sampling = sampling }
        finishTransformValues()
    }

    // MARK: Adjustment layers

    /// An adjustment layer's settings changed in Properties. The canvas shows them at once, and each change is one
    /// undo step: a slider's whole drag, a typed value, a menu choice.
    func changeAdjustment(_ id: UUID, _ update: (inout LayerAdjustment) -> Void) {
        guard canEditLayers, let current = document?.layers.first(where: { $0.id == id })?.adjustment,
              document?.effectiveLocks(of: id).all != true else { return }
        var value = current
        update(&value)
        guard value != current, value.isValid else { return }
        changeProperty("Edit \(value.kind.rawValue) Adjustment") { updateAdjustment(id, value: value) }
    }

    /// The footer's Reset: the settings a new layer of the kind starts with, keeping its grain or noise pattern.
    func resetAdjustment(_ id: UUID) {
        guard let current = document?.layers.first(where: { $0.id == id })?.adjustment else { return }
        changeAdjustment(id) { value in
            value = newAdjustment(current.kind)
            if current.kind == .grain { value.grain.seed = current.grain.seed }
            if current.kind == .addNoise { value.resolvedNoiseSeed = current.resolvedNoiseSeed }
        }
    }

    /// A Gradient Map layer's end color, from the app's picker: the end follows the working color, and everything
    /// the picker changes is one undo step.
    func openAdjustmentColorPicker(_ id: UUID, highlights: Bool) {
        guard canEditPalette, colorPicker == nil,
              let value = document?.layers.first(where: { $0.id == id })?.adjustment, value.kind == .gradientMap else { return }
        let end = highlights ? value.gradientMap.highlights : value.gradientMap.shadows
        openDialogColorPicker(title: highlights ? "Highlights" : "Shadows",
                              color: PaletteColor(red: end.red, green: end.green, blue: end.blue),
                              undoName: "Edit \(value.kind.rawValue) Adjustment") { [weak self] color in
            self?.changeAdjustment(id) {
                if highlights { $0.gradientMap.highlights = AdjustmentColor(color) } else { $0.gradientMap.shadows = AdjustmentColor(color) }
            }
        }
    }

    /// What a Levels layer's histogram counts: the layers below it, drawn as they show (those above it, and it,
    /// left out). Nil when there's nothing to count.
    func adjustmentInputHistogram(_ id: UUID) async -> [[Double]]? {
        guard let snapshot = projectSnapshot(), snapshot.manifest.layers.contains(where: { $0.id == id }) else { return nil }
        var manifest = snapshot.manifest
        // Group records stay, for their visibility and live-mask references.
        let underneath = Set(LayerHierarchy.entries(manifest.layers).prefix { $0.layer.id != id }.map { $0.layer.id })
        for index in manifest.layers.indices where manifest.layers[index].isGroup != true && !underneath.contains(manifest.layers[index].id) {
            manifest.layers[index].isVisible = false
        }
        let source = ProjectSnapshot(manifest: manifest, images: snapshot.images, masks: snapshot.masks)
        guard let raster = try? await ImageExporter.shared.render(source) else { return nil }
        let job = LevelsJob(image: raster.image, settings: LevelsSettings(), selection: nil, mapping: .identity)
        return await Task.detached(priority: .userInitiated) { try? LevelsFilter.histogram(job) }.value
    }

    // MARK: Type

    /// Character and Paragraph: the text being edited takes the change, applied with the rest of it as the Type bar's
    /// changes are; a type layer that is only selected is redrawn with it at once, as one undo step.
    func changeTextLayerStyle(held: Bool = false, _ change: (inout LayerTextStyle) -> Void) {
        if textDraft != nil { changeTextStyle(change); return }
        guard let document, let layer = activeLayer, let text = layer.liveText, canEditLayers else { return }
        var draft = TextDraft(documentID: document.id, layerID: layer.id, origin: layer.origin, transform: layer.transform,
                              style: text.style)
        change(&draft.style)
        guard draft.style.isValid, draft.style != text.style else { return }
        changeProperty("Edit Text", held: held) { applyText(draft, refocus: false) }
    }

    /// The color Character shows: the letters selected in the text being edited, else the layer's first letter.
    var textLayerColor: PaletteColor {
        if textDraft != nil { return typeColor }
        return activeLayer?.liveText?.style.color(at: 0) ?? foregroundColor
    }

    /// Character's color swatch: the Type bar's picker for text being edited; for a selected type layer, the picker
    /// recolors all of it, one undo step however long it stays open.
    func openTextLayerColorPicker() {
        if textDraft != nil { openTextColorPicker(); return }
        guard canEditPalette, colorPicker == nil, let layer = activeLayer, layer.liveText != nil else { return }
        let id = layer.id, original = textLayerColor
        openDialogColorPicker(title: "Text Color", color: original, undoName: "Text Color") { [weak self] color in
            guard let self else { return }
            // Back to where it started (Cancel): the layer's own pixels again, so the step has nothing in it.
            if color == original, let index = self.document?.layers.firstIndex(where: { $0.id == id }) {
                self.document?.layers[index].asset = layer.asset
                self.document?.layers[index].text = layer.text
            } else {
                self.recolorText(id, to: color)
            }
        }
    }

    /// Controls track the mouse in loops of their own, which event monitors don't see, so the button is watched
    /// instead, until it comes up.
    private func finishPropertyChangeOnRelease() {
        guard propertyRelease == nil else { return }
        propertyRelease = Task { @MainActor [weak self] in
            while self?.isPointerHeld() == true, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard let self, !Task.isCancelled else { return }
            self.propertyRelease = nil
            self.finishPropertyChange()
        }
    }
}
