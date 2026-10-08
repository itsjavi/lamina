import AppKit
import Testing
import UniformTypeIdentifiers
@testable import LaminaApp

/// File › New from Clipboard. Each test copies to a pasteboard of its own, never the person's clipboard.
@MainActor
struct NewFromClipboardTests {
    /// A pasteboard nobody else uses, released when the test is done with it.
    private func withPasteboard(_ body: (NSPasteboard) async throws -> Void) async rethrows {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        try await body(pasteboard)
    }

    /// Red on the left half, blue on the right, as PNG data.
    private func png(width: Int = 30, height: Int = 20) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (y * image.width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }

    /// Puts files on the pasteboard as Finder's Copy does: their URLs, their names, and an icon as image data.
    private func copyInFinder(_ files: [URL], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(files as [NSURL])
        pasteboard.addTypes([.string, .tiff], owner: nil)
        pasteboard.setString(files.map(\.lastPathComponent).joined(separator: "\r"), forType: .string)
        pasteboard.setData(NSWorkspace.shared.icon(forFile: files[0].path).tiffRepresentation, forType: .tiff)
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NewFromClipboardTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func anImageFromAnotherAppOpensAsANewProjectInOneStep() async throws {
        try await withPasteboard { pasteboard in
            pasteboard.clearContents()
            pasteboard.setData(try png(), forType: .png)
            let workspace = ProjectWorkspace()
            #expect(await workspace.newFromClipboard(pasteboard))
            #expect(workspace.tabs.count == 1, "the empty first tab is used, as a dropped image does")
            let session = workspace.current.session
            let document = try #require(session.document)
            #expect(document.size == CGSize(width: 30, height: 20))
            let layer = try #require(document.layers.first)
            #expect(document.layers.count == 1 && layer.name == "Layer 1" && session.activeLayerID == layer.id)
            #expect(layer.transform.origin == .zero && layer.size == CGSize(width: 30, height: 20))
            let image = try #require(layer.asset?.image)
            #expect(try pixel(image, x: 5, y: 10) == [255, 0, 0, 255])
            #expect(try pixel(image, x: 25, y: 10) == [0, 0, 255, 255])
            #expect(session.history.undoCount == 1 && session.history.undoName == "New from Clipboard")
            session.undo()
            #expect(session.document == nil, "one undo takes the whole step back")
        }
    }

    @Test func pixelsCopiedInAnOpenProjectOpenInANewTab() async throws {
        try await withPasteboard { pasteboard in
            let workspace = ProjectWorkspace()
            let source = workspace.current
            source.session.createDocument(width: 100, height: 40, emptyLayer: true)
            pasteboard.clearContents()
            pasteboard.setData(try png(), forType: .png)
            // What Copy keeps for Paste: the exact pixels, valid while the pasteboard hasn't changed since.
            let copied = try #require(EditorSession.pasteboardImage(pasteboard))
            source.session.pixelClipboard = PixelClipboard(image: copied, origin: CGPoint(x: 10, y: 5), changeCount: pasteboard.changeCount)

            #expect(await workspace.newFromClipboard(pasteboard))
            #expect(workspace.tabs.count == 2 && workspace.current !== source)
            let layer = try #require(workspace.current.session.document?.layers.first)
            #expect(workspace.current.session.document?.size == CGSize(width: 30, height: 20))
            #expect(layer.asset?.image === copied && layer.transform.origin == .zero)
            #expect(source.session.document?.layers.count == 1, "the source project is untouched")
        }
    }

    @Test func imageFilesCopiedInFinderOpenAsProjectsNotTheirIcons() async throws {
        let files = try folder()
        defer { try? FileManager.default.removeItem(at: files) }
        let photo = files.appendingPathComponent("photo.png")
        try png(width: 12, height: 7).write(to: photo)
        let notes = files.appendingPathComponent("notes.txt")
        try Data("Some notes".utf8).write(to: notes)
        try await withPasteboard { pasteboard in
            copyInFinder([notes, photo], to: pasteboard)
            #expect(await ProjectWorkspace.offersImage(pasteboard))
            let workspace = ProjectWorkspace()
            #expect(await workspace.newFromClipboard(pasteboard))
            #expect(workspace.tabs.count == 1)
            let document = try #require(workspace.current.session.document)
            #expect(document.size == CGSize(width: 12, height: 7) && document.layers.count == 1)

            // A file that isn't an image brings only its icon, which is no image to open.
            copyInFinder([notes], to: pasteboard)
            #expect(!(await ProjectWorkspace.offersImage(pasteboard)))
            #expect(!(await workspace.newFromClipboard(pasteboard)))
            #expect(workspace.tabs.count == 1)
        }
    }

    /// The menu item's enabled state follows the clipboard without reading what's on it.
    @Test func theCommandIsEnabledOnlyWithAnImageOnTheClipboard() async throws {
        try await withPasteboard { pasteboard in
            let workspace = ProjectWorkspace()
            await workspace.refreshClipboard(pasteboard)
            #expect(!workspace.clipboardOffersImage, "an empty clipboard")
            pasteboard.clearContents()
            pasteboard.setString("Some copied text", forType: .string)
            await workspace.refreshClipboard(pasteboard)
            #expect(!workspace.clipboardOffersImage, "text")
            #expect(!(await workspace.newFromClipboard(pasteboard)))
            pasteboard.clearContents()
            pasteboard.setData(try png(), forType: .png)
            await workspace.refreshClipboard(pasteboard)
            #expect(workspace.clipboardOffersImage, "an image")
            pasteboard.clearContents()
            await workspace.refreshClipboard(pasteboard)
            #expect(!workspace.clipboardOffersImage, "cleared again")
        }
    }

    @Test func anImagePastTheSideLimitIsRefused() async throws {
        try await withPasteboard { pasteboard in
            pasteboard.clearContents()
            pasteboard.setData(try png(width: DocumentLimits.maxSide + 1, height: 1), forType: .png)
            let workspace = ProjectWorkspace()
            #expect(await workspace.newFromClipboard(pasteboard))
            #expect(workspace.current.session.document == nil && workspace.current.session.importError != nil)
        }
    }

    /// ⇧⌘V stays free for Photoshop's Paste in Place.
    @Test func itsShortcutLeavesPasteInPlaceAlone() throws {
        let entry = try #require(ShortcutDefinition.all.first { $0.isMenu && $0.title == "New from Clipboard" })
        #expect(entry.original == ShortcutChord("n", 3))
        #expect(!ShortcutDefinition.all.contains { $0.isMenu && $0.original == ShortcutChord("v", 9) })
    }
}
