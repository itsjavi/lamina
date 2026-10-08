import Foundation
import Testing
@testable import LaminaAutomation

struct CatalogTests {
    @Test func commandAndToolNamesAreUniqueAndWellFormed() {
        let names = CommandCatalog.commands.map(\.name)
        #expect(Set(names).count == names.count)
        for spec in CommandCatalog.commands {
            #expect(spec.name.allSatisfy { $0.isLowercase || $0 == "-" }, "\(spec.name) is kebab-case")
            #expect(spec.toolName.range(of: "^[a-z_]{1,64}$", options: .regularExpression) != nil, "\(spec.toolName) is a valid MCP tool name")
            #expect(CommandCatalog.command(spec.name)?.name == spec.name)
            #expect(CommandCatalog.command(spec.toolName)?.name == spec.name)
            let parameters = spec.parameters.map(\.name)
            #expect(Set(parameters).count == parameters.count, "\(spec.name)'s parameters are unique")
            for parameter in spec.parameters {
                #expect(parameter.name.allSatisfy { $0.isLowercase || $0 == "_" }, "\(spec.name).\(parameter.name) is snake_case")
                #expect(!(parameter.isRequired && parameter.defaultValue != nil), "\(spec.name).\(parameter.name): required or defaulted")
                if let fallback = parameter.defaultValue { #expect(throws: Never.self) { try parameter.validate(fallback) } }
            }
            if spec.fileOutput != nil { #expect(spec.parameter(spec.fileOutput!.parameter)?.isClientSide == true) }
            if !spec.kinds.isEmpty {
                #expect(spec.parameter("kind") != nil && spec.parameter("settings") != nil)
                if case .choice(let kinds)? = spec.parameter("kind")?.type { #expect(kinds == spec.kinds.map(\.name)) }
            }
        }
    }

    @Test func everySettingsDefaultIsValidForItsKind() throws {
        for kind in EffectCatalog.filters + EffectCatalog.adjustments {
            let defaults = Dictionary(uniqueKeysWithValues: kind.settings.compactMap { setting in setting.defaultValue.map { (setting.name, $0) } })
            let checked = try kind.validate(defaults)
            #expect(checked.values.count == defaults.count, "\(kind.name)")
            #expect(kind.settingsHelp.hasPrefix(kind.name))
        }
    }

    @Test func validationFillsDefaultsAndRejectsWhatDoesntFit() throws {
        let spec = try #require(CommandCatalog.command("render-preview"))
        let arguments = try spec.validate(["document": "3F2A-9C1B"])
        #expect(arguments.string("document") == "3f2a9c1b", "ids are normalized")
        #expect(arguments.int("max_size") == 1024, "defaults are filled in")
        #expect(throws: AutomationError.self) { try spec.validate([:]) }
        #expect(throws: AutomationError.self) { try spec.validate(["document": "3f2a", "max_size": 5]) }
        #expect(throws: AutomationError.self) { try spec.validate(["document": "3f2a", "max_size": 10.5]) }
        #expect(throws: AutomationError.self) { try spec.validate(["document": "xyz!"]) }
        #expect(throws: AutomationError.self) { try spec.validate(["document": "3f2a", "colour": "red"]) }
        // Paths stay with lamina: the app validates without them.
        let sent = try spec.validate(["document": "3f2a", "output": "/tmp/x.png"], includingClientSide: false)
        #expect(sent["output"] == nil)

        let filter = try #require(CommandCatalog.command("apply_filter"))
        let blur = try filter.validate(["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": ["radius": 4]])
        #expect(blur.object("settings") == ["radius": 4])
        let quoted = try filter.validate(["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": #"{"radius": 4}"#])
        #expect(quoted.object("settings") == ["radius": 4], "settings sent as JSON text are taken as the object")
        do {
            _ = try filter.validate(["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": ["radius": 400]])
            Issue.record("an out-of-range setting passed")
        } catch let error as AutomationError {
            #expect(error.code == .invalidArguments && error.message.contains("settings.radius"))
        }
        #expect(throws: AutomationError.self) {
            try filter.validate(["document": "3f2a", "layer": "9c1b", "kind": "gaussian-blur", "settings": ["amount": 4]])
        }
    }

    @Test func schemasAreJSONSchema2020AndCatchMismatches() throws {
        for spec in CommandCatalog.commands {
            let input = spec.inputSchema
            #expect(input["type"] == "object" && input["$schema"] == "https://json-schema.org/draft/2020-12/schema")
            #expect(input["required"]?.arrayValue?.count == spec.parameters.filter(\.isRequired).count)
            #expect(spec.result.jsonSchema["type"] == "object")
        }
        let schema = Schema.object([.init("id", .string, ""), .init("size", .nullable(.integer), ""), .init("kind", .choice(["a", "b"]), "")])
        #expect(schema.violations(of: ["id": "x", "size": nil, "kind": "a", "extra": true]).isEmpty)
        #expect(schema.violations(of: ["id": 1, "size": 1.5, "kind": "c"]).count == 3)
        #expect(schema.violations(of: ["size": 2, "kind": "b"]) == ["$.id: missing"])
        let nullable = Schema.nullable(.string).jsonSchema
        #expect(nullable["type"] == ["string", "null"])
    }

    @Test func shortIDsAreTheShortestUniquePrefixes() throws {
        let a = try #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001"))
        let b = try #require(UUID(uuidString: "AAAAAAAA-B000-0000-0000-000000000002"))
        let c = try #require(UUID(uuidString: "12345678-0000-0000-0000-000000000003"))
        let prefixes = ShortID.prefixes([a, b, c])
        #expect(prefixes[c] == "12345678")
        #expect(prefixes[a] == "aaaaaaaa0" && prefixes[b] == "aaaaaaaab")
        let candidates = [(id: a, value: "a"), (id: b, value: "b"), (id: c, value: "c")]
        #expect(try ShortID.resolve("1234", among: candidates, noun: "layer") == "c")
        #expect(try ShortID.resolve(ShortID.normalize(b.uuidString), among: candidates, noun: "layer") == "b")
        #expect(throws: AutomationError(.ambiguous, "2 layers have ids starting with aaaa; give more of the id.")) {
            try ShortID.resolve("aaaa", among: candidates, noun: "layer")
        }
        #expect(throws: AutomationError.self) { try ShortID.resolve("ffff", among: candidates, noun: "layer") }
    }

    @Test func jsonIsCompactStableAndKeepsWholeNumbersWhole() throws {
        let value: JSONValue = ["b": 2, "a": [1.5, true, nil, "x"], "c": ["d": 3]]
        #expect(value.encodedString() == #"{"a":[1.5,true,null,"x"],"b":2,"c":{"d":3}}"#)
        #expect(try JSONValue.decode(value.encodedString()) == value)
        #expect(JSONValue.number(4).intValue == 4 && JSONValue.number(4.5).intValue == nil)
        #expect(value.encodedString(pretty: true) == """
        {
          "a": [
            1.5,
            true,
            null,
            "x"
          ],
          "b": 2,
          "c": {
            "d": 3
          }
        }
        """)
        #expect(JSONValue.object(["empty": [], "none": [:]]).encodedString(pretty: true) == "{\n  \"empty\": [],\n  \"none\": {}\n}")
    }

    @Test func repliesCarryAResultOrAnError() throws {
        let ok = AutomationMessage.reply(.success(["x": 1]))
        #expect(try AutomationMessage.outcome(of: ok).get() == ["x": 1])
        let failure = AutomationMessage.reply(.failure(AutomationError(.busy, "Text is being edited.")))
        #expect(throws: AutomationError(.busy, "Text is being edited.")) { try AutomationMessage.outcome(of: failure).get() }
        #expect(AutomationMessage.request(command: "undo", arguments: ["document": "3f2a"]) == ["v": 1, "command": "undo", "arguments": ["document": "3f2a"]])
    }
}
