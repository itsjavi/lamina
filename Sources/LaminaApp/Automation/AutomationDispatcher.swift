import AppKit
import LaminaAutomation

/// Runs `lamina`'s commands (LaminaAutomation's `CommandCatalog`) in the app. Each command calls the same session and
/// workspace methods the menus and panels call, so it validates, previews and records undo exactly as the menu item
/// would; an edit is one undo step. Commands run one at a time, in the order they arrive, on the main actor, and
/// refuse with the reason while the person is in the middle of something (typing text, a transform, an open dialog).
final class AutomationDispatcher {
    let workspace: ProjectWorkspace
    private var queue: Task<Void, Never>?

    init(workspace: ProjectWorkspace) { self.workspace = workspace }

    /// A JSON request in, a JSON reply out (see `AutomationMessage`); failures are replies, never thrown.
    func handle(_ request: Data) async -> Data {
        let previous = queue
        let task = Task { () -> Data in
            await previous?.value
            return await self.reply(to: request)
        }
        queue = Task { _ = await task.value }
        return await task.value
    }

    private func reply(to request: Data) async -> Data {
        let outcome: Result<JSONValue, AutomationError>
        do { outcome = .success(try await run(request)) }
        catch let error as AutomationError { outcome = .failure(error) }
        catch { outcome = .failure(AutomationError(.failed, error.localizedDescription)) }
        return AutomationMessage.reply(outcome).encoded()
    }

    private func run(_ data: Data) async throws -> JSONValue {
        guard let request = try? JSONValue.decode(data), request.objectValue != nil else {
            throw AutomationError.invalid("The request isn't a JSON object.")
        }
        if let version = request["v"]?.intValue, version > AutomationMessage.version {
            throw AutomationError(.unsupportedVersion, "This version of \(AppIdentity.displayName) understands requests up to version "
                + "\(AutomationMessage.version), not \(version). Update the app.")
        }
        guard let name = request["command"]?.stringValue else { throw AutomationError.invalid("The request names no command.") }
        let arguments = request["arguments"] ?? [:]
        guard let object = arguments.objectValue else { throw AutomationError.invalid("The arguments must be a JSON object.") }
        return try await run(name, object)
    }

    /// Runs one command with arguments that haven't been checked yet.
    func run(_ name: String, _ arguments: [String: JSONValue] = [:]) async throws -> JSONValue {
        guard let spec = CommandCatalog.command(name), let handler = Self.handlers[spec.name] else {
            throw AutomationError(.unknownCommand, "\(AppIdentity.displayName) has no command \(name).")
        }
        return try await handler(self)(try spec.validate(arguments, includingClientSide: false))
    }

    /// Each catalog command's implementation (AutomationCommands.swift); a test checks every command has one.
    static let handlers: [String: (AutomationDispatcher) -> (Arguments) async throws -> JSONValue] = [
        "list-documents": { $0.listDocuments },
        "describe-document": { $0.describeDocument },
        "select-layer": { $0.selectLayer },
        "apply-filter": { $0.applyFilter },
        "add-adjustment-layer": { $0.addAdjustmentLayer },
        "export-document": { $0.exportDocument },
        "render-preview": { $0.renderPreview },
        "undo": { $0.undo },
        "redo": { $0.redo },
    ]

    // MARK: Documents and layers by id

    func tab(_ arguments: Arguments) throws -> ProjectTab {
        try ShortID.resolve(arguments.string("document") ?? "", among: workspace.tabs.map { ($0.id, $0) }, noun: "open document")
    }

    func resolveLayer(_ query: String, in session: EditorSession) throws -> ImageLayer {
        guard let document = session.document else { throw AutomationError(.unavailable, "The document has no canvas yet.") }
        return try ShortID.resolve(query, among: document.layers.map { ($0.id, $0) }, noun: "layer")
    }

    func documentID(_ tab: ProjectTab) -> String {
        ShortID.prefixes(workspace.tabs.map(\.id))[tab.id] ?? ShortID.hex(tab.id)
    }

    func revision(_ session: EditorSession) -> String { String(ShortID.hex(session.history.currentRevision).prefix(8)) }

    // MARK: Refusing while the person is mid-edit

    /// Why an edit can't run on this document now, as the person would see it; nil when it can.
    func busyReason(_ tab: ProjectTab) -> String? {
        let s = tab.session
        if workspace.isManaging { return "The app is opening, closing or saving a project." }
        if s.textDraft != nil { return "Text is being edited." }
        if s.transformEdit != nil { return "A transform is in progress." }
        if let edit = s.filterEdit { return "The \(edit.kind.rawValue) dialog is open." }
        if s.hueSaturation != nil { return "The Hue/Saturation dialog is open." }
        if s.levels != nil { return "The Levels dialog is open." }
        if s.colorRange != nil { return "The Color Range dialog is open." }
        if s.selectionAmountOperation != nil { return "A Modify Selection dialog is open." }
        if let dialog = s.commandDialog {
            switch dialog {
            case .fill: return "The Fill dialog is open."
            case .loadSelection: return "The Load Selection dialog is open."
            case .lockLayers: return "The Lock Layers dialog is open."
            }
        }
        if s.colorPicker != nil { return "The color picker is open." }
        if s.layerStyle != nil { return "The Layer Style dialog is open." }
        if s.cropRect != nil { return "A crop is in progress." }
        if s.gradientEdit != nil { return "A gradient is waiting to be applied." }
        if s.pixelMove != nil { return "Pixels are being moved." }
        if s.brushStroke != nil || s.warpStroke != nil { return "A brush stroke is in progress." }
        if s.shapeDraft != nil || s.lassoDraft != nil || s.guideDrag != nil || s.selectionMoveOrigin != nil || s.opacityEditLayerID != nil
            || s.propertyEdit != nil {
            return "Something is being dragged or edited on the canvas."
        }
        if s.renamingLayerID != nil { return "A layer is being renamed." }
        if s.showsNewDocument || s.showsImporter || s.isImporting || s.showsConversionSheet { return "An import or New Canvas dialog is open." }
        if s.importError != nil || s.brushError != nil { return "An error message is showing." }
        if s.isProjectBusy { return "The document is busy saving or applying an edit." }
        if workspace.window?.attachedSheet != nil || NSApp?.modalWindow != nil { return "A dialog is open." }
        return nil
    }

    func requireIdle(_ tab: ProjectTab) throws {
        if let reason = busyReason(tab) {
            throw AutomationError(.busy, "\(reason) Commands that change the document wait until it's finished; try again then.")
        }
    }

    func requireRevision(_ arguments: Arguments, _ session: EditorSession) throws {
        guard let expected = arguments.string("expect_revision") else { return }
        let current = ShortID.hex(session.history.currentRevision)
        guard current.hasPrefix(expected) else {
            throw AutomationError(.conflict, "The document changed: it is at revision \(current.prefix(8)), not \(expected).")
        }
    }

    // MARK: Edits

    /// Runs an edit on the document the arguments name, once nothing else is in progress, and reports what it did.
    /// `body` returns the layer it made or changed, if any.
    func edit(_ arguments: Arguments, _ body: (ProjectTab) async throws -> UUID?) async throws -> JSONValue {
        let tab = try tab(arguments)
        try requireIdle(tab)
        try requireRevision(arguments, tab.session)
        let before = tab.session.document
        let revisionBefore = tab.session.history.currentRevision
        let layer = try await body(tab)
        return change(tab, from: before, revision: revisionBefore, layer: layer)
    }

    /// What an edit changed: its undo step and the layers added, removed and modified (#91's change summaries).
    func change(_ tab: ProjectTab, from before: CanvasDocument?, revision: UUID, layer: UUID?) -> JSONValue {
        let session = tab.session
        let old = Dictionary((before?.layers ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let new = session.document?.layers ?? []
        let ids = ShortID.prefixes(Set(old.keys).union(new.map(\.id)))
        let current = Set(new.map(\.id))
        func short(_ list: [UUID]) -> JSONValue { .array(list.map { .string(ids[$0] ?? ShortID.hex($0)) }) }
        var result: [String: JSONValue] = [
            "document": .string(documentID(tab)),
            "revision": .string(self.revision(session)),
            "changed": .bool(session.history.currentRevision != revision),
            "undo": session.history.undoName.isEmpty ? .null : .string(session.history.undoName),
            "added": short(new.map(\.id).filter { old[$0] == nil }),
            "removed": short((before?.layers ?? []).map(\.id).filter { !current.contains($0) }),
            "modified": short(new.filter { layer in old[layer.id].map { $0 != layer } ?? false }.map(\.id)),
            "active_layer": session.activeLayerID.map { .string(ids[$0] ?? ShortID.hex($0)) } ?? .null,
        ]
        if let layer { result["layer"] = .string(ids[layer] ?? ShortID.hex(layer)) }
        return .object(result)
    }
}
