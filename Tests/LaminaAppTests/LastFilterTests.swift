import AppKit
import SwiftUI
import Testing
import LaminaCore
@testable import LaminaApp

@MainActor
struct LastFilterTests {
    private func session() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 40, height: 20)
        let context = try BrushRaster.context(width: 40, height: 20, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Half"))
        return session
    }

    @Test func runsTheLastFilterAgainWithItsSettingsAsOneUndoStep() async throws {
        let session = try session()
        #expect(!session.canRepeatLastFilter)
        session.beginFilter(.gaussianBlur)
        session.updateFilter(FilterSettings(radius: 3), preview: true)
        await session.commitFilter()
        let once = try #require(session.activeLayer)
        #expect(session.lastFilter == .gaussianBlur && session.canRepeatLastFilter)

        let count = session.history.undoCount
        await session.repeatLastFilter()
        let twice = try #require(session.activeLayer)
        #expect(session.filterEdit == nil && session.history.undoCount == count + 1)
        #expect(twice.asset?.image !== once.asset?.image)
        // Blurred again by 3, it spreads another 3 × 3 past the edge the first blur left.
        #expect(twice.transform.size.width > once.transform.size.width)
        session.undo()
        #expect(session.activeLayer?.asset?.image === once.asset?.image)
    }

    @Test func aCancelledFilterOrAnImageAdjustmentIsNotTheLastFilter() async throws {
        let session = try session()
        session.beginFilter(.addNoise)
        await session.commitFilter()
        session.beginFilter(.gaussianBlur)
        session.cancelFilter()
        session.beginFilter(.curves)
        session.cancelFilter()
        #expect(session.lastFilter == .addNoise)
        // Nothing to do (no distortion to remove) closes without an undo step and without leaving it open.
        session.lastFilter = .lensCorrection
        let count = session.history.undoCount
        await session.repeatLastFilter()
        #expect(session.filterEdit == nil && session.history.undoCount == count)
    }

    /// Every menu shortcut belongs to one command: two share one only by accident, and then the first menu wins.
    @Test func noTwoMenuShortcutsAreTheSame() {
        let chords = ShortcutDefinition.all.filter(\.isMenu).map(\.original)
        #expect(Set(chords).count == chords.count)
    }

    /// ⌘F is Last Filter's, and Keyboard Shortcuts can change it. (The test host's menu bar isn't the app's, so the
    /// real menu bar is checked by hand.)
    @Test func commandFIsLastFilterInKeyboardShortcuts() throws {
        let entry = try #require(ShortcutDefinition.all.first { $0.isMenu && $0.title == "Last Filter" })
        #expect(entry.original == ShortcutChord("f", 1))
        let settings = ShortcutSettings(defaults: UserDefaults(suiteName: "LastFilterTests-\(UUID().uuidString)")!)
        #expect(settings.menu("f", modifiers: .command) == ShortcutChord("f", 1))
    }
}
