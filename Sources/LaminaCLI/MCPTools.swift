import Foundation
import LaminaAutomation

/// The MCP tools: one per catalog command, made from its definition, so adding a command adds its tool.
public enum MCPTools {
    /// Every tool, in catalog order (MCP asks for a deterministic order).
    public static var all: [JSONValue] { CommandCatalog.commands.map(tool) }

    public static func tool(_ spec: CommandSpec) -> JSONValue {
        var description = spec.summary
        if !spec.details.isEmpty { description += "\n\n" + spec.details }
        if spec.fileOutput != nil {
            description += "\n\nGive output as an absolute path; an existing file there is replaced."
        }
        var output = spec.result.jsonSchema
        if case .object(var object) = output {
            object["$schema"] = "https://json-schema.org/draft/2020-12/schema"
            output = .object(object)
        }
        return [
            "name": .string(spec.toolName),
            "title": .string(spec.title),
            "description": .string(description),
            "inputSchema": spec.inputSchema,
            "outputSchema": output,
            "annotations": annotations(spec),
        ]
    }

    /// Hints from what the command does: reading only, adding, editing (undoable, but it changes pixels or history),
    /// selecting, or writing a file (export and preview replace the file at `output`).
    static func annotations(_ spec: CommandSpec) -> JSONValue {
        var hints: [String: JSONValue] = ["title": .string(spec.title), "openWorldHint": false]
        if spec.fileOutput != nil {
            hints["readOnlyHint"] = false
            hints["destructiveHint"] = true
            hints["idempotentHint"] = true
            return .object(hints)
        }
        switch spec.effect {
        case .reads:
            hints["readOnlyHint"] = true
        case .selects:
            hints["readOnlyHint"] = false
            hints["destructiveHint"] = false
            hints["idempotentHint"] = true
        case .adds:
            hints["readOnlyHint"] = false
            hints["destructiveHint"] = false
            hints["idempotentHint"] = false
        case .edits:
            hints["readOnlyHint"] = false
            hints["destructiveHint"] = true
            hints["idempotentHint"] = false
        }
        return .object(hints)
    }

    /// For the model, sent with `server/discover` and `initialize`.
    public static let instructions = """
    These tools control the \(AppIdentity.displayName) image editor that is running on this Mac (it must already be \
    open). Start with list_documents: it gives each open document's id and its layers' ids (short prefixes; pass \
    them as they are). apply_filter changes a layer's pixels and add_adjustment_layer adds a non-destructive \
    adjustment; each edit is one undo step, and undo reverts it. Edits are refused (busy) while the person is in \
    the middle of something in the app; tell them and retry later rather than looping. render_preview returns the \
    image so you can look at the result; export_document writes a PNG or JPEG to the absolute path you give. Pass \
    expect_revision from an earlier result to avoid overwriting changes the person made meanwhile.
    """
}
