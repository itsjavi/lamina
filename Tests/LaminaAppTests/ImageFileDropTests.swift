import AppKit
import Testing
@testable import LaminaApp

/// A browser showing a file from disk hands it over by reference; the drop finds that file in the drag's URLs.
@MainActor
struct ImageFileDropTests {
    private func pasteboard(_ urls: [String]) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ImageFileDropTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { url in
            let item = NSPasteboardItem()
            item.setString(url, forType: .URL)
            return item
        })
        return pasteboard
    }

    private func provider(named name: String?) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = name
        return provider
    }

    @Test func aBrowsersLocalFileIsFoundByName() {
        let drag = pasteboard(["file:///Users/me/a.webp", "file:///Users/me/b.webp"])
        #expect(ImageFileDrop.referencedFile(for: provider(named: "b.webp"), in: drag)?.path == "/Users/me/b.webp")
        #expect(ImageFileDrop.referencedFile(for: provider(named: "a"), in: drag)?.path == "/Users/me/a.webp")
        // Two candidates and no name to tell them apart: none is guessed.
        #expect(ImageFileDrop.referencedFile(for: provider(named: nil), in: drag) == nil)
    }

    @Test func aSingleLocalFileNeedsNoName() {
        let drag = pasteboard(["file:///Users/me/photo.webp"])
        #expect(ImageFileDrop.referencedFile(for: provider(named: nil), in: drag)?.lastPathComponent == "photo.webp")
    }

    @Test func webAddressesAreNotFiles() {
        let drag = pasteboard(["https://example.com/photo.webp"])
        #expect(ImageFileDrop.referencedFile(for: provider(named: "photo.webp"), in: drag) == nil)
    }
}
