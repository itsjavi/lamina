import AppKit
import Testing
@testable import LaminaApp

/// The Type bar's and Properties' family menus list every installed family, the ones macOS leaves out of its own list too.
@MainActor struct FontFamiliesTests {
    /// Rockwell ships with macOS but isn't in `availableFontFamilies` (on macOS 27): both family menus still offer it,
    /// and all its styles. Skipped where Rockwell isn't installed.
    @Test(.enabled(if: NSFont(name: "Rockwell-Bold", size: 12) != nil))
    func theFamilyMenusOfferAFamilyMacOSHides() throws {
        #expect(FontMenuPicker.familyItems().contains { $0.value == "Rockwell" }, "the Type bar's family menu")
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        let coordinator = FontFamilyPopUp.Coordinator(choose: { _ in })
        coordinator.button = button
        coordinator.menuNeedsUpdate(try #require(button.menu))
        #expect(button.itemTitles.contains("Rockwell"), "Properties ▸ Character's family menu")
        #expect(Set(FontFaces.styles(of: "Rockwell").map(\.name))
            .isSuperset(of: ["Rockwell-Regular", "Rockwell-Italic", "Rockwell-Bold", "Rockwell-BoldItalic"]))
        #expect(FontFaces.face(in: "Rockwell", like: "Helvetica-Bold") == "Rockwell-Bold", "choosing it keeps the style")
    }

    @Test func theFamiliesAreTheSystemListAndTheOnesItLeavesOutInItsOrder() {
        let families = FontFaces.families
        #expect(Set(NSFontManager.shared.availableFontFamilies).isSubset(of: families))
        #expect(!families.contains { $0.hasPrefix(".") }, "the system's own interface families stay out")
        #expect(families == families.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(Set(families).count == families.count)
        let empty = families.filter { NSFontManager.shared.availableMembers(ofFontFamily: $0)?.isEmpty != false }
        #expect(empty.isEmpty, "every family listed has styles to choose")
    }
}
