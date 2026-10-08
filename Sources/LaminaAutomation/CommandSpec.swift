import Foundation

/// One parameter of a command (or one setting of a filter): its JSON name, type, limits and help. The CLI derives
/// its `--flag` from the name, the MCP server its input schema, and the app validates requests against it.
public struct ParameterSpec: Sendable {
    public enum ValueType: Sendable {
        case string
        /// A document or layer id: the full id or any unique prefix of at least four characters.
        case id
        case integer(ClosedRange<Int>)
        case number(ClosedRange<Double>)
        case boolean
        case choice([String])
        /// An sRGB color written `#rrggbb`.
        case color
        /// An object of settings whose keys depend on another parameter (a filter's `kind`); see `settingsFor`.
        case settings
        /// A file path on this Mac. `lamina` reads or writes it; the sandboxed app never sees it.
        case path
    }

    public let name: String
    public let type: ValueType
    public let summary: String
    public let isRequired: Bool
    /// What the app uses when the parameter is left out, shown in help and schemas. Nil when the default depends
    /// on the app's state (the summary then says what it is).
    public let defaultValue: JSONValue?

    public init(_ name: String, _ type: ValueType, _ summary: String, required: Bool = false, default defaultValue: JSONValue? = nil) {
        self.name = name
        self.type = type
        self.summary = summary
        self.isRequired = required
        self.defaultValue = defaultValue
    }

    /// The command-line spelling: `max_size` is `--max-size`.
    public var flag: String { "--" + name.replacingOccurrences(of: "_", with: "-") }

    /// Handled by `lamina` itself, never sent to the app.
    public var isClientSide: Bool { if case .path = type { return true }; return false }

    /// A short description of the accepted values, for help text.
    public var typeDescription: String {
        switch type {
        case .string: "text"
        case .id: "id"
        case .integer(let range): "integer \(range.lowerBound)–\(range.upperBound)"
        case .number(let range): "number \(Self.format(range.lowerBound))–\(Self.format(range.upperBound))"
        case .boolean: "true or false"
        case .choice(let values): values.joined(separator: " | ")
        case .color: "#rrggbb"
        case .settings: "settings"
        case .path: "path"
        }
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    /// JSON Schema (2020-12) for this parameter.
    public var jsonSchema: JSONValue {
        var schema: [String: JSONValue] = ["description": .string(summary)]
        switch type {
        case .string, .id, .path: schema["type"] = "string"
        case .integer(let range):
            schema["type"] = "integer"
            schema["minimum"] = JSONValue(range.lowerBound)
            schema["maximum"] = JSONValue(range.upperBound)
        case .number(let range):
            schema["type"] = "number"
            schema["minimum"] = JSONValue(range.lowerBound)
            schema["maximum"] = JSONValue(range.upperBound)
        case .boolean: schema["type"] = "boolean"
        case .choice(let values): schema["type"] = "string"; schema["enum"] = .array(values.map { .string($0) })
        case .color: schema["type"] = "string"; schema["pattern"] = "^#[0-9A-Fa-f]{6}$"
        case .settings: schema["type"] = "object"
        }
        if let defaultValue { schema["default"] = defaultValue }
        return .object(schema)
    }

    /// Checks one value against this parameter, returning it normalized (ids and colors lowercased).
    public func validate(_ value: JSONValue, in context: String = "") throws -> JSONValue {
        let label = context.isEmpty ? name : "\(context).\(name)"
        func fail(_ problem: String) -> AutomationError { .invalid("\(label) \(problem).") }
        switch type {
        case .string, .path:
            guard let text = value.stringValue else { throw fail("must be text") }
            if case .path = type, text.isEmpty { throw fail("can't be empty") }
            return value
        case .id:
            guard let text = value.stringValue else { throw fail("must be an id (text)") }
            let normalized = ShortID.normalize(text)
            guard normalized.count >= ShortID.minimumInput, normalized.allSatisfy(\.isHexDigit) else {
                throw fail("must be an id: at least \(ShortID.minimumInput) hexadecimal characters")
            }
            return .string(normalized)
        case .integer(let range):
            guard let number = value.intValue else { throw fail("must be a whole number") }
            guard range.contains(number) else { throw fail("must be between \(range.lowerBound) and \(range.upperBound)") }
            return value
        case .number(let range):
            guard let number = value.doubleValue, number.isFinite else { throw fail("must be a number") }
            guard range.contains(number) else {
                throw fail("must be between \(Self.format(range.lowerBound)) and \(Self.format(range.upperBound))")
            }
            return value
        case .boolean:
            guard value.boolValue != nil else { throw fail("must be true or false") }
            return value
        case .choice(let values):
            guard let text = value.stringValue, values.contains(text) else { throw fail("must be one of: \(values.joined(separator: ", "))") }
            return value
        case .color:
            guard let text = value.stringValue, Self.rgb(text) != nil else { throw fail("must be a color written #rrggbb") }
            return .string(text.lowercased())
        case .settings:
            guard value.objectValue != nil else { throw fail("must be an object") }
            return value
        }
    }

    /// `#rrggbb` as 0–1 channels.
    public static func rgb(_ text: String) -> (red: Double, green: Double, blue: Double)? {
        let hex = text.hasPrefix("#") ? text.dropFirst() : Substring(text)
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }
}

/// One command: its name, parameters and result, defined once for the app, `lamina` and the MCP server.
public struct CommandSpec: Sendable {
    public enum Effect: Sendable {
        /// Only reads the app's state.
        case reads
        /// Changes a document: one undo step in the app.
        case edits
        /// Changes what's selected or shown, not the document: no undo step, as in the app.
        case selects
    }

    /// A result that carries a file's bytes (base64 in `data`), which `lamina` writes to the path in `parameter`.
    public struct FileOutput: Sendable {
        public let parameter: String
        public let mimeTypes: [String: String]
    }

    public let name: String
    public let title: String
    public let summary: String
    public let details: String
    public let parameters: [ParameterSpec]
    public let result: Schema
    public let effect: Effect
    public let fileOutput: FileOutput?
    /// For commands with `kind` and `settings` parameters: the kinds, whose settings `settings` is checked against.
    public let kinds: [EffectKind]

    public init(name: String, title: String, summary: String, details: String = "", parameters: [ParameterSpec],
                result: Schema, effect: Effect, fileOutput: FileOutput? = nil, kinds: [EffectKind] = []) {
        self.name = name
        self.title = title
        self.summary = summary
        self.details = details
        self.parameters = parameters
        self.result = result
        self.effect = effect
        self.fileOutput = fileOutput
        self.kinds = kinds
    }

    /// The kind the arguments name, for commands that take one.
    public func kind(_ arguments: Arguments) -> EffectKind? {
        arguments.string("kind").flatMap { name in kinds.first { $0.name == name } }
    }

    /// The MCP tool name: `apply-filter` is `apply_filter`.
    public var toolName: String { name.replacingOccurrences(of: "-", with: "_") }
    public var isReadOnly: Bool { effect == .reads }
    public var writesFiles: Bool { fileOutput != nil }

    public func parameter(_ name: String) -> ParameterSpec? { parameters.first { $0.name == name } }

    /// JSON Schema (2020-12) for the arguments.
    public var inputSchema: JSONValue {
        [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": .object(Dictionary(uniqueKeysWithValues: parameters.map { ($0.name, $0.jsonSchema) })),
            "required": .array(parameters.filter(\.isRequired).map { .string($0.name) }),
            "additionalProperties": false,
        ]
    }

    /// Checks arguments against the parameters: rejects unknown names, missing required ones and wrong values, and
    /// fills in defaults. With `includingClientSide: false`, file paths are left out (the app never gets them).
    public func validate(_ arguments: [String: JSONValue], includingClientSide: Bool = true) throws -> Arguments {
        let known = Set(parameters.map(\.name))
        if let unknown = arguments.keys.sorted().first(where: { !known.contains($0) }) {
            throw AutomationError.invalid("\(name) has no parameter \(unknown). Parameters: \(parameters.map(\.name).joined(separator: ", ")).")
        }
        var values: [String: JSONValue] = [:]
        for parameter in parameters where includingClientSide || !parameter.isClientSide {
            if let value = arguments[parameter.name], !value.isNull {
                values[parameter.name] = try parameter.validate(value)
            } else if parameter.isRequired {
                throw AutomationError.invalid("\(name) needs \(parameter.name) (\(parameter.flag)).")
            } else if let fallback = parameter.defaultValue {
                values[parameter.name] = fallback
            }
        }
        if let settings = values["settings"]?.objectValue, let kind = kind(Arguments(values)) {
            values["settings"] = try kind.validate(settings).json
        }
        return Arguments(values)
    }
}

/// Validated arguments, with typed access. Missing optional values read as nil.
public struct Arguments: Sendable {
    public let values: [String: JSONValue]
    public init(_ values: [String: JSONValue]) { self.values = values }
    public subscript(name: String) -> JSONValue? { values[name] }
    public func string(_ name: String) -> String? { values[name]?.stringValue }
    public func int(_ name: String) -> Int? { values[name]?.intValue }
    public func double(_ name: String) -> Double? { values[name]?.doubleValue }
    public func bool(_ name: String) -> Bool? { values[name]?.boolValue }
    public func object(_ name: String) -> [String: JSONValue]? { values[name]?.objectValue }
    public func color(_ name: String) -> (red: Double, green: Double, blue: Double)? { string(name).flatMap(ParameterSpec.rgb) }
    /// The value to pass on: these arguments as one JSON object.
    public var json: JSONValue { .object(values) }
}
