import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

@MainActor
struct LayerAlignTests {
    /// A 400 × 300 canvas with a solid layer for each of `rects`, bottom to top.
    private func session(_ rects: [CGRect]) throws -> (EditorSession, [UUID]) {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        var ids: [UUID] = []
        for rect in rects {
            let context = try BrushRaster.context(width: Int(rect.width), height: Int(rect.height), mask: false)
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(origin: .zero, size: rect.size))
            let image = try #require(context.makeImage())
            session.insert(ImportedImage(image: image, thumbnail: image, name: "Box"), centeredAt: CGPoint(x: rect.midX, y: rect.midY))
            ids.append(try #require(session.activeLayerID))
        }
        return (session, ids)
    }

    private func origins(_ session: EditorSession, _ ids: [UUID]) -> [CGPoint] {
        ids.compactMap { id in session.document?.layers.first { $0.id == id }?.transform.origin }
    }

    @Test func severalLayersAlignToEachOther() throws {
        let (session, ids) = try session([CGRect(x: 10, y: 20, width: 40, height: 30),
                                          CGRect(x: 100, y: 60, width: 60, height: 20),
                                          CGRect(x: 200, y: 10, width: 20, height: 50)])
        session.selectedLayerIDs = Set(ids)
        session.alignLayers(.left)
        #expect(origins(session, ids).map(\.x) == [10, 10, 10])
        session.alignLayers(.bottom)
        #expect(origins(session, ids).map(\.y) == [50, 60, 30])
        session.undo()
        #expect(origins(session, ids).map(\.y) == [20, 60, 10])
    }

    @Test func oneLayerAlignsToTheCanvasAndTheSelectionComesFirst() throws {
        let (session, ids) = try session([CGRect(x: 10, y: 10, width: 101, height: 60)])
        session.selectedLayerIDs = Set(ids)
        session.alignLayers(.horizontalCenter)
        // 400 − 101 leaves an odd 299 to share: the layer lands on a whole pixel, not between two.
        #expect(origins(session, ids).first?.x == 150)
        session.alignLayers(.verticalCenter)
        #expect(origins(session, ids).first?.y == 120)
        session.document?.selection = DocumentSelection(path: CGPath(rect: CGRect(x: 300, y: 0, width: 50, height: 50), transform: nil))
        session.alignLayers(.right)
        #expect(origins(session, ids).first?.x == 249)
    }

    @Test func aSelectedFolderMovesAsOne() throws {
        let (session, ids) = try session([CGRect(x: 50, y: 10, width: 20, height: 20),
                                          CGRect(x: 90, y: 40, width: 20, height: 20),
                                          CGRect(x: 200, y: 100, width: 20, height: 20)])
        session.selectedLayerIDs = [ids[0], ids[1]]
        session.groupSelectedLayers()
        let folder = try #require(session.activeLayerID)
        session.selectedLayerIDs = [folder, ids[2]]
        session.alignLayers(.left)
        // The folder's box already starts furthest left; its layers keep their spacing, and the third joins them.
        #expect(origins(session, ids).map(\.x) == [50, 90, 50])
    }

    /// A 100 × 100 layer, clear but for a 20 × 20 square 60 px in from the left and 10 down, centered at `center`.
    private func insertPadded(_ session: EditorSession, centeredAt center: CGPoint) throws -> UUID {
        let context = try BrushRaster.context(width: 100, height: 100, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 60, y: 10, width: 20, height: 20))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Padded"), centeredAt: center)
        return try #require(session.activeLayerID)
    }

    /// As in Photoshop, a layer lines up by the pixels it shows, not by its transparent padding.
    @Test func layersAlignByTheirVisiblePixels() throws {
        let (session, ids) = try session([CGRect(x: 10, y: 20, width: 40, height: 30)])
        // Placed at 150, 100: its square shows from 210, 110 to 230, 130.
        let padded = try insertPadded(session, centeredAt: CGPoint(x: 200, y: 150))
        session.selectedLayerIDs = [ids[0], padded]
        session.alignLayers(.left)
        // The square's left edge meets the box's at 10; its transform box would have put the layer itself there.
        #expect(origins(session, [ids[0], padded]).map(\.x) == [10, -50])
        session.alignLayers(.top)
        #expect(origins(session, [ids[0], padded]).map(\.y) == [20, 10])
        // Alone, it centers its square on the canvas: the square's middle at 200 puts the layer at 130.
        session.selectedLayerIDs = [padded]
        session.alignLayers(.horizontalCenter)
        #expect(origins(session, [padded]).first?.x == 130)
        // Flipped, the square sits 20 px in from the layer's left edge instead, and that is what reaches the canvas's.
        let index = try #require(session.document?.layers.firstIndex { $0.id == padded })
        session.document?.layers[index].transform.flipX = true
        session.alignLayers(.left)
        #expect(origins(session, [padded]).first?.x == -20)
    }

    @Test func aLayerShowingNothingIsLeftAlone() throws {
        let (session, ids) = try session([CGRect(x: 10, y: 20, width: 40, height: 30), CGRect(x: 100, y: 60, width: 60, height: 20)])
        let context = try BrushRaster.context(width: 30, height: 30, mask: false)
        let empty = try #require(context.makeImage())
        session.insert(ImportedImage(image: empty, thumbnail: empty, name: "Empty"), centeredAt: CGPoint(x: 300, y: 200))
        let clear = try #require(session.activeLayerID)
        session.selectedLayerIDs = Set(ids + [clear])
        session.alignLayers(.left)
        #expect(origins(session, ids + [clear]).map(\.x) == [10, 10, 285])
    }

    @Test func aHiddenLayerMovesWithItsFolderButIsNotMeasured() throws {
        let (session, ids) = try session([CGRect(x: 50, y: 10, width: 20, height: 20),
                                          CGRect(x: 90, y: 40, width: 20, height: 20),
                                          CGRect(x: 200, y: 100, width: 20, height: 20)])
        session.selectedLayerIDs = [ids[0], ids[1]]
        session.groupSelectedLayers()
        let folder = try #require(session.activeLayerID)
        let index = try #require(session.document?.layers.firstIndex { $0.id == ids[0] })
        session.document?.layers[index].isVisible = false
        session.selectedLayerIDs = [folder, ids[2]]
        session.alignLayers(.right)
        // The folder measures 90 to 110, its showing layer alone, and moves 110 to end at 220 with the third.
        #expect(origins(session, ids).map(\.x) == [160, 200, 200])
    }

    @Test func distributeSpreadsMiddlesOrGapsEvenly() {
        let boxes = [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 60, y: 0, width: 30, height: 10),
                     CGRect(x: 100, y: 0, width: 10, height: 10)]
        // Middles at 5, 75 and 105: the middle one moves to 55.
        #expect(LayerDistribution.horizontalCenters.offsets(of: boxes).map(\.width) == [0, -20, 0])
        // 110 across, 50 of it boxes: gaps of 30 put the middle one at 40.
        #expect(LayerDistribution.horizontalSpacing.offsets(of: boxes).map(\.width) == [0, -20, 0])
        let uneven = [CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 0, y: 70, width: 10, height: 10),
                      CGRect(x: 0, y: 20, width: 10, height: 40), CGRect(x: 0, y: 100, width: 10, height: 10)]
        // Order follows position, not the list: gaps of (110 − 70) / 3.
        let gap: CGFloat = 40 / 3
        let spaced = LayerDistribution.verticalSpacing.offsets(of: uneven).map(\.height)
        #expect(abs(spaced[2] - (10 + gap - 20)) < 0.001)
        #expect(abs(spaced[1] - (10 + gap + 40 + gap - 70)) < 0.001)
        #expect(spaced[0] == 0 && spaced[3] == 0)
    }

    @Test func distributeNeedsThreeAndMovesWholePixels() throws {
        let (session, ids) = try session([CGRect(x: 0, y: 0, width: 10, height: 10),
                                          CGRect(x: 50, y: 0, width: 10, height: 10),
                                          CGRect(x: 101, y: 0, width: 10, height: 10)])
        session.selectedLayerIDs = [ids[0], ids[1]]
        session.distributeLayers(.horizontalCenters)
        #expect(origins(session, ids).map(\.x) == [0, 50, 101])
        session.selectedLayerIDs = Set(ids)
        session.distributeLayers(.horizontalCenters)
        #expect(origins(session, ids).map(\.x) == [0, 51, 101])
    }
}