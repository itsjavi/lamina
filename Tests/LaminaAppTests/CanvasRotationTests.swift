import AppKit
import ImageIO
import Testing
import LaminaCore
@testable import LaminaApp

@MainActor
struct CanvasRotationTests {
    /// A 5 × 3 canvas filled by one layer whose every pixel is its own color, so any misplaced or blended pixel shows.
    private func session() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 5, height: 3)
        let context = try BrushRaster.context(width: 5, height: 3, mask: false)
        for y in 0..<3 {
            for x in 0..<5 {
                context.setFillColor(CGColor(srgbRed: CGFloat(x) / 4, green: CGFloat(y) / 2, blue: 0.5, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Pixels"))
        return session
    }

    private func render(_ session: EditorSession) async throws -> NSBitmapImageRep {
        let snapshot = try #require(session.projectSnapshot())
        let data = try await ImageExporter.shared.pngData(snapshot)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return NSBitmapImageRep(cgImage: try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)))
    }

    private func bytes(_ image: CGImage?) throws -> Data {
        let image = try #require(image)
        return try #require(image.dataProvider?.data) as Data
    }

    @Test func quarterAndHalfTurnsMovePixelsExactly() async throws {
        let original = try await render(try session())
        for rotation in CanvasRotation.allCases {
            let session = try session()
            await session.rotateCanvas(rotation)
            let document = try #require(session.document)
            #expect(document.width == (rotation.swapsSides ? 3 : 5))
            #expect(document.height == (rotation.swapsSides ? 5 : 3))
            // The pixels were turned, so the layer stays upright and unscaled: nothing is resampled when drawn.
            let layer = try #require(document.layers.first)
            #expect(layer.transform.rotation == 0)
            #expect(layer.transform.origin == .zero)
            #expect(layer.transform.size == document.size)
            #expect(layer.asset?.image.width == document.width)
            let turned = try await render(session)
            let map = rotation.map(width: 5, height: 3)
            for y in 0..<3 {
                for x in 0..<5 {
                    // The pixel's middle, carried by the turn, lands in the middle of its new pixel.
                    let middle = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5).applying(map)
                    let expected = try #require(original.colorAt(x: x, y: y))
                    let actual = try #require(turned.colorAt(x: Int(middle.x), y: Int(middle.y)))
                    #expect(abs(actual.redComponent - expected.redComponent) < 0.01, "\(rotation) \(x),\(y)")
                    #expect(abs(actual.greenComponent - expected.greenComponent) < 0.01, "\(rotation) \(x),\(y)")
                    #expect(actual.alphaComponent == 1, "\(rotation) \(x),\(y)")
                }
            }
        }
    }

    @Test func fullTurnAndUndoGiveBackTheOriginal() async throws {
        let session = try session()
        let original = try #require(session.document)
        for _ in 0..<4 { await session.rotateCanvas(.clockwise) }
        #expect(session.document?.layers.map(\.transform) == original.layers.map(\.transform))
        #expect(try bytes(session.document?.layers.first?.asset?.image) == bytes(original.layers.first?.asset?.image))
        await session.rotateCanvas(.counterclockwise)
        await session.rotateCanvas(.clockwise)
        #expect(try bytes(session.document?.layers.first?.asset?.image) == bytes(original.layers.first?.asset?.image))
        await session.rotateCanvas(.halfTurn)
        session.undo()
        #expect(try bytes(session.document?.layers.first?.asset?.image) == bytes(original.layers.first?.asset?.image))
        #expect(session.document?.width == 5)
        for _ in 0..<6 { session.undo() }
        #expect(session.document == original)
    }

    @Test func selectionGuidesAndMasksTurnWithTheCanvas() async throws {
        let session = try session()
        session.document?.selection = DocumentSelection(path: CGPath(rect: CGRect(x: 0, y: 0, width: 2, height: 1), transform: nil))
        session.addGuide(CanvasGuide(id: UUID(), axis: .vertical, position: 1))
        session.addGuide(CanvasGuide(id: UUID(), axis: .horizontal, position: 1))
        // A mask hiding the layer's left column.
        let mask = try BrushRaster.context(width: 5, height: 3, mask: true)
        mask.setFillColor(gray: 1, alpha: 1)
        mask.fill(CGRect(x: 0, y: 0, width: 5, height: 3))
        mask.setFillColor(gray: 0, alpha: 1)
        mask.fill(CGRect(x: 0, y: 0, width: 1, height: 3))
        session.document?.layers[0].mask = LayerMask(asset: try LayerMask.asset(from: try #require(mask.makeImage())))
        await session.rotateCanvas(.clockwise)
        #expect(session.document?.selection?.path.boundingBoxOfPath == CGRect(x: 2, y: 0, width: 1, height: 2))
        // A vertical guide at x = 1 becomes a horizontal one at y = 1; a horizontal one at y = 1 a vertical at 3 − 1.
        #expect(session.document?.guides.first { $0.axis == .horizontal }?.position == 1)
        #expect(session.document?.guides.first { $0.axis == .vertical }?.position == 2)
        // The hidden column is now the top row.
        let turned = try await render(session)
        #expect(try #require(turned.colorAt(x: 1, y: 0)).alphaComponent == 0)
        #expect(try #require(turned.colorAt(x: 1, y: 1)).alphaComponent == 1)
    }

    @Test func placementsFollowTheTurn() {
        let map = CanvasRotation.clockwise.map(width: 5, height: 3)
        let placement = LayerTransform(origin: CGPoint(x: 1, y: 1), size: CGSize(width: 2, height: 1), flipX: true)
        // Turned pixels: sides swap, the flip moves to the other axis, the angle stays.
        #expect(placement.placingTurnedPixels(.clockwise, by: map)
            == LayerTransform(origin: CGPoint(x: 1, y: 1), size: CGSize(width: 1, height: 2), flipY: true))
        // Live text and shapes turn by their angle instead.
        #expect(placement.turned(90, by: map)
            == LayerTransform(origin: CGPoint(x: 0.5, y: 1.5), size: CGSize(width: 2, height: 1), rotation: 90, flipX: true))
    }

    /// Turning keeps every layer as it was apart from its place and pixels, unlike a document rebuilt from a project
    /// snapshot: layer effects stay, and live text and shapes stay editable, turned by their angle.
    @Test func effectsLiveTextAndShapesSurviveATurn() async throws {
        let session = EditorSession()
        session.createDocument(width: 200, height: 100, emptyLayer: true)
        let pixels = try BrushRaster.context(width: 20, height: 10, mask: false)
        pixels.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        pixels.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        let image = try #require(pixels.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Pixels"), centeredAt: CGPoint(x: 150, y: 80))
        let pixel = try #require(session.activeLayerID)
        session.selectTool(.rectangle)
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        session.beginShape(at: CGPoint(x: 10, y: 10))
        session.dragShape(to: CGPoint(x: 60, y: 40), square: false, fromCenter: false)
        session.finishShape()
        let shape = try #require(session.activeLayerID)
        session.selectTool(.type)
        session.beginText(at: CGPoint(x: 100, y: 20))
        session.textDraft?.style.content = "Text"
        #expect(session.applyText(try #require(session.textDraft)))
        let text = try #require(session.activeLayerID)
        session.selectTool(.move)
        var effects = LayerEffects()
        effects.shadow = ShadowEffect()
        effects.stroke = StrokeEffect()
        for id in [pixel, shape, text] { session.setEffects(effects, on: id, name: "Add Effects") }
        let before = try #require(session.document)
        #expect(before.layers.first { $0.id == shape }?.liveShape != nil && before.layers.first { $0.id == text }?.liveText != nil)

        await session.rotateCanvas(.clockwise)
        let after = try #require(session.document)
        #expect(after.width == 100 && after.height == 200)
        for id in [pixel, shape, text] { #expect(after.layers.first { $0.id == id }?.effects == effects) }
        let shapeLayer = try #require(after.layers.first { $0.id == shape })
        let textLayer = try #require(after.layers.first { $0.id == text })
        #expect(shapeLayer.liveShape != nil && shapeLayer.transform.rotation == 90)
        #expect(textLayer.liveText != nil && textLayer.transform.rotation == 90)
        // The pixel layer's own pixels turned instead, so it stays upright.
        #expect(after.layers.first { $0.id == pixel }?.asset?.image.width == 10)
        session.undo()
        #expect(session.document == before)
    }
}