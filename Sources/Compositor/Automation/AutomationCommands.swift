import AppKit
import ImageIO
import LaminaAutomation
import UniformTypeIdentifiers

/// The commands themselves. Results follow the schemas in `CommandCatalog`; AutomationTests checks them against it.
extension AutomationDispatcher {
    // MARK: Reading

    func listDocuments(_ arguments: Arguments) async throws -> JSONValue {
        let withLayers = arguments.bool("layers") ?? true
        return ["documents": .array(workspace.tabs.map { tab in
            var summary = documentSummary(tab)
            if withLayers { summary["layers"] = .array(layerEntries(tab.session).map { .object($0.summary) }) }
            return .object(summary)
        })]
    }

    func describeDocument(_ arguments: Arguments) async throws -> JSONValue {
        let tab = try tab(arguments)
        let session = tab.session
        var result = documentSummary(tab)
        let ids = ShortID.prefixes((session.document?.layers ?? []).map(\.id))
        result["resolution"] = session.document.map { .number($0.resolution) } ?? .null
        result["selected_layers"] = .array(session.selectedLayerIDs.compactMap { ids[$0] }.sorted().map { .string($0) })
        result["mask_selected"] = .bool(session.isMaskSelected)
        if let selection = session.selection, !selection.isEmpty {
            result["selection"] = Self.bounds(selection.path.boundingBoxOfPath)
        } else {
            result["selection"] = .null
        }
        result["undo"] = session.history.canUndo ? .string(session.history.undoName) : .null
        result["redo"] = session.history.canRedo ? .string(session.history.redoName) : .null
        result["busy"] = busyReason(tab).map { .string($0) } ?? .null
        result["layers"] = .array(layerEntries(session).map { entry in
            let layer = entry.layer
            var detail = entry.summary
            detail["opacity"] = .number(layer.opacity)
            detail["blend_mode"] = .string(layer.blendMode.rawValue)
            detail["bounds"] = Self.bounds(CGRect(origin: layer.transform.origin, size: layer.transform.size))
            detail["rotation"] = .number(Double(layer.transform.rotation))
            detail["mask"] = layer.mask.map { ["enabled": .bool($0.isEnabled), "linked": .bool($0.isLinked)] } ?? .null
            detail["effects"] = .array((layer.effects?.kinds ?? []).map { .string($0.rawValue) })
            detail["text"] = layer.liveText.map { .string($0.style.content) } ?? .null
            return .object(detail)
        })
        return .object(result)
    }

    func renderPreview(_ arguments: Arguments) async throws -> JSONValue {
        let tab = try tab(arguments)
        guard let snapshot = tab.session.projectSnapshot() else { throw AutomationError(.unavailable, "The document has no canvas yet.") }
        let raster = try await ImageExporter.shared.render(snapshot)
        let longest = arguments.int("max_size") ?? 1024
        let preview = try await Task.detached(priority: .userInitiated) { try AutomationImages.png(raster.image, longestSide: longest) }.value
        return [
            "document": .string(documentID(tab)),
            "width": JSONValue(preview.width), "height": JSONValue(preview.height),
            "source_width": JSONValue(snapshot.manifest.width), "source_height": JSONValue(snapshot.manifest.height),
            "bytes": JSONValue(preview.data.count),
            "data": .string(preview.data.base64EncodedString()),
        ]
    }

    /// File › Export PNG or Export JPEG, without their panels: the same renderer and encoders, the bytes returned for
    /// `lamina` to write.
    func exportDocument(_ arguments: Arguments) async throws -> JSONValue {
        let tab = try tab(arguments)
        guard let snapshot = tab.session.projectSnapshot() else { throw AutomationError(.unavailable, "The document has no canvas yet.") }
        let format = arguments.string("format") ?? "png"
        let data: Data
        if format == "jpeg" {
            let raster = try await ImageExporter.shared.render(snapshot)
            let matte = arguments.color("background") ?? (1, 1, 1)
            let options = JPEGOptions(quality: arguments.double("quality") ?? 0.85,
                                      red: CGFloat(matte.red), green: CGFloat(matte.green), blue: CGFloat(matte.blue))
            data = try await ImageExporter.shared.jpeg(raster, options: options).data
        } else {
            data = try await ImageExporter.shared.pngData(snapshot)
        }
        return [
            "document": .string(documentID(tab)), "format": .string(format),
            "width": JSONValue(snapshot.manifest.width), "height": JSONValue(snapshot.manifest.height),
            "bytes": JSONValue(data.count), "data": .string(data.base64EncodedString()),
        ]
    }

    // MARK: Selecting

    func selectLayer(_ arguments: Arguments) async throws -> JSONValue {
        let tab = try tab(arguments)
        try requireIdle(tab)
        let session = tab.session
        let layer = try resolveLayer(arguments.string("layer") ?? "", in: session)
        let mask = arguments.bool("mask") ?? false
        if mask, layer.mask == nil { throw AutomationError(.unavailable, "\(layer.name) has no mask.") }
        session.selectLayerTarget(layer.id, mask: mask)
        guard session.activeLayerID == layer.id else { throw AutomationError(.busy, "The layer couldn't be selected right now.") }
        return [
            "document": .string(documentID(tab)),
            "active_layer": .string(ShortID.prefixes((session.document?.layers ?? []).map(\.id))[layer.id] ?? ShortID.hex(layer.id)),
            "mask_selected": .bool(session.isMaskSelected),
        ]
    }

    // MARK: Editing

    /// A Filter or Image › Adjustments menu item on one layer: begin, set the dialog's values, OK.
    func applyFilter(_ arguments: Arguments) async throws -> JSONValue {
        try await edit(arguments) { tab in
            let session = tab.session
            guard let spec = EffectCatalog.filter(arguments.string("kind") ?? ""),
                  let kind = FilterKind.allCases.first(where: { $0.rawValue == spec.title }) else {
                throw AutomationError(.failed, "This filter isn't available in this version of the app.")
            }
            let settings = try spec.validate(arguments.object("settings") ?? [:])
            let layer = try resolveLayer(arguments.string("layer") ?? "", in: session)
            if layer.isGroup { throw AutomationError(.unavailable, "\(layer.name) is a folder; filters change a layer's pixels.") }
            if layer.adjustment != nil {
                throw AutomationError(.unavailable, "\(layer.name) is an adjustment layer; filters change a layer's pixels.")
            }
            if layer.asset == nil, kind != .vignette { throw AutomationError(.unavailable, "\(layer.name) has no pixels yet.") }
            session.selectLayerTarget(layer.id, mask: false)
            guard kind == .vignette ? session.canVignette : session.canAdjustColors else {
                if session.document?.effectiveVisibleIDs.contains(layer.id) != true {
                    throw AutomationError(.unavailable, "\(layer.name) is hidden; filters apply to visible layers.")
                }
                if session.selection?.isEmpty == true { throw AutomationError(.unavailable, "The selection is empty.") }
                throw AutomationError(.unavailable, "\(kind.rawValue) can't be applied to \(layer.name) right now.")
            }
            session.beginFilter(kind)
            guard let edit = session.filterEdit else {
                throw AutomationError(.failed, takeError(session) ?? "\(kind.rawValue) couldn't start on \(layer.name).")
            }
            let values = AutomationEffects.filterSettings(kind, base: edit.settings, settings)
            if kind.isAutomatic {
                // The automatic filters (Remove Background) commit once the preview beginFilter started is ready; a
                // preview is only restarted for settings other than those.
                if values != edit.settings { session.updateFilter(values, preview: true) }
            } else {
                session.updateFilter(values, preview: false)
            }
            await session.commitFilter()
            if let open = session.filterEdit {
                // Not committed: an automatic filter's preview failed. Its error is the reason.
                for _ in 0..<4 {
                    guard let task = open.previewTask else { break }
                    await task.value
                }
                let reason = open.previewError ?? takeError(session) ?? "\(kind.rawValue) couldn't be applied."
                session.cancelFilter()
                throw AutomationError(.failed, reason)
            }
            if let error = takeError(session) { throw AutomationError(.failed, error) }
            return layer.id
        }
    }

    /// Layer › New Adjustment Layer with its settings filled in, as one undo step (the menu opens the settings panel
    /// instead; a command sets them directly).
    func addAdjustmentLayer(_ arguments: Arguments) async throws -> JSONValue {
        try await edit(arguments) { tab in
            let session = tab.session
            guard let spec = EffectCatalog.adjustment(arguments.string("kind") ?? ""),
                  let kind = AdjustmentKind.allCases.first(where: { $0.rawValue == spec.title }) else {
                throw AutomationError(.failed, "This adjustment isn't available in this version of the app.")
            }
            let settings = try spec.validate(arguments.object("settings") ?? [:])
            guard let document = session.document else { throw AutomationError(.unavailable, "The document has no canvas yet.") }
            if let above = arguments.string("above") {
                session.selectLayerTarget(try resolveLayer(above, in: session).id, mask: false)
            }
            guard session.canEditLayers, document.layers.count < 10_000 else {
                throw AutomationError(.unavailable, "An adjustment layer can't be added to this document right now.")
            }
            let previous = session.activeLayerID
            session.beginEdit("New \(kind.rawValue) Adjustment")
            session.addAdjustment(kind)
            session.adjustmentEditingID = nil
            guard let id = session.activeLayerID, id != previous, let value = session.activeLayer?.adjustment else {
                session.endEdit()
                throw AutomationError(.failed, "The adjustment layer couldn't be added.")
            }
            let adjusted = AutomationEffects.adjustment(value, settings)
            guard adjusted.isValid else {
                // Leave the document as it was: no layer, no undo step.
                session.document?.layers.removeAll { $0.id == id }
                session.activeLayerID = previous
                session.endEdit()
                throw AutomationError.invalid("Those settings aren't valid for \(spec.name).")
            }
            session.updateAdjustment(id, value: adjusted)
            session.endEdit()
            return id
        }
    }

    func undo(_ arguments: Arguments) async throws -> JSONValue {
        try await edit(arguments) { tab in
            guard tab.session.canUndo else { throw AutomationError(.unavailable, "There is nothing to undo.") }
            tab.session.undo()
            return nil
        }
    }

    func redo(_ arguments: Arguments) async throws -> JSONValue {
        try await edit(arguments) { tab in
            guard tab.session.canRedo else { throw AutomationError(.unavailable, "There is nothing to redo.") }
            tab.session.redo()
            return nil
        }
    }

    // MARK: Helpers

    /// The error a session method left for its alert, taken so the alert doesn't also show: the caller reports it.
    private func takeError(_ session: EditorSession) -> String? {
        defer { session.brushError = nil }
        return session.brushError
    }

    private func documentSummary(_ tab: ProjectTab) -> [String: JSONValue] {
        let session = tab.session
        let ids = ShortID.prefixes((session.document?.layers ?? []).map(\.id))
        return [
            "id": .string(documentID(tab)),
            "title": .string(tab.title),
            "path": session.projectURL.map { .string($0.path) } ?? .null,
            "front": .bool(tab.id == workspace.selectedID),
            "modified": .bool(session.isModified),
            "revision": .string(revision(session)),
            "width": session.document.map { JSONValue($0.width) } ?? .null,
            "height": session.document.map { JSONValue($0.height) } ?? .null,
            "active_layer": session.activeLayerID.flatMap { ids[$0] }.map { .string($0) } ?? .null,
        ]
    }

    struct LayerEntry {
        let layer: ImageLayer
        let summary: [String: JSONValue]
    }

    /// Layers top to bottom with their folders' contents under them, as the Layers panel lists them.
    private func layerEntries(_ session: EditorSession) -> [LayerEntry] {
        let layers = session.document?.layers ?? []
        let ids = ShortID.prefixes(layers.map(\.id))
        let children = Dictionary(grouping: layers, by: \.parentID)
        var result: [LayerEntry] = []
        func visit(_ parent: UUID?, depth: Int) {
            guard depth <= 64 else { return }
            for layer in (children[parent] ?? []).reversed() {
                var summary: [String: JSONValue] = [
                    "id": .string(ids[layer.id] ?? ShortID.hex(layer.id)),
                    "name": .string(layer.name),
                    "type": .string(Self.type(of: layer)),
                    "visible": .bool(layer.isVisible),
                    "parent": layer.parentID.flatMap { ids[$0] }.map { .string($0) } ?? .null,
                    "depth": JSONValue(depth),
                ]
                if let adjustment = layer.adjustment { summary["adjustment"] = .string(AutomationEffects.name(of: adjustment.kind)) }
                result.append(LayerEntry(layer: layer, summary: summary))
                if layer.isGroup { visit(layer.id, depth: depth + 1) }
            }
        }
        visit(nil, depth: 0)
        return result
    }

    private static func type(of layer: ImageLayer) -> String {
        if layer.isGroup { return "group" }
        if layer.adjustment != nil { return "adjustment" }
        if layer.liveText != nil { return "text" }
        if layer.liveShape != nil { return "shape" }
        return layer.asset == nil ? "empty" : "pixels"
    }

    private static func bounds(_ rect: CGRect) -> JSONValue {
        ["x": .number(rect.minX), "y": .number(rect.minY), "width": .number(rect.width), "height": .number(rect.height)]
    }
}

/// Preview images for `render-preview`.
nonisolated enum AutomationImages {
    /// `image` scaled down (never up) to fit `longestSide`, as PNG.
    static func png(_ image: CGImage, longestSide: Int) throws -> (data: Data, width: Int, height: Int) {
        let scale = min(1, CGFloat(longestSide) / CGFloat(max(image.width, image.height)))
        let width = max(1, Int((CGFloat(image.width) * scale).rounded())), height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        var output = image
        if width != image.width || height != image.height {
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ExportError.render }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let scaled = context.makeImage() else { throw ExportError.render }
            output = scaled
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ExportError.encode }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.encode }
        return (data as Data, width, height)
    }
}
