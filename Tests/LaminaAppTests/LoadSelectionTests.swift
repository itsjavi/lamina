import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Select › Load Selection… (docs/DESIGN.md, Menus and Dialogs): a layer's transparency or a mask, inverted or not,
/// as a new selection or added to or taken from it. It replaces Select › Layer's Pixels and Mask's Black Areas.
@MainActor
struct LoadSelectionTests {
    private func makeSession(side: Int = 100) -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: side, height: side, emptyLayer: true)
        return session
    }
    private func lasso(_ session: EditorSession, _ rect: CGRect) {
        session.applySelection(CGPath(rect: rect, transform: nil), mode: .replace, name: "Select")
    }
    /// Coverage 0–255 at a document pixel.
    private func coverage(_ session: EditorSession, _ x: Int, _ y: Int) throws -> Int {
        let document = try #require(session.document)
        let image = try #require(session.selection).coverage(width: document.width, height: document.height)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Int(bytes[y * image.width + x])
    }
    /// The empty layer with a mask: white, with a black square (hidden) holding a white square hole.
    private func maskedLayer(_ session: EditorSession) throws -> UUID {
        let id = try #require(session.activeLayerID)
        let context = try BrushRaster.context(width: 100, height: 100, mask: true)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 20, y: 30, width: 40, height: 40))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 30, y: 40, width: 10, height: 10))
        let asset = try LayerMask.asset(from: try #require(context.makeImage()))
        session.addLayerMask(revealing: true)
        let index = try #require(session.document?.layers.firstIndex { $0.id == id })
        session.document?.layers[index].mask = LayerMask(asset: asset)
        return id
    }
    /// A 50 × 50 image shown at 2× from (50, 50): an opaque ring round a transparent middle.
    private func ringLayer(_ session: EditorSession) throws -> UUID {
        let context = try BrushRaster.context(width: 50, height: 50, mask: false)
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 10, y: 10, width: 30, height: 30))
        context.clear(CGRect(x: 20, y: 20, width: 10, height: 10))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Ring"))
        let id = try #require(session.activeLayerID)
        let index = try #require(session.document?.layers.firstIndex { $0.id == id })
        session.document?.layers[index].transform = LayerTransform(origin: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 100))
        return id
    }

    @Test func listsEachLayersTransparencyAndEachMaskTopFirst() throws {
        let session = makeSession()
        let masked = try maskedLayer(session)
        let ring = try ringLayer(session)
        let channels = session.selectionChannels
        #expect(channels.map(\.name) == ["Ring Transparency", "Layer 1 Mask"], "an empty layer has no pixels to load")
        #expect(channels.map(\.channel) == [SelectionChannel(layerID: ring, kind: .transparency),
                                            SelectionChannel(layerID: masked, kind: .mask)])
        #expect(session.defaultSelectionChannel == SelectionChannel(layerID: ring, kind: .transparency))
        session.selectLayerTarget(masked, mask: true)
        #expect(session.defaultSelectionChannel == SelectionChannel(layerID: masked, kind: .mask))
    }

    @Test func transparencyLoadsTheOpaquePixelsAndInvertedTheRest() throws {
        let session = makeSession(side: 200)
        let ring = try ringLayer(session)
        session.loadSelection(LoadSelectionOptions(channel: SelectionChannel(layerID: ring, kind: .transparency)))
        #expect(session.history.undoName == "Load Selection")
        #expect(session.selection?.path.boundingBoxOfPath == CGRect(x: 70, y: 70, width: 60, height: 60))
        #expect(try coverage(session, 75, 75) == 255 && coverage(session, 99, 99) == 0 && coverage(session, 10, 10) == 0)
        session.loadSelection(LoadSelectionOptions(channel: SelectionChannel(layerID: ring, kind: .transparency), invert: true))
        #expect(try coverage(session, 75, 75) == 0 && coverage(session, 99, 99) == 255 && coverage(session, 10, 10) == 255)
    }

    @Test func aMaskLoadsWhatItRevealsAndInvertedItsBlackAreas() throws {
        let session = makeSession()
        let id = try maskedLayer(session)
        let mask = SelectionChannel(layerID: id, kind: .mask)
        session.loadSelection(LoadSelectionOptions(channel: mask))
        #expect(try coverage(session, 25, 35) == 0 && coverage(session, 35, 45) == 255 && coverage(session, 80, 80) == 255)
        // Inverted: exactly what Select › Mask's Black Areas selected, to the pixel.
        session.loadSelection(LoadSelectionOptions(channel: mask, invert: true))
        #expect(try coverage(session, 25, 35) == 255)
        #expect(try coverage(session, 35, 45) == 0 && coverage(session, 80, 80) == 0)
        #expect(try coverage(session, 59, 69) == 255 && coverage(session, 60, 70) == 0)
        let inverted = try #require(session.selection)
        session.deselect()
        session.loadMaskSelection(layerID: id)
        let document = try #require(session.document)
        #expect(try #require(session.selection).coverage(width: document.width, height: document.height).dataProvider?.data
                == inverted.coverage(width: document.width, height: document.height).dataProvider?.data)
    }

    /// A reveal-all mask's channel is the whole canvas, so inverted there is nothing to load.
    @Test func anEmptyChannelLeavesTheSelectionAsItWas() throws {
        let session = makeSession()
        session.addLayerMask(revealing: true)
        let id = try #require(session.activeLayerID)
        lasso(session, CGRect(x: 10, y: 10, width: 20, height: 20))
        let before = session.selection
        let count = session.history.undoCount
        session.loadSelection(LoadSelectionOptions(channel: SelectionChannel(layerID: id, kind: .mask), invert: true))
        #expect(session.selection == before && session.history.undoCount == count)
        session.loadSelection(LoadSelectionOptions(channel: SelectionChannel(layerID: id, kind: .mask)))
        #expect(try coverage(session, 0, 0) == 255 && coverage(session, 50, 50) == 255 && coverage(session, 99, 99) == 255)
    }

    @Test func addsToAndSubtractsFromTheSelection() throws {
        let session = makeSession()
        let id = try maskedLayer(session)
        let black = LoadSelectionOptions(channel: SelectionChannel(layerID: id, kind: .mask), invert: true)
        lasso(session, CGRect(x: 80, y: 80, width: 10, height: 10))
        var add = black
        add.operation = .add
        session.loadSelection(add)
        #expect(try coverage(session, 85, 85) == 255 && coverage(session, 25, 35) == 255)
        var subtract = black
        subtract.operation = .subtract
        session.loadSelection(subtract)
        #expect(try coverage(session, 85, 85) == 255 && coverage(session, 25, 35) == 0)
        // Taking the whole selection away leaves none, not an empty one that stops every brush.
        lasso(session, CGRect(x: 22, y: 32, width: 4, height: 4))
        session.loadSelection(subtract)
        #expect(session.selection == nil)
        // And taking from no selection changes nothing.
        let count = session.history.undoCount
        session.loadSelection(subtract)
        #expect(session.selection == nil && session.history.undoCount == count)
    }

    @Test func theDialogWaitsForOK() throws {
        let session = makeSession()
        let id = try maskedLayer(session)
        session.beginLoadSelection()
        #expect(session.commandDialog == .loadSelection && !session.canEditSelection)
        session.finishLoadSelection(nil)
        #expect(session.commandDialog == nil && session.selection == nil)
        session.beginLoadSelection()
        session.finishLoadSelection(LoadSelectionOptions(channel: SelectionChannel(layerID: id, kind: .mask), invert: true))
        #expect(session.commandDialog == nil && session.selection != nil)
        // Nothing to load: no layer has pixels or a mask.
        let empty = makeSession()
        #expect(!empty.canLoadSelection)
        empty.beginLoadSelection()
        #expect(empty.commandDialog == nil)
    }
}
