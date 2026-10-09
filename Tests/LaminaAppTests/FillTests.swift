import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// Edit › Fill… (docs/DESIGN.md, Menus and Dialogs): each kind of contents, its opacity, masks, and the dialog's
/// way in and out.
@MainActor
struct FillTests {
    private func makeSession() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 60, height: 40, emptyLayer: true)
        return session
    }
    /// A layer with pixels: an opaque blue image covering the canvas.
    private func imageSession() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 60, height: 40)
        let context = try BrushRaster.context(width: 60, height: 40, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 60, height: 40))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Blue"))
        return session
    }
    private func select(_ session: EditorSession, _ rect: CGRect) {
        session.applySelection(CGPath(rect: rect, transform: nil), mode: .replace, name: "Select")
    }
    private func pixel(_ session: EditorSession, x: Int, y: Int) async throws -> [Int] {
        let image = try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (y * image.width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }
    /// The active layer's mask value in the middle of its pixels.
    private func maskValue(_ session: EditorSession) throws -> Int {
        let image = try #require(session.activeLayer?.mask?.asset.image)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Int(bytes[(image.height / 2) * image.width + image.width / 2])
    }

    @Test func eachColorContentsFillsTheSelection() async throws {
        let session = makeSession()
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        session.backgroundColor = PaletteColor(red: 0, green: 1, blue: 0)
        let cases: [(FillContents, [Int])] = [
            (.foreground, [255, 0, 0, 255]), (.background, [0, 255, 0, 255]), (.color, [0, 0, 255, 255]),
            (.black, [0, 0, 0, 255]), (.gray, [128, 128, 128, 255]), (.white, [255, 255, 255, 255]),
        ]
        for (index, (contents, expected)) in cases.enumerated() {
            // Each in its own 10 px column, so one fill doesn't hide another.
            select(session, CGRect(x: index * 10, y: 0, width: 10, height: 20))
            await session.fill(FillOptions(contents: contents, color: PaletteColor(red: 0, green: 0, blue: 1)))
            #expect(session.history.undoName == "Fill", "\(contents.rawValue)")
            #expect(try await pixel(session, x: index * 10 + 5, y: 5) == expected, "\(contents.rawValue)")
            #expect(try await pixel(session, x: index * 10 + 5, y: 30)[3] == 0, "only the selection: \(contents.rawValue)")
        }
    }

    @Test func opacityBlendsOverWhatIsThere() async throws {
        let session = makeSession()
        await session.fill(FillOptions(contents: .white))
        await session.fill(FillOptions(contents: .black, opacity: 0.5))
        let value = try await pixel(session, x: 30, y: 20)
        #expect((126...129).contains(value[0]) && value[0] == value[1] && value[3] == 255)
    }

    @Test func onAMaskColorsFillByTheirBrightness() async throws {
        let session = makeSession()
        session.addLayerMask(revealing: true)
        #expect(session.isMaskSelected)
        await session.fill(FillOptions(contents: .black))
        #expect(session.history.undoName == "Fill Mask")
        #expect(try maskValue(session) == 0)
        await session.fill(FillOptions(contents: .gray))
        #expect(abs(try maskValue(session) - 128) <= 1)
        // Pure red is about 30% bright.
        await session.fill(FillOptions(contents: .color, color: PaletteColor(red: 1, green: 0, blue: 0)))
        #expect(abs(try maskValue(session) - 76) <= 1)
        // The swatches stand for white and black on a mask.
        await session.fill(FillOptions(contents: .foreground))
        let foreground = try maskValue(session)
        await session.fill(FillOptions(contents: .background))
        #expect(Set([foreground, try maskValue(session)]) == [0, 255])
    }

    @Test func contentAwareOpensContentAwareFill() async throws {
        let session = try imageSession()
        select(session, CGRect(x: 20, y: 10, width: 10, height: 10))
        session.fillOptions.contents = .contentAware
        session.beginFill()
        #expect(session.commandDialog == .fill)
        await session.finishFill(FillOptions(contents: .contentAware))
        #expect(session.commandDialog == nil && session.filterEdit?.kind == .contentAwareFill)
        session.cancelFilter()
        // Without a selection it can't, so the dialog starts on the foreground color.
        session.deselect()
        session.beginFill()
        #expect(session.fillOptions.contents == .foreground)
        await session.finishFill(nil)
    }

    @Test func theDialogWaitsForOKAndKeepsItsSettings() async throws {
        let session = makeSession()
        let count = session.history.undoCount
        session.beginFill()
        #expect(session.commandDialog == .fill && !session.canEditLayers && !session.canFill, "other edits wait")
        await session.finishFill(nil)
        #expect(session.commandDialog == nil && session.history.undoCount == count, "Cancel changes nothing")
        session.beginFill()
        await session.finishFill(FillOptions(contents: .white, opacity: 0.4))
        #expect(session.history.undoCount == count + 1 && session.fillOptions == FillOptions(contents: .white, opacity: 0.4))
        // Nothing to fill on: a group's pixels.
        session.addGroup()
        session.beginFill()
        #expect(session.commandDialog == nil)
    }

    /// ⌥⌫ and ⌘⌫ still fill straight away, with no dialog.
    @Test func directFillsUseTheSwatches() async throws {
        let session = makeSession()
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        await session.fillSelection(with: .foreground)
        #expect(try await pixel(session, x: 5, y: 5) == [255, 0, 0, 255] && session.commandDialog == nil)
    }
}
