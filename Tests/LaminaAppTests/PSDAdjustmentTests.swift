import CoreGraphics
import Foundation
import Testing
import LaminaCore
@testable import LaminaApp

/// Layer masks read from a PSD, laid out as Photoshop writes them. Reading adjustment layers is tested in
/// LaminaCoreTests (PSDReaderTests).
struct PSDAdjustmentTests {
    @Test func maskPatchSitsWhereItIsOnTheCanvas() throws {
        // A 2 × 2 white patch at (3, 1) on a 6 × 4 canvas, black everywhere else, on an adjustment layer (no pixels of its
        // own, so it covers the canvas): the patch must land at (3, 1), not stretch over the whole layer.
        let patch = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 2,
                                           space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        patch.setFillColor(gray: 1, alpha: 1)
        patch.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        var record = PSDRecord(id: UUID(), parentID: nil, name: "Levels")
        record.maskBounds = CGRect(x: 3, y: 1, width: 2, height: 2)
        record.maskDefault = 0
        let canvas = CGSize(width: 6, height: 4)
        let layer = ImageLayer(id: UUID(), asset: nil, name: "Levels", isVisible: true,
                               transform: LayerTransform(origin: .zero, size: canvas), parentID: nil)
        let patchImage = try #require(patch.makeImage())
        let mask = try #require(PSDDocumentBuilder.maskOnLayerGrid(patchImage, record: record, layer: layer, canvas: canvas))
        #expect(mask.width == 6 && mask.height == 4)
        let pixels = try #require(mask.dataProvider?.data as Data?)
        let rows = (0..<4).map { y in (0..<6).map { x in pixels[y * mask.bytesPerRow + x] > 127 ? "#" : "." }.joined() }
        #expect(rows == ["......", "...##.", "...##.", "......"])
    }
}
