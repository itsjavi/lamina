import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The commands the menus gained with their familiar names (docs/DESIGN.md, Menus): View › Extras, Layer › Hide
/// Layers, the New items that ask for a name, and Layer › Layer Mask.
@MainActor
struct MenuCommandTests {
    private func makeSession() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 100, height: 100, emptyLayer: true)
        return session
    }

    /// Extras hides the grid, guides, pixel grid and selection edges together and keeps each one's own setting.
    @Test func extrasHidesEveryExtraAndRemembersEach() {
        let session = makeSession()
        session.showsGrid = true
        session.showsGuides = false
        session.showsPixelGrid = true
        session.applySelection(CGPath(rect: CGRect(x: 10, y: 10, width: 20, height: 20), transform: nil), mode: .replace, name: "Select")
        session.showsExtras = false
        #expect(!session.gridVisible && !session.guidesVisible && !session.pixelGridVisible && !session.selectionEdgesVisible)
        #expect(session.showsGrid && !session.showsGuides && session.showsPixelGrid, "each keeps its own setting")
        #expect(session.selection != nil, "the selection stays; only its edges hide")
        session.showsExtras = true
        #expect(session.gridVisible && !session.guidesVisible && session.pixelGridVisible && session.selectionEdgesVisible)
        // Turning one on while Extras is off shows Extras again; turning one off leaves it alone.
        session.showsExtras = false
        session.showsGrid = false
        #expect(!session.showsExtras)
        session.showsPixelGrid = false
        session.showsPixelGrid = true
        #expect(session.showsExtras)
    }

    @Test func hideLayersHidesAndShowsEverySelectedLayer() throws {
        let session = makeSession()
        let first = try #require(session.activeLayerID)
        session.addBlankLayer()
        let second = try #require(session.activeLayerID)
        session.selectLayers([first, second], primary: second)
        #expect(!session.selectedLayersHidden)
        session.toggleSelectedLayersVisibility()
        #expect(session.history.undoName == "Hide Layers")
        #expect(session.document?.layers.allSatisfy { !$0.isVisible } == true && session.selectedLayersHidden)
        session.toggleSelectedLayersVisibility()
        #expect(session.history.undoName == "Show Layers" && session.document?.layers.allSatisfy(\.isVisible) == true)
    }

    /// New › Layer…, Group…, Group from Layers… and Duplicate Layer… open the new layer's name, as their dialogs ask.
    @Test func newLayerCommandsOpenTheNameForEditing() throws {
        let session = makeSession()
        session.newLayerNamingIt()
        #expect(session.renamingLayerID == session.activeLayerID && session.document?.layers.count == 2)
        session.renamingLayerID = nil
        session.duplicateLayerNamingIt()
        #expect(session.renamingLayerID == session.activeLayerID && session.activeLayer?.name.hasSuffix("copy") == true)
        session.renamingLayerID = nil
        session.groupFromLayersNamingIt()
        #expect(session.activeLayer?.isGroup == true && session.renamingLayerID == session.activeLayerID)
        session.renamingLayerID = nil
        session.newGroupNamingIt()
        #expect(session.activeLayer?.isGroup == true && session.renamingLayerID == session.activeLayerID)
        // Nothing made, nothing to name: a rename already under way blocks the next one.
        let count = session.document?.layers.count
        session.newLayerNamingIt()
        #expect(session.document?.layers.count == count)
    }

    @Test func layerMaskItemsFollowTheMaskAndSelection() throws {
        let session = makeSession()
        #expect(session.canAddLayerMask && !session.canAddSelectionMask && !session.canDeleteLayerMask)
        session.applySelection(CGPath(rect: CGRect(x: 10, y: 10, width: 20, height: 20), transform: nil), mode: .replace, name: "Select")
        #expect(session.canAddSelectionMask)
        session.addMask(revealing: false)
        #expect(session.history.undoName == "Hide Selection" && session.canDeleteLayerMask && !session.canAddLayerMask)
        session.deleteLayerMask()
        #expect(session.activeLayer?.mask == nil)
    }
}
