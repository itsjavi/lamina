import Foundation

/// Every command the running app answers, defined once. `lamina` builds its subcommands, flags and help from these,
/// the MCP server its tools, and the app checks requests against them; adding a command here (and its handler in
/// the app) adds it everywhere.
public enum CommandCatalog {
    public static let commands: [CommandSpec] = [
        listDocuments, describeDocument, selectLayer, applyFilter, addAdjustmentLayer, exportDocument, renderPreview, undo, redo,
    ]

    public static func command(_ name: String) -> CommandSpec? {
        commands.first { $0.name == name || $0.toolName == name }
    }

    // MARK: Parameters several commands share

    static let document = ParameterSpec("document", .id, "The document's id, from list-documents.", required: true)
    static let expectRevision = ParameterSpec("expect_revision", .id,
        "Refuse (conflict) unless the document is still at this revision, from an earlier result; guards against edits made meanwhile.")

    // MARK: Results

    static let layerFields: [Schema.Field] = [
        .init("id", .string, "The layer's id: a unique prefix of its UUID."),
        .init("name", .string, "The name in the Layers panel."),
        .init("type", .choice(["pixels", "empty", "group", "adjustment", "text", "shape"]), "What the layer is."),
        .init("visible", .boolean, "Whether its eye is on in the Layers panel."),
        .init("parent", .nullable(.string), "The folder it is in, or null at the top level."),
        .init("depth", .integer, "How many folders deep it is."),
        .init("adjustment", .string, "For adjustment layers, the kind (see add-adjustment-layer).", required: false),
    ]

    static let documentFields: [Schema.Field] = [
        .init("id", .string, "The document's id for this session of the app: a unique prefix."),
        .init("title", .string, "The name on its tab."),
        .init("path", .nullable(.string), "Where its project is saved, or null if it never was."),
        .init("front", .boolean, "Whether its tab is the one on screen."),
        .init("modified", .boolean, "Whether it has unsaved changes."),
        .init("revision", .string, "Changes with every edit (and back with undo); see expect_revision."),
        .init("width", .nullable(.integer), "Canvas width in pixels, or null for an empty tab."),
        .init("height", .nullable(.integer), "Canvas height in pixels, or null for an empty tab."),
        .init("active_layer", .nullable(.string), "The selected layer, which menu commands act on."),
    ]

    static let bounds: Schema = .object([
        .init("x", .number, "Left edge in document pixels."),
        .init("y", .number, "Top edge in document pixels."),
        .init("width", .number, "Width in document pixels."),
        .init("height", .number, "Height in document pixels."),
    ])

    /// What an edit did: the undo step it made and the layers it touched.
    static let change: Schema = .object([
        .init("document", .string, "The document's id."),
        .init("revision", .string, "The document's revision after the command."),
        .init("changed", .boolean, "False when the command left the document as it was (no undo step)."),
        .init("undo", .nullable(.string), "The name of the undo step now on top of the document's history."),
        .init("added", .array(.string), "Layers added."),
        .init("removed", .array(.string), "Layers removed."),
        .init("modified", .array(.string), "Layers changed."),
        .init("active_layer", .nullable(.string), "The selected layer afterwards."),
        .init("layer", .string, "The layer the command made or changed.", required: false),
    ])

    // MARK: Commands

    static let listDocuments = CommandSpec(
        name: "list-documents", title: "List documents",
        summary: "List the open documents (tabs) and their layers.",
        details: "Layers are listed top to bottom, as in the Layers panel. Ids are short unique prefixes; any longer prefix works too.",
        parameters: [ParameterSpec("layers", .boolean, "Include each document's layers.", default: true)],
        result: .object([.init("documents", .array(.object(documentFields + [
            .init("layers", .array(.object(layerFields)), "Its layers, top to bottom.", required: false),
        ])), "Open documents, in tab order.")]),
        effect: .reads)

    static let describeDocument = CommandSpec(
        name: "describe-document", title: "Describe a document",
        summary: "Describe one document: canvas, selection, history and every layer in detail.",
        parameters: [document],
        result: .object(documentFields + [
            .init("resolution", .nullable(.number), "Pixels per inch."),
            .init("selected_layers", .array(.string), "Every selected layer (several when Shift- or Cmd-clicked)."),
            .init("mask_selected", .boolean, "Whether the active layer's mask, not its pixels, is the target."),
            .init("selection", .nullable(bounds), "The bounds of the marching-ants selection, or null when nothing is selected."),
            .init("undo", .nullable(.string), "What Undo would undo."),
            .init("redo", .nullable(.string), "What Redo would redo."),
            .init("busy", .nullable(.string), "Why edits would be refused right now (someone is mid-edit), or null."),
            .init("layers", .array(.object(layerFields + [
                .init("opacity", .number, "Opacity, 0–1."),
                .init("blend_mode", .string, "Blend mode, as named in the app."),
                .init("bounds", bounds, "Where the layer sits, before rotation."),
                .init("rotation", .number, "Rotation in degrees."),
                .init("mask", .nullable(.object([
                    .init("enabled", .boolean, "Whether the mask applies."),
                    .init("linked", .boolean, "Whether it moves with the layer."),
                ])), "The layer mask, or null."),
                .init("effects", .array(.string), "Layer effects (stroke, shadows, glows…)."),
                .init("text", .nullable(.string), "A live text layer's text."),
            ])), "Layers, top to bottom."),
        ]),
        effect: .reads)

    static let selectLayer = CommandSpec(
        name: "select-layer", title: "Select a layer",
        summary: "Select a layer (or its mask), as clicking it in the Layers panel does.",
        details: "Selecting isn't an undo step, as in the app.",
        parameters: [
            document,
            ParameterSpec("layer", .id, "The layer's id.", required: true),
            ParameterSpec("mask", .boolean, "Select the layer's mask instead of its pixels.", default: false),
        ],
        result: .object([
            .init("document", .string, "The document's id."),
            .init("active_layer", .string, "The selected layer."),
            .init("mask_selected", .boolean, "Whether its mask is the target."),
        ]),
        effect: .selects)

    static let applyFilter = CommandSpec(
        name: "apply-filter", title: "Apply a filter",
        summary: "Apply a filter or image adjustment to a layer's pixels, as one undo step.",
        details: """
        Runs as the Filter and Image › Adjustments menus do: on the layer (which becomes the selected one), inside \
        the selection if there is one. Settings left out take the defaults below, not the last ones used in the app.
        Kinds and settings:
        \(EffectCatalog.filters.map { "  " + $0.settingsHelp }.joined(separator: "\n"))
        """,
        parameters: [
            document,
            ParameterSpec("layer", .id, "The pixel layer to filter.", required: true),
            ParameterSpec("kind", .choice(EffectCatalog.filters.map(\.name)), "Which filter.", required: true),
            ParameterSpec("settings", .settings, "The filter's settings as an object, e.g. {\"radius\": 4}; see the list of kinds."),
            expectRevision,
        ],
        result: change, effect: .edits, kinds: EffectCatalog.filters)

    static let addAdjustmentLayer = CommandSpec(
        name: "add-adjustment-layer", title: "Add an adjustment layer",
        summary: "Add an adjustment layer, which changes everything below it without touching pixels, as one undo step.",
        details: """
        As Layer › New Adjustment Layer: it goes above the selected layer, or above the layer given. Settings left \
        out take the defaults below.
        Kinds and settings:
        \(EffectCatalog.adjustments.map { "  " + $0.settingsHelp }.joined(separator: "\n"))
        """,
        parameters: [
            document,
            ParameterSpec("kind", .choice(EffectCatalog.adjustments.map(\.name)), "Which adjustment.", required: true),
            ParameterSpec("settings", .settings, "The adjustment's settings as an object, e.g. {\"exposure\": 0.5}; see the list of kinds."),
            ParameterSpec("above", .id, "Put it above this layer (default: above the selected layer)."),
            expectRevision,
        ],
        result: change, effect: .edits, kinds: EffectCatalog.adjustments)

    static let exportDocument = CommandSpec(
        name: "export-document", title: "Export a document",
        summary: "Export the flattened image to a PNG or JPEG file, as File › Export does.",
        details: "The app renders and encodes it; lamina writes the file (the sandboxed app can't write where it likes).",
        parameters: [
            document,
            ParameterSpec("output", .path, "The file to write; an existing file is replaced.", required: true),
            ParameterSpec("format", .choice(["png", "jpeg"]), "Image format (default: from output's extension, .jpg or .jpeg for JPEG, else PNG)."),
            ParameterSpec("quality", .number(0...1), "JPEG quality.", default: 0.85),
            ParameterSpec("background", .color, "JPEG: the color transparent areas become.", default: "#ffffff"),
        ],
        result: .object([
            .init("document", .string, "The document's id."),
            .init("format", .choice(["png", "jpeg"]), "The image format."),
            .init("width", .integer, "Width in pixels."),
            .init("height", .integer, "Height in pixels."),
            .init("bytes", .integer, "File size."),
            .init("path", .string, "The file written.", required: false),
        ]),
        effect: .reads,
        fileOutput: .init(parameter: "output", mimeTypes: ["png": "image/png", "jpeg": "image/jpeg"]))

    static let renderPreview = CommandSpec(
        name: "render-preview", title: "Render a preview",
        summary: "Render the flattened document as a PNG no larger than max_size on its longest side.",
        details: "Shows what is committed: an open dialog's preview isn't included.",
        parameters: [
            document,
            ParameterSpec("max_size", .integer(16...4096), "Longest side in pixels; smaller documents keep their size.", default: 1024),
            ParameterSpec("output", .path, "The PNG file to write (an MCP host can show the image instead)."),
        ],
        result: .object([
            .init("document", .string, "The document's id."),
            .init("width", .integer, "Preview width in pixels."),
            .init("height", .integer, "Preview height in pixels."),
            .init("source_width", .integer, "Canvas width."),
            .init("source_height", .integer, "Canvas height."),
            .init("bytes", .integer, "PNG size."),
            .init("path", .string, "The file written.", required: false),
        ]),
        effect: .reads,
        fileOutput: .init(parameter: "output", mimeTypes: ["png": "image/png"]))

    static let undo = CommandSpec(
        name: "undo", title: "Undo",
        summary: "Undo the document's last change (Edit › Undo).",
        parameters: [document, expectRevision],
        result: change, effect: .edits)

    static let redo = CommandSpec(
        name: "redo", title: "Redo",
        summary: "Redo the change last undone (Edit › Redo).",
        parameters: [document, expectRevision],
        result: change, effect: .edits)
}
