import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Photoshop's layer locks (docs/DESIGN.md, Layers): Lock image pixels, Lock position and Lock all refuse what they
/// lock through the predicates the menus, tools and `lamina` share; Lock transparent pixels is in progress.
@MainActor
struct LayerLockTests {
    /// A 100 × 100 document with a 40 × 40 red layer, "Square", selected.
    private func sessionWithSquare() throws -> EditorSession {
        let session = EditorSession()
        session.announceInProgress = { _ in }
        session.createDocument(width: 100, height: 100)
        let context = try BrushRaster.context(width: 40, height: 40, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Square"))
        return session
    }

    @Test func aLockButtonTogglesForTheSelectionAsOneUndoStep() throws {
        let session = try sessionWithSquare()
        #expect(session.canChangeLocks && !session.isLocked(.position))
        session.toggleLock(.position)
        #expect(session.isLocked(.position) && session.activeLayer?.locks == LayerLocks(position: true))
        #expect(session.history.undoName == "Lock Layers")
        session.toggleLock(.position)
        #expect(session.activeLayer?.locks.isEmpty == true)
        session.undo()
        #expect(session.activeLayer?.locks == LayerLocks(position: true))
        #expect(session.lastLock == .position, "/ now toggles the lock last chosen")
        session.toggleLastLock()
        #expect(session.activeLayer?.locks.isEmpty == true)
    }

    @Test func lockTransparentPixelsOnlySaysItIsInProgress() throws {
        let session = try sessionWithSquare()
        #expect(session.lastLock == .transparentPixels, "/ starts on Lock transparent pixels, as in Photoshop")
        let before = session.document
        session.toggleLastLock()
        #expect(session.inProgressNotice?.feature == .lockTransparentPixels && session.document == before)
        #expect(!session.isLocked(.transparentPixels))
    }

    @Test func lockImagePixelsRefusesPixelEditsButNotMovesOrTheMask() throws {
        let session = try sessionWithSquare()
        session.toggleLock(.imagePixels)
        #expect(!session.canPaint && !session.canEditPixels && !session.canFill && !session.canAdjustColors && !session.canInvert)
        #expect(session.paintRefusal?.contains("locked") == true)
        #expect(session.canTransform && session.canAlignLayers, "the layer can still move")
        #expect(!session.canDistort, "distorting would resample the locked pixels")
        session.addLayerMask()
        #expect(session.isMaskSelected && session.canPaint, "its mask stays editable")
    }

    @Test func lockPositionRefusesMovesButNotPainting() throws {
        let session = try sessionWithSquare()
        session.toggleLock(.position)
        #expect(!session.canTransform && !session.canAlignLayers && session.alignmentItems.isEmpty)
        let origin = session.activeLayer?.origin
        session.nudgeLayer(dx: 5, dy: 0)
        #expect(session.activeLayer?.origin == origin)
        #expect(session.canPaint && session.canAdjustColors)
    }

    @Test func lockAllRefusesAppearanceTheMaskAndText() throws {
        let session = try sessionWithSquare()
        session.addLayerMask()
        session.selectLayerTarget(try #require(session.activeLayerID), mask: false)
        session.toggleLock(.all)
        #expect(!session.canPaint && !session.canTransform && !session.canEditOpacity && !session.canEditAppearance)
        #expect(!session.canEditEffects && !session.canEditMask)
        let opacity = session.activeLayer?.opacity
        session.setLayerOpacity(0.25)
        #expect(session.activeLayer?.opacity == opacity)
        session.selectLayerTarget(try #require(session.activeLayerID), mask: true)
        #expect(!session.canPaint, "Lock all keeps the mask too")
    }

    @Test func aGroupsLocksHoldForItsContents() throws {
        let session = try sessionWithSquare()
        let square = try #require(session.activeLayerID)
        session.groupSelectedLayers()
        let group = try #require(session.activeLayerID)
        #expect(group != square)
        session.toggleLock(.position)
        session.selectLayer(square)
        #expect(session.activeLocks.position && session.activeLayer?.locks.isEmpty == true)
        #expect(!session.canTransform)
        session.selectLayer(group)
        session.toggleLock(.position)
        session.selectLayer(square)
        session.toggleLock(.imagePixels)
        session.selectLayer(group)
        #expect(session.selectionPixelsLocked, "a selected group counts what it holds")
    }

    @Test func theLockDialogSetsEverySelectedLayer() throws {
        let session = try sessionWithSquare()
        session.beginLockLayers()
        #expect(session.commandDialog == .lockLayers && session.commonLocks.isEmpty)
        session.finishLockLayers(LayerLocks(imagePixels: true, position: true))
        #expect(session.commandDialog == nil && session.activeLayer?.locks == LayerLocks(imagePixels: true, position: true))
        session.beginLockLayers()
        session.finishLockLayers(nil)
        #expect(session.activeLayer?.locks == LayerLocks(imagePixels: true, position: true), "Cancel changes nothing")
    }

    @Test func locksAreSavedAndSurvivePixelEdits() async throws {
        let session = try sessionWithSquare()
        session.toggleLock(.position)
        session.applySelection(CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil), mode: .replace, name: "Select")
        await session.fill(PaletteColor(red: 0, green: 1, blue: 0), opacity: 1)
        #expect(session.activeLayer?.locks == LayerLocks(position: true), "painting rebuilds the layer and keeps its locks")
        session.addBlankLayer()
        let snapshot = try #require(session.projectSnapshot())
        #expect(snapshot.manifest.layers.map(\.locks) == [LayerLocks(position: true), nil], "unlocked layers write no locks")
        #expect(snapshot.documentLayers.map(\.locks) == [LayerLocks(position: true), LayerLocks()])
    }
}
