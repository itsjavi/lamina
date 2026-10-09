import AppKit
import LaminaAutomation
import Testing
import LaminaCore
@testable import LaminaApp

/// The Layer Style dialog's model: its pages, checkboxes, live preview, one undo step for OK and an exact Cancel.
@MainActor
struct LayerStyleTests {
    private func styledSession() throws -> (session: EditorSession, layer: UUID) {
        let session = EditorSession()
        let ctx = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try #require(ctx.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Red"))
        return (session, try #require(session.activeLayerID))
    }

    private func layer(_ session: EditorSession, _ id: UUID) -> ImageLayer? {
        session.document?.layers.first { $0.id == id }
    }

    @Test func listsBlendingOptionsThenTheEffectsInPhotoshopsOrder() {
        #expect(LayerStylePage.all.map(\.title) == ["Blending Options", "Stroke", "Inner Shadow", "Inner Glow",
                                                    "Color Overlay", "Outer Glow", "Drop Shadow"])
        #expect(Set(LayerEffectKind.layerStyleOrder) == Set(LayerEffectKind.allCases), "every effect has a page")
        for page in LayerStylePage.all {
            #expect(ShortcutDefinition.assignableMenuCommands.contains("Layer › Layer Style › \(page.title)…"))
        }
    }

    @Test func anEffectsPageTurnsItOnAndTheCheckboxTurnsItOff() throws {
        let (session, id) = try styledSession()
        session.openLayerStyle(.effect(.stroke))
        #expect(session.layerStyle?.page == .effect(.stroke))
        #expect(!session.canEditLayers && !session.canUndo, "the dialog holds the document until it closes")
        // On the canvas at once, at today's defaults.
        #expect(layer(session, id)?.effects?.stroke == StrokeEffect(red: 1, green: 1, blue: 1), "a new stroke takes the background color")

        session.setLayerStyleEffect(.stroke, enabled: false)
        #expect(layer(session, id)?.effects?.isEnabled(.stroke) == false)
        session.setLayerStyleEffect(.shadow, enabled: true)
        #expect(session.layerStyle?.page == .effect(.stroke), "a checkbox doesn't change the page")
        #expect(layer(session, id)?.effects?.shadow == ShadowEffect())

        session.selectLayerStylePage(.blendingOptions)
        #expect(session.layerStyle?.page == .blendingOptions)
        session.finishLayerStyle(commit: true)
        // The stroke was only tried: it doesn't stay behind, hidden.
        #expect(layer(session, id)?.effects == LayerEffects(shadow: ShadowEffect()))
    }

    @Test func okAppliesEverythingAsOneUndoStep() throws {
        let (session, id) = try styledSession()
        let before = session.document
        let undoCount = session.history.undoCount
        session.openLayerStyle()
        session.changeLayerStyle { $0.blendMode = .multiply; $0.opacity = 0.4 }
        session.selectLayerStylePage(.effect(.shadow))
        session.changeLayerStyle { $0.effects.shadow?.blur = 6; $0.effects.shadow?.angle = 120 }
        session.selectLayerStylePage(.effect(.outerGlow))
        session.changeLayerStyle { $0.effects.outerGlow?.size = 4 }
        #expect(session.history.undoCount == undoCount, "nothing reaches the history while the dialog is open")
        #expect(layer(session, id)?.blendMode == .multiply, "the canvas previews every change")

        session.finishLayerStyle(commit: true)
        #expect(session.layerStyle == nil)
        #expect(session.history.undoCount == undoCount + 1)
        #expect(session.history.undoName == "Layer Style")
        let styled = try #require(layer(session, id))
        #expect(styled.blendMode == .multiply && styled.opacity == 0.4)
        #expect(styled.effects?.shadow?.blur == 6 && styled.effects?.shadow?.angle == 120)
        #expect(styled.effects?.outerGlow?.size == 4)

        session.undo()
        #expect(session.document == before)
    }

    @Test func okWithNoChangeAddsNoStep() throws {
        let (session, _) = try styledSession()
        let undoCount = session.history.undoCount
        session.openLayerStyle()
        session.finishLayerStyle(commit: true)
        #expect(session.history.undoCount == undoCount)
    }

    @Test func cancelRestoresTheLayerExactly() throws {
        let (session, id) = try styledSession()
        var effects = LayerEffects(shadow: ShadowEffect(enabled: false, distance: 7))
        effects.stroke = StrokeEffect(size: 3)
        session.setEffects(effects, on: id)
        session.setLayerOpacity(0.8)
        session.setLayerBlendMode(.screen)
        let before = session.document
        let undoCount = session.history.undoCount

        session.openLayerStyle(.effect(.shadow))
        session.changeLayerStyle { $0.effects.shadow?.distance = 40 }
        session.setLayerStyleEffect(.stroke, enabled: false)
        session.setLayerStyleEffect(.innerGlow, enabled: true)
        session.changeLayerStyle { $0.blendMode = .overlay; $0.opacity = 0.1 }
        #expect(session.document != before)

        session.finishLayerStyle(commit: false)
        #expect(session.document == before)
        #expect(layer(session, id)?.effects == effects)
        #expect(session.history.undoCount == undoCount)
        #expect(session.canEditLayers)
    }

    @Test func previewOffShowsTheLayerAsItWas() throws {
        let (session, id) = try styledSession()
        session.openLayerStyle(.effect(.colorOverlay))
        #expect(layer(session, id)?.effects?.colorOverlay != nil)
        session.setLayerStylePreview(false)
        #expect(layer(session, id)?.effects == nil)
        session.changeLayerStyle { $0.effects.colorOverlay?.opacity = 0.5 }
        #expect(layer(session, id)?.effects == nil, "changes wait for Preview")
        session.setLayerStylePreview(true)
        #expect(layer(session, id)?.effects?.colorOverlay?.opacity == 0.5)
        // OK applies the working style whatever Preview shows.
        session.setLayerStylePreview(false)
        session.finishLayerStyle(commit: true)
        #expect(layer(session, id)?.effects?.colorOverlay?.opacity == 0.5)
    }

    @Test func invalidSettingsAreRefused() throws {
        let (session, id) = try styledSession()
        session.openLayerStyle(.effect(.shadow))
        session.changeLayerStyle { $0.effects.shadow?.blur = 9000 }
        #expect(layer(session, id)?.effects?.shadow?.blur == ShadowEffect().blur)
        session.changeLayerStyle { $0.opacity = 7 }
        #expect(layer(session, id)?.opacity == 1)
        session.finishLayerStyle(commit: false)
    }

    @Test func doubleClickingAnEffectRowOpensItsPage() throws {
        let (session, id) = try styledSession()
        session.setEffects(LayerEffects(innerShadow: InnerShadowEffect()), on: id)
        session.selectEffect(.innerShadow, on: id)
        #expect(session.layerStyle == nil, "a single click only selects the row")
        session.selectEffect(.innerShadow, on: id, editing: true)
        #expect(session.layerStyle?.page == .effect(.innerShadow))
        session.finishLayerStyle(commit: false)
    }

    @Test func theColorPickerEditsTheWorkingStyle() throws {
        let (session, id) = try styledSession()
        session.openLayerStyle(.effect(.shadow))
        session.openEffectColorPicker(.shadow)
        session.colorPicker?.hsb = PickerHSB(PaletteColor(red: 1, green: 1, blue: 0))
        session.previewEffectColor()
        #expect(layer(session, id)?.effects?.shadow?.color == PaletteColor(red: 1, green: 1, blue: 0))
        session.closeColorPicker(commit: false)
        #expect(layer(session, id)?.effects?.shadow?.color == .black)
        session.openEffectColorPicker(.shadow)
        session.colorPicker?.hsb = PickerHSB(PaletteColor(red: 0, green: 1, blue: 0))
        // OK on the dialog keeps the picker's color.
        session.finishLayerStyle(commit: true)
        #expect(session.colorPicker == nil)
        #expect(layer(session, id)?.effects?.shadow?.color == PaletteColor(red: 0, green: 1, blue: 0))
    }

    @Test func groupsCantOpenIt() throws {
        let (session, _) = try styledSession()
        session.addGroup()
        #expect(!session.canOpenLayerStyle)
        session.openLayerStyle()
        #expect(session.layerStyle == nil)
    }

    @Test func laminaCommandsWaitForTheDialog() async throws {
        let workspace = ProjectWorkspace()
        let session = workspace.current.session
        session.createDocument(width: 20, height: 20)
        let context = try BrushRaster.context(width: 20, height: 20, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Half"))
        let dispatcher = AutomationDispatcher(workspace: workspace)
        session.openLayerStyle(.effect(.shadow))
        #expect(dispatcher.busyReason(workspace.current) == "The Layer Style dialog is open.")
        session.finishLayerStyle(commit: false)
        #expect(dispatcher.busyReason(workspace.current) == nil)
    }

    @Test func swatchDrawsTheStyleOnItsSample() throws {
        let plain = try #require(LayerStyleSwatch.image(for: LayerEffects()))
        let shadowed = try #require(LayerStyleSwatch.image(for: LayerEffects(shadow: ShadowEffect(distance: 400, blur: 400))))
        #expect(shadowed.width > plain.width, "the shadow reaches past the sample")
        #expect(shadowed.width <= plain.width + 2 * 2 * 14, "huge sizes are scaled to fit the swatch")
    }
}
