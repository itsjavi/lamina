import Foundation

/// Any JSON value. Requests, results and schemas travel as these, so the app, the `lamina` tool and its MCP server
/// share one representation and nothing depends on `JSONSerialization`'s untyped dictionaries.
public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { return object[key] }
        return nil
    }
    public var stringValue: String? { if case .string(let value) = self { return value }; return nil }
    public var boolValue: Bool? { if case .bool(let value) = self { return value }; return nil }
    public var doubleValue: Double? { if case .number(let value) = self { return value }; return nil }
    /// The number when it is a whole one (JSON has no separate integer type).
    public var intValue: Int? {
        guard case .number(let value) = self, value.rounded() == value, abs(value) <= 9_007_199_254_740_992 else { return nil }
        return Int(value)
    }
    public var arrayValue: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    public var isNull: Bool { self == .null }

    /// The JSON type's name, for error messages.
    public var typeName: String {
        switch self {
        case .null: "null"
        case .bool: "boolean"
        case .number: "number"
        case .string: "string"
        case .array: "array"
        case .object: "object"
        }
    }

    /// Compact (or indented) JSON with sorted keys, so output is stable from run to run.
    public func encoded(pretty: Bool = false) -> Data {
        if pretty { return Data(indented("").utf8) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding a JSONValue can't fail: every case maps to plain JSON and numbers are finite (see `encode`).
        return (try? encoder.encode(self)) ?? Data("null".utf8)
    }
    public func encodedString(pretty: Bool = false) -> String { String(decoding: encoded(pretty: pretty), as: UTF8.self) }

    /// Two-space indented JSON, `"key": value`, with empty arrays and objects kept on one line.
    private func indented(_ indent: String) -> String {
        let inner = indent + "  "
        switch self {
        case .array(let items) where !items.isEmpty:
            return "[\n" + items.map { inner + $0.indented(inner) }.joined(separator: ",\n") + "\n\(indent)]"
        case .object(let object) where !object.isEmpty:
            return "{\n" + object.keys.sorted().map { key in
                inner + JSONValue.string(key).encodedString() + ": " + object[key]!.indented(inner)
            }.joined(separator: ",\n") + "\n\(indent)}"
        default:
            return encodedString()
        }
    }

    public static func decode(_ data: Data) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data) }
    public static func decode(_ text: String) throws -> JSONValue { try decode(Data(text.utf8)) }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a JSON value.") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value):
            // Whole numbers are written without a fraction (4, not 4.0); JSON can't hold NaN or infinity.
            if value.rounded() == value, abs(value) < 1e15 { try container.encode(Int64(value)) }
            else if value.isFinite { try container.encode(value) }
            else { try container.encodeNil() }
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

public extension JSONValue {
    init(_ value: Int) { self = .number(Double(value)) }
    init(_ value: Double) { self = .number(value) }
    init(_ value: String?) { self = value.map { .string($0) } ?? .null }
    init(_ value: Bool) { self = .bool(value) }
}
