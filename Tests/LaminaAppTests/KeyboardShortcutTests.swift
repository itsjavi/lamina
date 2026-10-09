import AppKit
import SwiftUI
import Testing
import LaminaCore
@testable import LaminaApp

@MainActor
struct KeyboardShortcutTests {
    /// Settings kept in a throwaway defaults suite, so a test never touches the person's real shortcuts.
    private func settings() -> ShortcutSettings {
        ShortcutSettings(defaults: UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!)
    }

    private func key(_ characters: String, code: UInt16, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: code)!
    }

    @Test func defaultsHaveUniqueIDsAndNoConflicts() {
        let ids = ShortcutDefinition.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ShortcutSettings.problem(in: [:]) == nil)
    }

    @Test func unassignedHasNoKeyAndReadsAsNone() {
        #expect(ShortcutChord.unassigned.isNone)
        #expect(ShortcutChord.unassigned.keyboardShortcut == nil)
        #expect(ShortcutChord.unassigned.label == "None")
        #expect(ShortcutChord("z", 1).keyboardShortcut == KeyboardShortcut("z", modifiers: .command))
    }

    @Test func clearedMenuShortcutHasNoKeyRatherThanItsDefault() throws {
        let settings = settings()
        let undo = try #require(ShortcutDefinition.all.first { $0.isMenu && $0.title == "Undo" })
        settings.save([undo.id: .unassigned])
        #expect(settings.menu("z", modifiers: .command).isNone)
        #expect(ShortcutSettings.problem(in: [undo.id: .unassigned]) == nil, "several cleared shortcuts never conflict")
    }

    @Test func clearedCanvasKeyIsSwallowed() throws {
        let settings = settings()
        let brush = try #require(ShortcutDefinition.all.first { $0.title == "Brush tool" })
        settings.save([brush.id: .unassigned])
        #expect(settings.canvasEvent(key("b", code: 11)) == nil)
        #expect(settings.canvasEvent(key("v", code: 9)) != nil, "other keys still reach the canvas")
    }

    @Test func overridesForTitlesThatNoLongerExistAreIgnored() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let saved = ["Menus:Gone Command": ShortcutChord("k", 1), "Menus:Undo": ShortcutChord("y", 1)]
        defaults.set(try! JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu("z", modifiers: .command) == ShortcutChord("y", 1))
    }

    /// A saved value that can't be decoded at all (damaged, or edited by hand) drops alone too.
    @Test func anUndecodableOverrideDropsAloneOnLoad() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let saved = #"{"Menus:Undo": {"key": "y", "modifiers": 1}, "Menus:Redo": {"key": 5}, "Menus:Save": "⌘S"}"#
        defaults.set(Data(saved.utf8), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu("z", modifiers: .command) == ShortcutChord("y", 1), "the readable one is kept")
        #expect(settings.menu("z", modifiers: [.command, .shift]) == ShortcutChord("z", 9))
        #expect(settings.menu("s", modifiers: .command) == ShortcutChord("s", 1))
    }

    @Test func everyFilterAdjustmentAndLayerMenuCommandIsAssignable() {
        let titles = Set(ShortcutDefinition.all.filter { $0.group == ShortcutDefinition.moreGroup }.map(\.title))
        // Every filter has a place in the Filter menu's submenus, but those with keys of their own and the two that
        // live in Edit and Layer.
        let placed = FilterKind.filterMenu.flatMap { submenu in submenu.kinds.compactMap { $0 }.map { (submenu.title, $0) } }
        let elsewhere: Set<FilterKind> = [.cameraRaw, .lensCorrection, .contentAwareFill, .removeBackground]
        #expect(Set(placed.map(\.1)) == Set(FilterKind.allCases.filter { !$0.isImageAdjustment && !elsewhere.contains($0) }))
        for (submenu, kind) in placed {
            #expect(titles.contains("Filter › \(submenu) › \(kind.rawValue)…"), "\(kind.rawValue)")
        }
        #expect(titles.contains("Layer › Remove Background…") && titles.contains("Edit › Content-Aware Fill…"))
        for kind in [FilterKind.exposure, .gradientMap, .grain] {
            #expect(titles.contains("Image › Adjustments › \(kind.rawValue)…"), "\(kind.rawValue)")
        }
        #expect(Set(AdjustmentKind.menuSections.joined()) == Set(AdjustmentKind.allCases)
                && AdjustmentKind.menuSections.joined().count == AdjustmentKind.allCases.count)
        for kind in AdjustmentKind.allCases {
            #expect(titles.contains("Layer › New Adjustment Layer › \(kind.rawValue)"), "\(kind.rawValue)")
        }
        #expect(Set(LayerAlignment.menuSections.joined()) == Set(LayerAlignment.allCases))
        #expect(Set(LayerDistribution.menuSections.joined()) == Set(LayerDistribution.allCases))
        for title in ["Select › Color Range…", "Select › Subject", "Select › Load Selection…", "Lamina › Check for Updates…",
                      "Lamina › Show All", "File › Open Recent › Clear Recent File List", "Type › Panels › Character",
                      "Layer › Layer Mask › Reveal All", "Layer › Layer Mask › Apply", "Layer › Delete › Layer"] {
            #expect(titles.contains(title), "\(title)")
        }
    }

    private func menuDefault(_ title: String) -> ShortcutChord? {
        ShortcutDefinition.all.first { $0.isMenu && $0.title == title }?.original
    }

    /// docs/DESIGN.md, Shortcut changes: the keys familiar editors use.
    @Test func shortcutChangesApply() throws {
        let f5 = ShortcutChord.functionKey(5), f6 = ShortcutChord.functionKey(6)
        let expected: [String: ShortcutChord] = [
            "Last Filter": ShortcutChord("f", 5), "Merge Visible": ShortcutChord("e", 9), "Extras": ShortcutChord("h", 1),
            "Hide Lamina": ShortcutChord("h", 5), "Fill": ShortcutChord(f5, 8), "Color Balance": ShortcutChord("b", 1),
            "Black & White": ShortcutChord("b", 11), "Camera Raw Filter": ShortcutChord("a", 9),
            "Lens Correction": ShortcutChord("r", 9), "Liquify": ShortcutChord("x", 9), "Feather": ShortcutChord(f6, 8),
            "Hide Layers": ShortcutChord(",", 1), "Keyboard Shortcuts": ShortcutChord("k", 11),
            "Export As": ShortcutChord("w", 11), "Free Transform": ShortcutChord("t", 1), "Settings": ShortcutChord("k", 1),
        ]
        for (title, chord) in expected { #expect(menuDefault(title) == chord, "\(title)") }
        // The keys they gave up belong to no menu command now: ⌘F (Photoshop's Search), ⌥⌘A (All Layers).
        for freed in [ShortcutChord("f", 1), ShortcutChord("a", 3)] {
            #expect(!ShortcutDefinition.all.contains { $0.original == freed }, "\(freed.label)")
        }
        // Commands that ship without a key now.
        let more = ShortcutDefinition.all.filter { $0.group == ShortcutDefinition.moreGroup }
        for title in ["File › Export › Quick Export as PNG", "Select › Subject", "Edit › Content-Aware Fill…"] {
            #expect(more.first { $0.title == title }?.original.isNone == true, "\(title)")
        }
        // Fill…'s second key, and the direct fills, which have no menu items.
        let canvas = Dictionary(uniqueKeysWithValues: ShortcutDefinition.all.filter { $0.group == "Canvas & Layers" }
            .map { ($0.title, $0.original) })
        #expect(canvas["Fill… (second shortcut)"] == ShortcutChord("\u{7f}", 8))
        #expect(canvas["Fill with foreground color"] == ShortcutChord("\u{7f}", 2))
        #expect(canvas["Fill with background color"] == ShortcutChord("\u{7f}", 1))
        // The Keyboard Shortcuts window lists every one of them, and no two commands share a key.
        #expect(ShortcutSettings.problem(in: [:]) == nil)
        let ids = ShortcutDefinition.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// F5 and F6 as the menus take them, the list shows them and a recorded key press reads them.
    @Test func functionKeysWorkAsShortcuts() throws {
        let f5 = ShortcutChord(ShortcutChord.functionKey(5), 8)
        #expect(f5.label == "⇧F5" && ShortcutChord(ShortcutChord.functionKey(12)).label == "F12")
        #expect(f5.keyboardShortcut == KeyboardShortcut(KeyEquivalent(Character("\u{F708}")), modifiers: .shift))
        #expect(ShortcutChord(key("\u{F708}", code: 96, .shift)) == f5)
        #expect(f5.event(like: key("a", code: 0))?.keyCode == 96)
        let settings = settings()
        #expect(settings.menu(KeyEquivalent(Character(ShortcutChord.functionKey(5))), modifiers: .shift) == f5)
        let fill = try #require(ShortcutDefinition.all.first { $0.isMenu && $0.title == "Fill" })
        settings.save([fill.id: ShortcutChord("f", 6)])
        #expect(settings.menu(KeyEquivalent(Character(ShortcutChord.functionKey(5))), modifiers: .shift) == ShortcutChord("f", 6))
    }

    /// Keys people gave commands that TASK-62 renamed or moved stay with those commands.
    @Test func customKeysOfRenamedAndMovedCommandsCarryOver() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let more = ShortcutDefinition.moreGroup
        let saved = [
            "Menus:New Blank Layer": ShortcutChord("n", 5),
            "Menus:Fit Canvas": ShortcutChord("0", 5),
            "Menus:Export PNG": ShortcutChord("p", 5),
            "Menus:Select Subject": ShortcutChord("s", 7),
            "Menus:Fill with Foreground": ShortcutChord("f", 6),
            "\(more):File › Import Images…": ShortcutChord("i", 5),
            "\(more):Image › Color Balance…": ShortcutChord("c", 7),
            "\(more):Filter › Gaussian Blur…": ShortcutChord("g", 7),
            "\(more):Filter › Remove Background…": ShortcutChord("r", 7),
            "\(more):View › Snap": ShortcutChord("s", 5),
            "\(more):Layer › Show or Hide Layer": ShortcutChord("h", 7),
            "\(more):Layer › Distribute › Horizontal Spacing": ShortcutChord("d", 7),
            // Both became Load Selection…: Layer's Pixels' key wins.
            "\(more):Select › Layer's Pixels": ShortcutChord("l", 7),
            "\(more):Select › Mask's Black Areas": ShortcutChord("m", 7),
        ]
        defaults.set(try! JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu("n", modifiers: [.command, .shift]) == ShortcutChord("n", 5), "Layer › New › Layer…")
        #expect(settings.menu("0", modifiers: .command) == ShortcutChord("0", 5), "View › Fit on Screen")
        #expect(settings.assigned("File › Export › Quick Export as PNG") == ShortcutChord("p", 5))
        #expect(settings.assigned("Select › Subject") == ShortcutChord("s", 7))
        #expect(settings.assigned("File › Place Embedded…") == ShortcutChord("i", 5))
        #expect(settings.menu("b", modifiers: .command) == ShortcutChord("c", 7), "Image › Adjustments › Color Balance…")
        #expect(settings.assigned("Filter › Blur › Gaussian Blur…") == ShortcutChord("g", 7))
        #expect(settings.assigned("Layer › Remove Background…") == ShortcutChord("r", 7))
        #expect(settings.menu(";", modifiers: [.command, .shift]) == ShortcutChord("s", 5), "the one View › Snap")
        #expect(settings.menu(",", modifiers: .command) == ShortcutChord("h", 7), "Layer › Hide Layers")
        #expect(settings.assigned("Layer › Distribute › Horizontally") == ShortcutChord("d", 7))
        #expect(settings.assigned("Select › Load Selection…") == ShortcutChord("l", 7))
        let fill = ShortcutDefinition.all.first { $0.title == "Fill with foreground color" }!
        #expect(settings.chord(fill) == ShortcutChord("f", 6), "⌥⌫'s replacement, now a window-wide key")
    }

    /// A key saved under a command's current name wins over one carried over from its old name, and a carried key that
    /// a new default now takes gives way to the default, alone.
    @Test func carriedKeysGiveWayToCurrentOnesAndNewDefaults() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let more = ShortcutDefinition.moreGroup
        let saved = ["\(more):View › Snap": ShortcutChord("s", 5), "Menus:Snap": ShortcutChord("s", 7),
                     // ⇧⌘E, Export PNG's old default saved as a choice of its own, is Merge Visible's now.
                     "Menus:Export PNG": ShortcutChord("e", 9), "Menus:Undo": ShortcutChord("y", 1)]
        defaults.set(try! JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu(";", modifiers: [.command, .shift]) == ShortcutChord("s", 7))
        #expect(settings.assigned("File › Export › Quick Export as PNG").isNone)
        #expect(settings.menu("e", modifiers: [.command, .shift]) == ShortcutChord("e", 9), "Merge Visible keeps ⇧⌘E")
        #expect(settings.menu("z", modifiers: .command) == ShortcutChord("y", 1))
    }

    /// TASK-65: Export JPEG… is gone, its ⌥⇧⌘S free; a key someone gave it moves to Export As…, unless Export As… has
    /// one of its own or the key now belongs to another command.
    @Test func exportJPEGKeysMoveToExportAs() {
        #expect(!ShortcutDefinition.all.contains { $0.title == "Export JPEG" })
        #expect(!ShortcutDefinition.all.contains { $0.original == ShortcutChord("s", 11) }, "⌥⇧⌘S belongs to nothing")
        func settings(_ saved: [String: ShortcutChord]) -> ShortcutSettings {
            let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
            defaults.set(try! JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
            return ShortcutSettings(defaults: defaults)
        }
        let exportAs: (KeyEquivalent, EventModifiers) = ("w", [.command, .option, .shift])
        #expect(settings(["Menus:Export JPEG": ShortcutChord("j", 11)]).menu(exportAs.0, modifiers: exportAs.1) == ShortcutChord("j", 11))
        #expect(settings(["Menus:Export JPEG": ShortcutChord("j", 11), "Menus:Export As": ShortcutChord("x", 11)])
            .menu(exportAs.0, modifiers: exportAs.1) == ShortcutChord("x", 11), "Export As…'s own key wins")
        // ⌘J is Layer Via Copy's: the carried key gives way and Export As… keeps its default.
        let collided = settings(["Menus:Export JPEG": ShortcutChord("j", 1)])
        #expect(collided.menu(exportAs.0, modifiers: exportAs.1) == ShortcutChord("w", 11))
        #expect(collided.menu("j", modifiers: .command) == ShortcutChord("j", 1))
    }

    /// Every old name leads to a command that exists.
    @Test func everyRenamedEntryLeadsToACommand() {
        let known = Set(ShortcutDefinition.all.map(\.id))
        for old in ShortcutSettings.renamedIDs.keys {
            #expect(known.contains(ShortcutSettings.currentID(old)), "\(old)")
            #expect(!known.contains(old), "\(old) is still a command, so its key would be moved away from it")
        }
    }

    @Test func assignableCommandsStartEmptyAndTakeAKey() throws {
        let settings = settings()
        #expect(settings.assigned("Select › Color Range…").isNone)
        let id = "\(ShortcutDefinition.moreGroup):Select › Color Range…"
        settings.save([id: ShortcutChord("k", 5)])
        #expect(settings.assigned("Select › Color Range…") == ShortcutChord("k", 5))
        settings.save([:])
        #expect(settings.assigned("Select › Color Range…").isNone, "Restore Defaults clears it again")
    }

    /// The transform commands moved to the Edit menu: keys people set for them under their old names stay with them.
    /// Show Transform Controls is a Move bar checkbox only now, and ⌘H is View › Extras.
    @Test func movedTransformCommandsKeepTheirCustomKeys() {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let more = ShortcutDefinition.moreGroup
        let saved = ["Menus:Transform Layer / Selection": ShortcutChord("t", 3),
                     "Menus:Show Transform Controls": ShortcutChord("h", 7),
                     "\(more):Layer › Flip Layer Horizontal": ShortcutChord("f", 7),
                     "\(more):Layer › Flip Layer Vertical": ShortcutChord("v", 5)]
        defaults.set(try! JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu("t", modifiers: .command) == ShortcutChord("t", 3), "Edit › Free Transform")
        #expect(settings.assigned("Edit › Transform › Flip Horizontal") == ShortcutChord("f", 7))
        #expect(settings.assigned("Edit › Transform › Flip Vertical") == ShortcutChord("v", 5))
        #expect(settings.assigned("Edit › Transform › Distort").isNone)
        #expect(!settings.overrides.values.contains(ShortcutChord("h", 7)), "a command that's gone keeps no key")
        #expect(!ShortcutDefinition.all.contains { $0.title.contains("Show Transform Controls") })
        #expect(menuDefault("Extras") == ShortcutChord("h", 1))
    }

    @Test func menuShortcutsNeedCommandOptionOrControl() {
        let id = "\(ShortcutDefinition.moreGroup):Select › Color Range…"
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("k", 0)]) != nil, "a plain letter")
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("k", 8)]) != nil, "Shift alone")
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("k", 5)]) == nil)
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("z", 1)]) != nil, "taken by Undo")
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("k", 1)]) != nil, "taken by Settings")
        // Defaults keep working even where they break the rule (Fill… is Shift-F5).
        #expect(ShortcutSettings.problem(in: [:]) == nil)
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord(",", 1)]) != nil, "taken by Hide Layers, no longer macOS's")
        #expect(ShortcutSettings.problem(in: [id: ShortcutChord("q", 1)]) != nil, "reserved by macOS")
    }

    @Test func sheetListsEveryGroup() {
        #expect(KeyboardShortcutsSheet.groups == ["Menus", ShortcutDefinition.moreGroup, "Canvas & Layers", "Text Editing"])
        let grouped = Set(KeyboardShortcutsSheet.groups)
        #expect(ShortcutDefinition.all.allSatisfy { grouped.contains($0.group) }, "no definition is left out of the sheet")
    }

    /// ⌥⌫ and ⌘⌫ fill without menu items, so a key the person gives them instead reaches the canvas's key monitor as
    /// the Delete key it stands for, and the Delete key itself then does nothing.
    @Test func fillKeysTakeCustomShortcutsWithoutMenuItems() throws {
        let settings = settings()
        let fill = try #require(ShortcutDefinition.all.first { $0.title == "Fill with foreground color" })
        settings.save([fill.id: ShortcutChord("f", 6)])
        let translated = try #require(settings.canvasEvent(key("f", code: 3, [.control, .option])))
        #expect(translated.keyCode == 51 && translated.modifierFlags.intersection([.command, .control, .option, .shift]) == .option)
        #expect(settings.canvasEvent(key("\u{7f}", code: 51, .option)) == nil)
        // SwiftUI's `.delete` (U+0008) is the Delete key the list records as U+007F.
        #expect(ShortcutChord("\u{7f}", 2).keyboardShortcut == KeyboardShortcut(.delete, modifiers: .option))
    }

    /// An override saved by an older version that a newer rule refuses (a plain letter on a menu command, or a key a
    /// new default now takes) is dropped on its own; the person's other shortcuts survive the update.
    @Test func anOverrideTheRulesNowRefuseDropsAloneOnLoad() throws {
        let defaults = UserDefaults(suiteName: "KeyboardShortcutTests-\(UUID().uuidString)")!
        let saved = ["Menus:Curves": ShortcutChord("k", 0), "Menus:Undo": ShortcutChord("y", 1)]
        defaults.set(try JSONEncoder().encode(saved), forKey: "keyboardShortcuts.v1")
        let settings = ShortcutSettings(defaults: defaults)
        #expect(settings.menu("z", modifiers: .command) == ShortcutChord("y", 1), "the valid override survives")
        #expect(settings.menu("m", modifiers: .command) == ShortcutChord("m", 1), "the refused one falls back to its default")
    }

    /// A key that types nothing (a dead key on some layouts) reads as no key at all; it must not be taken for a
    /// command whose shortcut was cleared.
    @Test func aKeyWithNoCharactersIsNotAClearedCommand() throws {
        let settings = settings()
        let brush = try #require(ShortcutDefinition.all.first { $0.title == "Brush tool" })
        settings.save([brush.id: .unassigned])
        let dead = key("", code: 33)
        #expect(settings.canvasEvent(dead)?.charactersIgnoringModifiers == "", "passed on as it was, not turned into B")
        #expect(settings.textEvent(dead)?.charactersIgnoringModifiers == "")
    }

    /// ⊗ in the sheet must record "no key", not drop the row's entry (which would bring the default back).
    @Test func clearingInTheSheetRecordsNoKey() throws {
        let undo = try #require(ShortcutDefinition.all.first { $0.isMenu && $0.title == "Undo" })
        let draft = KeyboardShortcutsSheet.clearing(undo.id, in: [:])
        #expect(draft[undo.id]?.isNone == true)
        let settings = settings()
        settings.save(draft)
        #expect(settings.menu("z", modifiers: .command).isNone)
    }
}
