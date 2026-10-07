import AppKit
import ImageIO
import LaminaAutomation
import Testing
@testable import Compositor

/// `lamina`'s commands, run through the dispatcher with JSON as the Apple Event handler runs them, without the
/// transport. Every result is checked against the catalog's schema for its command.
@MainActor
struct AutomationTests {
    /// A workspace whose one document is 40×20 with an opaque white left half on a layer named "Half".
    func fixture() throws -> (workspace: ProjectWorkspace, dispatcher: AutomationDispatcher, session: EditorSession) {
        let workspace = ProjectWorkspace()
        let session = workspace.current.session
        session.createDocument(width: 40, height: 20)
        let context = try BrushRaster.context(width: 40, height: 20, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Half"))
        return (workspace, AutomationDispatcher(workspace: workspace), session)
    }

    /// Runs a command, checking its result against the catalog.
    func run(_ dispatcher: AutomationDispatcher, _ command: String, _ arguments: [String: JSONValue] = [:]) async throws -> JSONValue {
        let result = try await dispatcher.run(command, arguments)
        let spec = try #require(CommandCatalog.command(command))
        #expect(spec.result.violations(of: result).isEmpty, "\(command): \(spec.result.violations(of: result))")
        return result
    }

    func expectError(_ code: AutomationError.Code, _ body: () async throws -> JSONValue) async {
        do {
            _ = try await body()
            Issue.record("expected \(code.rawValue)")
        } catch let error as AutomationError {
            #expect(error.code == code, "\(error.message)")
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    func ids(_ f: (workspace: ProjectWorkspace, dispatcher: AutomationDispatcher, session: EditorSession)) throws -> (document: String, layer: String) {
        let layer = try #require(f.session.activeLayerID)
        return (ShortID.hex(f.workspace.current.id), ShortID.hex(layer))
    }

    @Test func onlyThisUsersProcessesOnThisMacAreHeard() {
        let me = Int32(bitPattern: geteuid())
        #expect(AutomationServer.refusal(source: Int32(kAELocalProcess), senderUserID: me) == nil)
        #expect(AutomationServer.refusal(source: Int32(kAESameProcess), senderUserID: nil) == nil)
        #expect(AutomationServer.refusal(source: Int32(kAERemoteProcess), senderUserID: me)?.code == .transport)
        #expect(AutomationServer.refusal(source: Int32(kAELocalProcess), senderUserID: me &+ 1)?.code == .transport)
        // A local event as the Apple Event Manager makes it passes.
        let event = NSAppleEventDescriptor(eventClass: AutomationEvent.eventClass, eventID: AutomationEvent.eventID,
                                           targetDescriptor: .currentProcess(), returnID: AEReturnID(kAutoGenerateReturnID),
                                           transactionID: AETransactionID(kAnyTransactionID))
        #expect(AutomationServer.refusal(of: event) == nil)
    }

    @Test func everyCatalogCommandHasAHandler() {
        #expect(Set(AutomationDispatcher.handlers.keys) == Set(CommandCatalog.commands.map(\.name)))
    }

    @Test func requestsAndRepliesTravelAsJSON() async throws {
        let f = try fixture()
        let reply = try JSONValue.decode(await f.dispatcher.handle(Data(#"{"v":1,"command":"list-documents","arguments":{}}"#.utf8)))
        #expect(reply["ok"] == true)
        #expect(reply["result"]?["documents"]?.arrayValue?.count == 1)
        for (request, code) in [
            (#"{"v":1,"command":"paint-it-black"}"#, "unknown_command"),
            (#"not json"#, "invalid_arguments"),
            (#"{"v":99,"command":"list-documents"}"#, "unsupported_version"),
            (#"{"v":1,"command":"undo","arguments":{}}"#, "invalid_arguments"),
        ] {
            let failure = try JSONValue.decode(await f.dispatcher.handle(Data(request.utf8)))
            #expect(failure["ok"] == false && failure["error"]?["code"]?.stringValue == code, "\(request)")
        }
    }

    @Test func listsDocumentsAndTheirLayersTopToBottomWithShortIDs() async throws {
        let f = try fixture()
        f.session.addBlankLayer()
        let result = try await run(f.dispatcher, "list-documents")
        let document = try #require(result["documents"]?.arrayValue?.first)
        #expect(document["id"]?.stringValue == String(ShortID.hex(f.workspace.current.id).prefix(8)))
        #expect(document["width"] == 40 && document["height"] == 20 && document["front"] == true && document["modified"] == true)
        let layers = try #require(document["layers"]?.arrayValue)
        #expect(layers.map { $0["type"]?.stringValue } == ["empty", "pixels"])
        #expect(layers.last?["name"] == "Half")
        #expect(layers.allSatisfy { $0["id"]?.stringValue?.count == 8 })
        #expect(document["active_layer"] == layers.first?["id"])
        let bare = try await run(f.dispatcher, "list-documents", ["layers": false])
        #expect(bare["documents"]?.arrayValue?.first?["layers"] == nil)
    }

    @Test func describesADocumentInDetail() async throws {
        let f = try fixture()
        let (document, _) = try ids(f)
        let result = try await run(f.dispatcher, "describe-document", ["document": .string(document)])
        #expect(result["resolution"] == 72 && result["busy"] == .null && result["selection"] == .null)
        #expect(result["undo"]?.stringValue?.isEmpty == false, "inserting the layer made an undo step")
        let layer = try #require(result["layers"]?.arrayValue?.first)
        #expect(layer["bounds"] == ["x": 0, "y": 0, "width": 40, "height": 20])
        #expect(layer["opacity"] == 1 && layer["blend_mode"] == "Normal" && layer["mask"] == .null)
    }

    @Test func selectsALayerWithoutAnUndoStep() async throws {
        let f = try fixture()
        let (document, half) = try ids(f)
        f.session.addBlankLayer()
        let count = f.session.history.undoCount
        let result = try await run(f.dispatcher, "select-layer", ["document": .string(document), "layer": .string(String(half.prefix(6)))])
        #expect(f.session.activeLayerID.map(ShortID.hex) == half)
        #expect(result["active_layer"]?.stringValue == String(half.prefix(8)) && result["mask_selected"] == false)
        #expect(f.session.history.undoCount == count)
        await expectError(.unavailable) { try await run(f.dispatcher, "select-layer", ["document": .string(document), "layer": .string(half), "mask": true]) }
    }

    @Test func appliesAFilterThroughTheFilterDialogAsOneUndoStep() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        let before = f.session.activeLayer?.asset?.image
        let count = f.session.history.undoCount
        let result = try await run(f.dispatcher, "apply-filter", [
            "document": .string(document), "layer": .string(layer), "kind": "gaussian-blur", "settings": ["radius": 3],
        ])
        #expect(f.session.history.undoCount == count + 1 && f.session.history.undoName == "Gaussian Blur")
        #expect(f.session.filterEdit == nil && f.session.filterSettings.radius == 3)
        #expect(f.session.activeLayer?.asset?.image !== before)
        #expect((f.session.activeLayer?.asset?.image.height ?? 0) > 20, "the blur grew the layer, as the menu's does")
        #expect(result["changed"] == true && result["undo"] == "Gaussian Blur")
        #expect(result["modified"] == [.string(String(layer.prefix(8)))] && result["layer"]?.stringValue == String(layer.prefix(8)))
        #expect(result["revision"]?.stringValue == String(ShortID.hex(f.session.history.currentRevision).prefix(8)))

        // Settings that change nothing make no undo step, as OK in the dialog would.
        let none = try await run(f.dispatcher, "apply-filter", [
            "document": .string(document), "layer": .string(layer), "kind": "lens-correction",
        ])
        #expect(none["changed"] == false && f.session.history.undoCount == count + 1)
    }

    @Test func refusesFiltersThatCantApply() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        f.session.addBlankLayer()
        let empty = try #require(f.session.activeLayerID.map(ShortID.hex))
        await expectError(.unavailable) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(empty), "kind": "gaussian-blur"])
        }
        f.session.toggleLayerVisibility(try #require(f.session.document?.layers.first?.id))
        await expectError(.unavailable) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(layer), "kind": "grain"])
        }
        await expectError(.invalidArguments) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(layer), "kind": "grain",
                                                         "settings": ["amount": 500]])
        }
        await expectError(.notFound) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": "ffffffff", "kind": "grain"])
        }
        await expectError(.notFound) {
            try await run(f.dispatcher, "apply-filter", ["document": "ffffffff", "layer": .string(layer), "kind": "grain"])
        }
    }

    @Test func addsAnAdjustmentLayerWithItsSettingsAsOneUndoStep() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        let count = f.session.history.undoCount
        let result = try await run(f.dispatcher, "add-adjustment-layer", [
            "document": .string(document), "kind": "exposure", "settings": ["exposure": 0.5, "gamma": 1.2],
        ])
        let added = try #require(f.session.activeLayer)
        #expect(added.adjustment?.kind == .exposure && added.adjustment?.exposure.exposure == 0.5 && added.adjustment?.exposure.gamma == 1.2)
        #expect(f.session.adjustmentEditingID == nil, "no settings panel left open")
        #expect(f.session.history.undoCount == count + 1 && f.session.history.undoName == "New Exposure Adjustment")
        #expect(result["added"] == [.string(String(ShortID.hex(added.id).prefix(8)))] && result["layer"] == result["added"]?.arrayValue?.first)
        #expect(f.session.document?.layers.last?.id == added.id)

        // Above a named layer, and listed by kind.
        _ = try await run(f.dispatcher, "add-adjustment-layer", ["document": .string(document), "kind": "invert", "above": .string(layer)])
        #expect(f.session.document?.layers.map { $0.adjustment?.kind } == [nil, .invert, .exposure])
        let listed = try await run(f.dispatcher, "list-documents")
        #expect(listed["documents"]?.arrayValue?.first?["layers"]?.arrayValue?.compactMap { $0["adjustment"]?.stringValue } == ["exposure", "invert"])

        f.session.undo()
        f.session.undo()
        #expect(f.session.history.undoCount == count)
    }

    @Test func undoesAndRedoes() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        let original = f.session.document
        _ = try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(layer), "kind": "grain"])
        let filtered = f.session.document
        let undone = try await run(f.dispatcher, "undo", ["document": .string(document)])
        #expect(f.session.document == original && undone["changed"] == true && undone["modified"]?.arrayValue?.count == 1)
        _ = try await run(f.dispatcher, "redo", ["document": .string(document)])
        #expect(f.session.document == filtered)
        await expectError(.unavailable) { try await run(f.dispatcher, "redo", ["document": .string(document)]) }
    }

    @Test func refusesEditsWhileThePersonIsMidEditButStillAnswersQuestions() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        f.session.beginFilter(.motionBlur)
        #expect(f.session.filterEdit != nil)
        await expectError(.busy) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(layer), "kind": "grain"])
        }
        await expectError(.busy) { try await run(f.dispatcher, "select-layer", ["document": .string(document), "layer": .string(layer)]) }
        let described = try await run(f.dispatcher, "describe-document", ["document": .string(document)])
        #expect(described["busy"] == "The Motion Blur dialog is open.")
        _ = try await run(f.dispatcher, "render-preview", ["document": .string(document)])
        f.session.cancelFilter()

        f.session.beginTransform()
        #expect(f.session.transformEdit != nil)
        await expectError(.busy) { try await run(f.dispatcher, "undo", ["document": .string(document)]) }
        f.session.cancelTransform()
        _ = try await run(f.dispatcher, "undo", ["document": .string(document)])
    }

    @Test func expectRevisionRefusesAfterAChange() async throws {
        let f = try fixture()
        let (document, layer) = try ids(f)
        let revision = try #require(try await run(f.dispatcher, "describe-document", ["document": .string(document)])["revision"])
        f.session.addBlankLayer()
        await expectError(.conflict) {
            try await run(f.dispatcher, "apply-filter", ["document": .string(document), "layer": .string(layer), "kind": "grain",
                                                         "expect_revision": revision])
        }
        let current = try #require(try await run(f.dispatcher, "describe-document", ["document": .string(document)])["revision"])
        _ = try await run(f.dispatcher, "undo", ["document": .string(document), "expect_revision": current])
        #expect(try await run(f.dispatcher, "describe-document", ["document": .string(document)])["revision"] == revision,
                "undo goes back to the revision before")
    }

    @Test func idPrefixesThatMatchSeveralLayersAreAmbiguous() async throws {
        let f = try fixture()
        let (document, _) = try ids(f)
        let image = try #require(f.session.activeLayer?.asset)
        for suffix in ["1", "2"] {
            let id = try #require(UUID(uuidString: "ABCDEF0\(suffix)-0000-0000-0000-000000000000"))
            f.session.document?.layers.append(ImageLayer(id: id, asset: image, name: suffix, isVisible: true,
                                                         transform: LayerTransform(origin: .zero, size: CGSize(width: 40, height: 20))))
        }
        await expectError(.ambiguous) { try await run(f.dispatcher, "select-layer", ["document": .string(document), "layer": "abcdef0"]) }
        _ = try await run(f.dispatcher, "select-layer", ["document": .string(document), "layer": "abcdef02"])
        #expect(f.session.activeLayer?.name == "2")
        let listed = try await run(f.dispatcher, "list-documents")
        #expect(listed["documents"]?.arrayValue?.first?["layers"]?.arrayValue?.prefix(2).compactMap { $0["id"]?.stringValue } == ["abcdef02", "abcdef01"])
    }

    @Test func exportsPNGAndJPEGBytesForLaminaToWrite() async throws {
        let f = try fixture()
        let (document, _) = try ids(f)
        let png = try await run(f.dispatcher, "export-document", ["document": .string(document), "format": "png"])
        let pngData = try #require(png["data"]?.stringValue.flatMap { Data(base64Encoded: $0) })
        let source = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 40 && image.height == 20 && png["bytes"]?.intValue == pngData.count)
        let jpeg = try await run(f.dispatcher, "export-document", ["document": .string(document), "format": "jpeg", "quality": 0.5])
        let jpegData = try #require(jpeg["data"]?.stringValue.flatMap { Data(base64Encoded: $0) })
        #expect(jpegData.prefix(2) == Data([0xFF, 0xD8]) && jpeg["format"] == "jpeg")
    }

    @Test func rendersAPreviewNoLargerThanAsked() async throws {
        let f = try fixture()
        let (document, _) = try ids(f)
        let small = try await run(f.dispatcher, "render-preview", ["document": .string(document), "max_size": 16])
        #expect(small["width"] == 16 && small["height"] == 8 && small["source_width"] == 40)
        let full = try await run(f.dispatcher, "render-preview", ["document": .string(document)])
        #expect(full["width"] == 40 && full["height"] == 20, "never scaled up")
    }

    // MARK: The catalog's filters and adjustments are the app's

    @Test func everyKindIsOneOfTheAppsFiltersOrAdjustments() {
        for kind in EffectCatalog.filters { #expect(FilterKind(rawValue: kind.title) != nil, "\(kind.title)") }
        for kind in EffectCatalog.adjustments { #expect(AdjustmentKind(rawValue: kind.title) != nil, "\(kind.title)") }
    }

    /// Values for every setting that differ from its default.
    func changed(_ setting: ParameterSpec) -> JSONValue {
        switch setting.type {
        case .number(let range): setting.defaultValue?.doubleValue == range.lowerBound ? .number(range.upperBound) : .number(range.lowerBound)
        case .boolean: .bool(!(setting.defaultValue?.boolValue ?? false))
        case .choice(let values): .string(values.first { .string($0) != setting.defaultValue } ?? values[0])
        default: "#123456"
        }
    }

    func defaults(_ kind: EffectKind) -> Arguments {
        Arguments(Dictionary(uniqueKeysWithValues: kind.settings.compactMap { setting in setting.defaultValue.map { (setting.name, $0) } }))
    }

    @Test func filterDefaultsAreTheAppsAndEverySettingTakesEffect() throws {
        for spec in EffectCatalog.filters {
            let kind = try #require(FilterKind(rawValue: spec.title))
            let base = FilterSettings()
            #expect(AutomationEffects.filterSettings(kind, base: base, defaults(spec)) == base, "\(spec.name)'s documented defaults")
            for setting in spec.settings {
                let value = try spec.validate([setting.name: changed(setting)])
                #expect(AutomationEffects.filterSettings(kind, base: base, value) != base, "\(spec.name).\(setting.name) takes effect")
            }
        }
    }

    @Test func adjustmentDefaultsAreTheAppsAndEverySettingTakesEffect() throws {
        for spec in EffectCatalog.adjustments {
            let kind = try #require(AdjustmentKind(rawValue: spec.title))
            let base = LayerAdjustment(kind: kind)
            let withDefaults = AutomationEffects.adjustment(base, defaults(spec))
            #expect(withDefaults.resolvedHSV == base.resolvedHSV && withDefaults.exposure == base.exposure && withDefaults.grain == base.grain
                && withDefaults.blackWhite == base.blackWhite && withDefaults.colorBalance == base.colorBalance
                && withDefaults.gradientMap == base.gradientMap && withDefaults.gaussianRadius == base.gaussianRadius
                && withDefaults.resolvedMotionAngle == base.resolvedMotionAngle && withDefaults.resolvedMotionDistance == base.resolvedMotionDistance
                && withDefaults.resolvedNoiseAmount == base.resolvedNoiseAmount, "\(spec.name)'s documented defaults")
            for setting in spec.settings {
                let value = try spec.validate([setting.name: changed(setting)])
                let adjusted = AutomationEffects.adjustment(base, value)
                #expect(adjusted != base && adjusted.isValid, "\(spec.name).\(setting.name) takes effect")
            }
        }
    }
}
