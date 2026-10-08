import Foundation

/// The shape of a command's result, written once: it becomes the MCP tool's output schema (JSON Schema 2020-12)
/// and tests check every real result against it.
public indirect enum Schema: Sendable {
    case string
    case integer
    case number
    case boolean
    case choice([String])
    case array(Schema)
    case object([Field])
    /// A value that can also be null.
    case nullable(Schema)

    public struct Field: Sendable {
        public let name: String
        public let schema: Schema
        public let summary: String
        public let isRequired: Bool
        public init(_ name: String, _ schema: Schema, _ summary: String, required: Bool = true) {
            self.name = name
            self.schema = schema
            self.summary = summary
            self.isRequired = required
        }
    }

    /// JSON Schema (draft 2020-12).
    public var jsonSchema: JSONValue { jsonSchema(summary: nil) }

    func jsonSchema(summary: String?) -> JSONValue {
        var result: [String: JSONValue]
        switch self {
        case .string: result = ["type": "string"]
        case .integer: result = ["type": "integer"]
        case .number: result = ["type": "number"]
        case .boolean: result = ["type": "boolean"]
        case .choice(let values): result = ["type": "string", "enum": .array(values.map { .string($0) })]
        case .array(let item): result = ["type": "array", "items": item.jsonSchema]
        case .object(let fields):
            result = [
                "type": "object",
                "properties": .object(Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.schema.jsonSchema(summary: $0.summary)) })),
                "required": .array(fields.filter(\.isRequired).map { .string($0.name) }),
            ]
        case .nullable(let wrapped):
            guard case .object(var inner) = wrapped.jsonSchema(summary: nil) else { return wrapped.jsonSchema }
            if case .string(let type)? = inner["type"] { inner["type"] = [.string(type), "null"] }
            if case .array(let values)? = inner["enum"] { inner["enum"] = .array(values + [.null]) }
            result = inner
        }
        if let summary { result["description"] = .string(summary) }
        return .object(result)
    }

    /// Where `value` departs from this schema, as `path: problem` lines; empty when it conforms. Fields not in the
    /// schema are allowed, as in JSON Schema without `additionalProperties`.
    public func violations(of value: JSONValue, at path: String = "$") -> [String] {
        switch (self, value) {
        case (.nullable, .null): return []
        case (.nullable(let wrapped), _): return wrapped.violations(of: value, at: path)
        case (.string, .string), (.boolean, .bool), (.number, .number): return []
        case (.integer, .number): return value.intValue == nil ? ["\(path): expected an integer"] : []
        case (.choice(let values), .string(let text)):
            return values.contains(text) ? [] : ["\(path): \(text) is not one of \(values.joined(separator: ", "))"]
        case (.array(let item), .array(let items)):
            return items.enumerated().flatMap { item.violations(of: $1, at: "\(path)[\($0)]") }
        case (.object(let fields), .object(let object)):
            return fields.flatMap { field -> [String] in
                guard let member = object[field.name] else { return field.isRequired ? ["\(path).\(field.name): missing"] : [] }
                return field.schema.violations(of: member, at: "\(path).\(field.name)")
            }
        default: return ["\(path): expected \(typeName), got \(value.typeName)"]
        }
    }

    var typeName: String {
        switch self {
        case .string, .choice: "string"
        case .integer: "integer"
        case .number: "number"
        case .boolean: "boolean"
        case .array: "array"
        case .object: "object"
        case .nullable(let wrapped): "\(wrapped.typeName) or null"
        }
    }
}
