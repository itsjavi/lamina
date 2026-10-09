import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The Properties panel (docs/DESIGN.md, Dock and panels ▸ Properties): what it shows for each selection, and that what
/// it changes goes through the same paths as the menus and bars, one undo step each, and is saved with the project.
@MainActor struct PropertiesTests {
    private func solid(width: Int, height: Int, gray: CGFloat = 0.5) throws -> ImportedImage {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        return ImportedImage(image: image, thumbnail: image, name: "Solid")
    }
    private func session(width: Int = 80, height: Int = 60) throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: width, height: height)
        session.insert(try solid(width: 20, height: 10))
        return session
    }
    private func textLayer(_ session: EditorSession, _ content: String = "Type") throws -> UUID {
        session.beginText(at: CGPoint(x: 10, y: 30))
        session.textDraft?.style.content = content
        #expect(session.applyText(try #require(session.textDraft)))
        return try #require(session.activeLayerID)
    }
    /// Saved to a package and opened again in a session of its own.
    private func reopened(_ session: EditorSession) async throws -> EditorSession {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Properties-\(UUID()).lam")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.shared.save(try #require(session.projectSnapshot()), to: url)
        let loaded = try await ProjectStore.shared.load(from: url)
        let reopened = EditorSession()
        reopened.installProject(loaded, from: url)
        return reopened
    }

    @Test func eachSelectionShowsItsOwnSettings() throws {
        let empty = EditorSession()
        #expect(empty.propertiesKind == .none)
        let session = try session()
        let pixel = try #require(session.activeLayerID)
        #expect(session.propertiesKind == .pixel && session.propertiesKind.title == "Pixel Layer")
        session.addLayerMask()
        #expect(session.isMaskSelected && session.propertiesKind == .mask)
        session.selectLayerTarget(pixel, mask: false)
        #expect(session.propertiesKind == .pixel)

        let text = try textLayer(session)
        #expect(session.propertiesKind == .type)

        session.selectTool(.rectangle)
        session.beginShape(at: CGPoint(x: 40, y: 30))
        session.dragShape(to: CGPoint(x: 60, y: 50), square: false, fromCenter: false)
        session.finishShape()
        #expect(session.propertiesKind == .shape)

        session.selectLayers([pixel, text], primary: text)
        #expect(session.propertiesKind == .layers(2) && session.propertiesKind.title == "2 Layers")
        session.groupSelectedLayers()
        let group = try #require(session.document?.layers.first(where: \.isGroup)?.id)
        session.selectLayer(group)
        #expect(session.propertiesKind == .group)

        session.addAdjustment(.curves)
        #expect(session.propertiesKind == .adjustment(.curves) && session.propertiesKind.title == "Curves")

        session.selectLayer(nil)
        #expect(session.propertiesKind == .document)
    }

    @Test func showingAdjustmentSettingsBringsPropertiesForward() throws {
        let session = try session()
        let before = session.propertiesRequest
        session.addAdjustment(.invert)
        #expect(session.propertiesRequest == before + 1, "a new adjustment layer shows its settings")
        session.showProperties()
        #expect(session.propertiesRequest == before + 2)
        let layout = DockLayout(defaults: UserDefaults(suiteName: "PropertiesTests-\(UUID())")!)
        layout.show(.adjustments)
        layout.show(.properties)
        #expect(layout.isVisible(.properties))
    }

    @Test func transformFieldsApplyOnceDoneAndSurviveReopening() async throws {
        let session = try session()
        let id = try #require(session.activeLayerID)
        let steps = session.history.undoCount
        session.locksTransformRatio = false
        // Typing a width previews it on the canvas; leaving the field applies it, one step.
        session.changeTransform(.width, to: 30)
        session.changeTransform(.width, to: 40)
        #expect(session.history.undoCount == steps)
        session.finishTransformValues()
        #expect(session.history.undoCount == steps + 1 && session.history.undoName == "Transform Layer")
        let resized = try #require(session.activeLayer?.transform)
        #expect(resized.size == CGSize(width: 40, height: 10))

        session.changeTransform(.x, to: 5)
        session.finishTransformValues()
        session.changeTransform(.y, to: 7)
        session.finishTransformValues()
        #expect(EditorSession.bounds(of: try #require(session.activeLayer?.transform)).origin == CGPoint(x: 5, y: 7))

        // Linked, the other side follows.
        session.locksTransformRatio = true
        session.changeTransform(.height, to: 20)
        session.finishTransformValues()
        #expect(session.activeLayer?.transform.size == CGSize(width: 80, height: 20))
        #expect(EditorSession.bounds(of: try #require(session.activeLayer?.transform)).origin == CGPoint(x: 5, y: 7),
                "the top left stays where it was")

        session.changeTransform(.angle, to: 30)
        session.finishTransformValues()
        session.changeInterpolation(.nearest)
        let placed = try #require(session.activeLayer?.transform)
        #expect(abs(placed.rotation - 30) < 0.001 && placed.sampling == .nearest)
        #expect(session.history.undoCount == steps + 6)

        session.undo()
        #expect(session.activeLayer?.transform.sampling != .nearest)
        session.redo()

        let reopened = try await reopened(session)
        let layer = try #require(reopened.document?.layers.first { $0.id == id })
        #expect(layer.transform.size == placed.size && abs(layer.transform.rotation - 30) < 0.001)
        #expect(layer.transform.sampling == .nearest)
        #expect(abs(layer.transform.origin.x - placed.origin.x) < 0.01 && abs(layer.transform.origin.y - placed.origin.y) < 0.01)
    }

    @Test func aFreeTransformTakesTheFieldsAsPartOfItself() throws {
        let session = try session()
        let steps = session.history.undoCount
        session.beginTransform()
        session.changeTransform(.width, to: 40)
        session.finishTransformValues()
        #expect(session.transformEdit != nil && session.history.undoCount == steps, "waits for Commit")
        session.commitTransform()
        #expect(session.history.undoCount == steps + 1)
    }

    @Test func characterEditsRedrawTheLayerOneStepEachAndSurviveReopening() async throws {
        let session = try session()
        let id = try textLayer(session)
        let steps = session.history.undoCount
        // A field being typed in keeps one step open until it is done.
        session.changeTextLayerStyle(held: true) { $0.fontSize = 4 }
        session.changeTextLayerStyle(held: true) { $0.fontSize = 48 }
        #expect(session.textDraft == nil, "the layer changes at once; no text editor opens")
        session.finishPropertyChange()
        #expect(session.history.undoCount == steps + 1 && session.history.undoName == "Edit Text")
        session.changeTextLayerStyle { $0.leading = 60 }
        session.changeTextLayerStyle { $0.tracking = 25 }
        session.changeTextLayerStyle { $0.alignment = .center }
        let current = FontFaces.family(of: session.currentTextStyle.fontName)
        let family = try #require(["Times New Roman", "Courier", "Menlo"].first {
            $0 != current && NSFontManager.shared.availableFontFamilies.contains($0)
        })
        let face = try #require(FontFaces.face(in: family, like: session.currentTextStyle.fontName))
        #expect(FontFaces.family(of: face) == family)
        session.changeTextLayerStyle { $0.setFont(face, in: NSRange(location: 0, length: 0)) }
        #expect(session.history.undoCount == steps + 5)
        let style = try #require(session.activeLayer?.liveText?.style)
        #expect(style.fontSize == 48 && style.leading == 60 && style.tracking == 25 && style.alignment == .center && style.fontName == face)
        session.undo()
        #expect(session.activeLayer?.liveText?.style.fontName != face)
        session.redo()

        let reopened = try await reopened(session)
        let saved = try #require(reopened.document?.layers.first { $0.id == id }?.liveText?.style)
        #expect(saved.fontSize == 48 && saved.leading == 60 && saved.tracking == 25 && saved.alignment == .center && saved.fontName == face)
    }

    @Test func characterEditsJoinTheTextBeingEdited() throws {
        let session = try session()
        _ = try textLayer(session)
        session.editActiveText()
        let steps = session.history.undoCount
        session.changeTextLayerStyle { $0.tracking = 40 }
        #expect(session.textDraft?.style.tracking == 40 && session.history.undoCount == steps, "applied with the text")
        #expect(session.finishText())
        #expect(session.activeLayer?.liveText?.style.tracking == 40 && session.history.undoCount == steps + 1)
    }

    @Test func textColorFromPropertiesIsOneStepAndCancelLeavesNone() throws {
        let session = try session()
        _ = try textLayer(session)
        let steps = session.history.undoCount
        session.openTextLayerColorPicker()
        let picker = try #require(session.colorPicker)
        picker.hsb = PickerHSB(PaletteColor(red: 1, green: 0, blue: 0))
        session.previewDialogColor()
        picker.hsb = PickerHSB(PaletteColor(red: 0, green: 0, blue: 1))
        session.previewDialogColor()
        session.closeColorPicker(commit: true)
        #expect(session.history.undoCount == steps + 1 && session.history.undoName == "Text Color")
        #expect(session.activeLayer?.liveText?.style.color(at: 0) == PaletteColor(red: 0, green: 0, blue: 1))

        session.openTextLayerColorPicker()
        session.colorPicker?.hsb = PickerHSB(PaletteColor(red: 0, green: 1, blue: 0))
        session.previewDialogColor()
        session.closeColorPicker(commit: false)
        #expect(session.history.undoCount == steps + 1, "Cancel puts the color back, with no step")
        #expect(session.activeLayer?.liveText?.style.color(at: 0) == PaletteColor(red: 0, green: 0, blue: 1))
    }

    @Test func aDragInPropertiesIsOneUndoStep() async throws {
        let session = try session()
        session.addAdjustment(.exposure)
        let id = try #require(session.activeLayerID)
        let steps = session.history.undoCount
        var held = true
        session.isPointerHeld = { held }
        for value in stride(from: 0.1, through: 1, by: 0.1) {
            session.changeAdjustment(id) { $0.exposure.exposure = value }
        }
        #expect(session.activeLayer?.adjustment?.exposure.exposure == 1, "the canvas follows the drag")
        #expect(!session.canUndo, "the step is open until the button comes up")
        held = false
        await session.propertyRelease?.value
        #expect(session.history.undoCount == steps + 1 && session.history.undoName == "Edit Exposure Adjustment")
        session.undo()
        #expect(session.activeLayer?.adjustment?.exposure.exposure == 0)
    }

    @Test func adjustmentEditsSurviveReopening() async throws {
        let session = try session()
        session.addAdjustment(.blackWhite)
        let blackWhite = try #require(session.activeLayerID)
        session.changeAdjustment(blackWhite) { var settings = $0.filterSettings; settings.blackWhite.reds = 80; $0.take(settings) }
        // The footer: clipped to the pixel layer below, hidden.
        #expect(session.canToggleClippingMask(blackWhite))
        session.toggleClippingMask(blackWhite)
        session.toggleLayerVisibility(blackWhite)
        session.addAdjustment(.levels)
        let levels = try #require(session.activeLayerID)
        session.changeAdjustment(levels) { $0.levels.ranges[0].outputWhite = 200 }
        session.addAdjustment(.hsv)
        let hsv = try #require(session.activeLayerID)
        session.changeAdjustment(hsv) { var value = $0.resolvedHSV; value.hue = 45; $0.hsvSettings = value }

        let reopened = try await reopened(session)
        let layers = try #require(reopened.document?.layers)
        #expect(layers.first { $0.id == levels }?.adjustment?.levels.ranges[0].outputWhite == 200)
        #expect(layers.first { $0.id == hsv }?.adjustment?.resolvedHSV.hue == 45)
        let saved = try #require(layers.first { $0.id == blackWhite })
        #expect(saved.adjustment?.blackWhite.reds == 80 && saved.maskSourceID != nil && !saved.isVisible)
    }

    @Test func levelsCountsTheLayersBelow() async throws {
        let session = EditorSession()
        session.createDocument(width: 4, height: 4)
        session.insert(try solid(width: 4, height: 4, gray: 1))
        session.addAdjustment(.levels)
        let id = try #require(session.activeLayerID)
        // Above the adjustment, left out of what it counts.
        session.insert(try solid(width: 4, height: 4, gray: 0))
        let histogram = try #require(await session.adjustmentInputHistogram(id))
        #expect(histogram[1][255] == 16 && histogram[1][0] == 0, "the white layer below, not the black one above")
        // Auto, from that histogram, as the dialog's.
        let auto = LevelsAuto.contrast.settings(histogram: histogram)
        session.selectLayer(id)
        session.changeAdjustment(id) { $0.levels = auto }
        #expect(session.activeLayer?.adjustment?.levels == auto)
    }

    @Test func maskColorRangeReplacesTheMaskAndLeavesTheSelection() async throws {
        let session = EditorSession()
        session.createDocument(width: 20, height: 10)
        // Left half black, right half white.
        let context = try BrushRaster.context(width: 20, height: 10, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 10, y: 0, width: 10, height: 10))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Halves"))
        session.addLayerMask()
        #expect(session.propertiesKind == .mask)
        let steps = session.history.undoCount
        session.beginColorRange(forMask: true)
        let edit = try #require(session.colorRange)
        edit.fuzziness = 10
        session.sampleColorRange(at: CGPoint(x: 15, y: 5), shift: false, option: false)
        for _ in 0..<200 where session.document?.selection == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(session.document?.selection != nil, "the panel previews the match as a selection")
        session.commitColorRange()
        #expect(session.document?.selection == nil, "the selection is put back as it was")
        #expect(session.history.undoCount == steps + 1 && session.history.undoName == "Mask Color Range")
        let mask = try #require(session.activeLayer?.mask?.asset.image)
        #expect(mask.width == 20 && mask.height == 10)
        let gray = try BrushRaster.context(width: 20, height: 10, mask: true)
        gray.draw(mask, in: CGRect(x: 0, y: 0, width: 20, height: 10))
        let bytes = try #require(gray.data).assumingMemoryBound(to: UInt8.self)
        // Rows run top to bottom in memory; column 2 is black, column 17 white.
        #expect(bytes[5 * gray.bytesPerRow + 2] < 30 && bytes[5 * gray.bytesPerRow + 17] > 225)

        let reopened = try await reopened(session)
        #expect(reopened.document?.layers.first?.mask?.asset.image.width == 20)
    }

    @Test func canvasFieldsUseCanvasSizeAndImageSizePaths() async throws {
        let session = try session(width: 80, height: 60)
        let projects = ProjectController(session: session)
        let steps = session.history.undoCount
        await projects.resizeCanvas(width: 100, height: 60)
        #expect(session.document?.width == 100 && session.history.undoName == "Canvas Size")
        await projects.changeResolution(300)
        #expect(session.document?.resolution == 300 && session.document?.width == 100, "no resampling")
        #expect(session.history.undoCount == steps + 2 && session.history.undoName == "Image Size")
        let reopened = try await reopened(session)
        #expect(reopened.document?.width == 100 && reopened.document?.height == 60 && reopened.document?.resolution == 300)
    }

    @Test func rulerUnitsConvertTheCanvasSize() {
        #expect(SizeUnit.inches.value(ofPixels: 300, resolution: 300) == 1)
        #expect(SizeUnit.millimeters.pixels(25.4, resolution: 72) == 72)
        #expect(!SizeUnit.rulerUnits.contains(.percent))
    }
}
