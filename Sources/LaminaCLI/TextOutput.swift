import Foundation
import LaminaAutomation

/// Results as text for people: documents and layers as indented lists, everything else as `name: value` lines.
/// `--json` prints the result itself.
public enum TextOutput {
    public static func render(_ result: JSONValue) -> String {
        guard case .object(let object) = result else { return Help.describe(result) }
        if case .array(let documents)? = object["documents"] {
            return documents.isEmpty ? "No documents are open." : documents.map(document).joined(separator: "\n\n")
        }
        if object["title"] != nil, object["layers"] != nil { return document(result) }
        return fields(object, skipping: [])
    }

    static func document(_ value: JSONValue) -> String {
        guard case .object(let object) = value else { return "" }
        var header = [object["id"]?.stringValue ?? "", object["title"]?.stringValue ?? ""]
        if let width = object["width"]?.intValue, let height = object["height"]?.intValue { header.append("\(width)×\(height)") }
        else { header.append("(no canvas)") }
        if object["front"]?.boolValue == true { header.append("front") }
        if object["modified"]?.boolValue == true { header.append("modified") }
        var lines = [header.joined(separator: "  ")]
        let skipped: Set<String> = ["id", "title", "width", "height", "front", "modified", "layers"]
        let rest = fields(object, skipping: skipped)
        if !rest.isEmpty { lines.append(rest.split(separator: "\n").map { "  " + $0 }.joined(separator: "\n")) }
        if case .array(let layers)? = object["layers"] {
            lines.append(layers.isEmpty ? "  (no layers)" : "  layers, top to bottom:")
            for case .object(let layer) in layers {
                let indent = String(repeating: "  ", count: 2 + (layer["depth"]?.intValue ?? 0))
                var line = "\(indent)\(layer["id"]?.stringValue ?? "")  \(layer["name"]?.stringValue ?? "")"
                var notes = [layer["adjustment"]?.stringValue.map { "adjustment: \($0)" } ?? layer["type"]?.stringValue ?? ""]
                if layer["visible"]?.boolValue == false { notes.append("hidden") }
                if let id = layer["id"]?.stringValue, id == object["active_layer"]?.stringValue { notes.append("selected") }
                if let opacity = layer["opacity"]?.doubleValue, opacity < 1 { notes.append("opacity \(Int((opacity * 100).rounded()))%") }
                if let mode = layer["blend_mode"]?.stringValue, mode != "Normal" { notes.append(mode) }
                if layer["mask"]?.objectValue != nil { notes.append("mask") }
                if case .array(let effects)? = layer["effects"], !effects.isEmpty {
                    notes.append(effects.compactMap(\.stringValue).joined(separator: ", "))
                }
                if let text = layer["text"]?.stringValue { notes.append("\"\(text)\"") }
                line += "  (\(notes.joined(separator: ", ")))"
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// `name: value` lines, nested objects indented; empty lists and nulls are left out.
    static func fields(_ object: [String: JSONValue], skipping: Set<String>, indent: String = "") -> String {
        object.keys.sorted().filter { !skipping.contains($0) }.compactMap { key -> String? in
            switch object[key]! {
            case .null: return nil
            case .array(let items):
                if items.isEmpty { return nil }
                if items.allSatisfy({ $0.objectValue == nil }) { return "\(indent)\(key): \(items.map(Help.describe).joined(separator: ", "))" }
                return "\(indent)\(key):\n" + items.map { item in
                    item.objectValue.map { fields($0, skipping: [], indent: indent + "  ") } ?? "\(indent)  \(Help.describe(item))"
                }.joined(separator: "\n")
            case .object(let nested):
                return "\(indent)\(key):\n" + fields(nested, skipping: [], indent: indent + "  ")
            case let value:
                return "\(indent)\(key): \(Help.describe(value))"
            }
        }.joined(separator: "\n")
    }
}
