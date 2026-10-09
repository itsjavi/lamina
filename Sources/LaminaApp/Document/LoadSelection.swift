import AppKit
import LaminaCore

/// A channel Select › Load Selection… loads, as Photoshop lists them: a layer's Transparency (its pixels at least
/// 50% opaque) or its Mask (what the mask reveals, at least 50% white).
nonisolated struct SelectionChannel: Hashable, Sendable {
    nonisolated enum Kind: Hashable, Sendable { case transparency, mask }
    let layerID: UUID
    let kind: Kind
}

/// Select › Load Selection…'s settings.
nonisolated struct LoadSelectionOptions: Equatable, Sendable {
    var channel: SelectionChannel
    /// The channel's other pixels instead: a mask's black areas, a layer's transparent ones.
    var invert = false
    var operation: SelectionMode = .replace
}

extension EditorSession {
    /// What Load Selection can load, in Layers panel order (top first), with the names it lists them by.
    var selectionChannels: [(channel: SelectionChannel, name: String)] {
        guard let document else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: document.layers.map { ($0.id, $0) })
        return LayerHierarchy.entries(document.layers.map(\.hierarchyRecord), topFirst: true).flatMap { entry in
            guard let layer = byID[entry.layer.id] else { return [(channel: SelectionChannel, name: String)]() }
            var channels: [(channel: SelectionChannel, name: String)] = []
            if !layer.isGroup, layer.asset != nil {
                channels.append((SelectionChannel(layerID: layer.id, kind: .transparency), layer.name + " Transparency"))
            }
            if layer.mask != nil { channels.append((SelectionChannel(layerID: layer.id, kind: .mask), layer.name + " Mask")) }
            return channels
        }
    }

    /// The channel the dialog starts on: the active layer's mask while it is targeted, else its transparency.
    var defaultSelectionChannel: SelectionChannel? {
        let channels = selectionChannels.map(\.channel)
        let preferred = activeLayerID.map { SelectionChannel(layerID: $0, kind: isMaskSelected ? .mask : .transparency) }
        let fallback = activeLayerID.map { SelectionChannel(layerID: $0, kind: isMaskSelected ? .transparency : .mask) }
        return [preferred, fallback].compactMap { $0 }.first(where: channels.contains) ?? channels.first
    }

    var canLoadSelection: Bool { canEditSelection && !selectionChannels.isEmpty }

    /// Select › Load Selection…: opens its dialog.
    func beginLoadSelection() {
        guard canLoadSelection, commandDialog == nil else { NSSound.beep(); return }
        commandDialog = .loadSelection
    }

    /// The Load Selection dialog's OK (its settings) or Cancel (nil).
    func finishLoadSelection(_ options: LoadSelectionOptions?) {
        guard commandDialog == .loadSelection else { return }
        commandDialog = nil
        if let options { loadSelection(options) }
    }

    /// Makes the channel the selection, adds it to the selection or takes it away, as one undo step. Inverted, the
    /// rest of the canvas is loaded instead: an inverted mask is its black areas, what Select › Mask's Black Areas
    /// gave before TASK-62.
    func loadSelection(_ options: LoadSelectionOptions) {
        guard canEditSelection, let document else { return }
        let channel: (outline: CGPath?, complement: Bool)
        do { channel = try channelOutline(options.channel) } catch { brushError = error.localizedDescription; return }
        let canvas = CGPath(rect: CGRect(origin: .zero, size: document.size), transform: nil)
        let outline: CGPath = channel.outline ?? CGMutablePath()
        // One boolean step from the traced outline either way: a complement of a complement, or of an outline already
        // clipped to the canvas, comes back with slivers a hair wide that read as a selection.
        let shape = channel.complement != options.invert
            ? canvas.subtracting(outline, using: .winding) : outline.intersection(canvas, using: .winding)
        let result: CGPath
        switch options.operation {
        case .replace: result = shape
        case .add: result = selection.map { $0.path.union(shape, using: .winding) } ?? shape
        case .subtract:
            // Taking something away from no selection leaves no selection.
            guard let current = selection else { return }
            result = current.path.subtracting(shape, using: .winding)
        }
        let loaded = DocumentSelection(path: result, antialiased: selectionAntialiased)
        // An empty channel loads nothing: a new selection keeps the old one, as Photoshop does after its warning.
        if options.operation == .replace, loaded.isEmpty { NSSound.beep(); return }
        // Nothing left is no selection at all, not an invisible empty one that stops every brush.
        setSelection(loaded.isEmpty ? nil : loaded, name: "Load Selection")
    }

    /// A channel's selected pixels: a document-space `outline` (nil when it has none), or with `complement` the whole
    /// canvas but that outline. A mask is a channel over the whole canvas: past its own pixels it is what its edge
    /// mostly is (`LayerMask.background`), so a reveal-all mask is the canvas but its black areas, and inverted it is
    /// exactly those, as Mask's Black Areas selected them. A hide-all mask is its white areas.
    func channelOutline(_ channel: SelectionChannel) throws -> (outline: CGPath?, complement: Bool) {
        guard let layer = document?.layers.first(where: { $0.id == channel.layerID }) else { return (nil, false) }
        switch channel.kind {
        case .transparency:
            return (try layerSelectionOutline(layerID: layer.id), false)
        case .mask:
            guard let mask = layer.mask else { return (nil, false) }
            if LayerMask.background(of: mask.asset.thumbnail) >= 0.5 { return (try maskSelectionOutline(layerID: layer.id), true) }
            let image = mask.asset.image
            var toDocument = BrushRaster.pixelToDocument(layer.maskTransform, width: image.width, height: image.height)
            return (try MaskTracing.whitePixels(in: image)?.copy(using: &toDocument), false)
        }
    }
}
