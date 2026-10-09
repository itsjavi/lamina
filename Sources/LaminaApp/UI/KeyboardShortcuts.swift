import AppKit
import SwiftUI
import LaminaCore

struct ShortcutChord: Codable, Equatable, Hashable {
    var key: String
    var modifiers: Int
    init(_ key: String, _ modifiers: Int = 0) { self.key = key; self.modifiers = modifiers }
    /// No key at all: a command the person has cleared, or one that ships without a shortcut.
    static let unassigned = ShortcutChord("", 0)
    var isNone: Bool { key.isEmpty }
    /// What SwiftUI applies to a menu item or button: nil takes any key equivalent away.
    var keyboardShortcut: KeyboardShortcut? {
        // The list records Delete as U+007F, as NSEvent reports it; SwiftUI's Delete key equivalent is U+0008.
        key.first.map { KeyboardShortcut($0 == "\u{7f}" ? .delete : KeyEquivalent($0), modifiers: eventModifiers) }
    }
    /// A key equivalent as the list records it: SwiftUI's `.delete` (U+0008) is the Delete key, recorded as U+007F.
    static func recorded(_ key: KeyEquivalent) -> String {
        key == .delete ? "\u{7f}" : String(key.character)
    }
    // Stable stored bits: Command, Option, Control, Shift.
    init(_ event: NSEvent) {
        let flags = event.modifierFlags
        modifiers = (flags.contains(.command) ? 1 : 0) | (flags.contains(.option) ? 2 : 0)
            | (flags.contains(.control) ? 4 : 0) | (flags.contains(.shift) ? 8 : 0)
        switch event.keyCode {
        case 51, 117: key = "\u{7f}"
        case 36, 76: key = "\r"
        case 53: key = "\u{1b}"
        case 48: key = "\t"
        case 49: key = " "
        case 123: key = "\u{f702}"
        case 124: key = "\u{f703}"
        case 125: key = "\u{f701}"
        case 126: key = "\u{f700}"
        default:
            let typed = event.charactersIgnoringModifiers?.lowercased() ?? ""
            key = ["{": "[", "}": "]", "+": "=", "_": "-" ][typed] ?? typed
        }
    }
    var eventModifiers: EventModifiers {
        var flags: EventModifiers = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }
    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.option) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }
    /// F1 to F12 as key equivalents: NSEvent's function-key characters, U+F704 to U+F70F.
    static func functionKey(_ number: Int) -> String { String(UnicodeScalar(0xF703 + UInt32(number))!) }
    private static let functionKeyCodes: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
    var label: String {
        if isNone { return "None" }
        let special = ["\u{7f}": "Delete", "\r": "Return", "\u{1b}": "Esc", "\t": "Tab", " ": "Space",
                       "\u{f702}": "←", "\u{f703}": "→", "\u{f701}": "↓", "\u{f700}": "↑"]
        let function = key.unicodeScalars.first.flatMap { (0xF704...0xF70F).contains($0.value) ? "F\($0.value - 0xF703)" : nil }
        return (modifiers & 4 != 0 ? "⌃" : "") + (modifiers & 2 != 0 ? "⌥" : "")
            + (modifiers & 8 != 0 ? "⇧" : "") + (modifiers & 1 != 0 ? "⌘" : "")
            + (special[key] ?? function ?? key.uppercased())
    }
    func event(like event: NSEvent) -> NSEvent? {
        var codes: [String: UInt16] = ["\u{7f}": 51, "\r": 36, "\u{1b}": 53, "\t": 48, " ": 49,
                                       "\u{f702}": 123, "\u{f703}": 124, "\u{f701}": 125, "\u{f700}": 126,
                                       "=": 24, "-": 27]
        for (index, code) in Self.functionKeyCodes.enumerated() { codes[Self.functionKey(index + 1)] = code }
        let shifted = modifiers & 8 != 0 ? (["[": "{", "]": "}", "=": "+", "-": "_"][key] ?? key) : key
        return NSEvent.keyEvent(with: event.type, location: event.locationInWindow, modifierFlags: cocoaModifiers,
            timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil,
            characters: shifted, charactersIgnoringModifiers: shifted, isARepeat: event.isARepeat,
            keyCode: codes[key] ?? 0xffff)
    }
}

struct ShortcutDefinition: Identifiable {
    let title: String
    let group: String
    let original: ShortcutChord
    var id: String { "\(group):\(title)" }
    var isMenu: Bool { group == "Menus" }

    /// Menu commands that ship without a key; the person can give them one.
    static let moreGroup = "More Menu Commands"

    /// Their titles, "Menu › Item" as the menu bar shows them. Keep in step with LaminaMain: in a Debug build a
    /// menu item asking for a title that isn't here stops with a message saying so.
    static let assignableMenuCommands: [String] = {
        var titles = [
            "Lamina › Check for Updates…", "Lamina › Show All",
            "File › Open Recent › Clear Recent File List", "File › Export › Quick Export as PNG", "File › Place Embedded…",
            "Edit › Clear", "Edit › Stroke…", "Edit › Content-Aware Fill…",
            "Edit › Transform › Distort", "Edit › Transform › Flip Horizontal", "Edit › Transform › Flip Vertical",
            "Image › Adjustments › Exposure…", "Image › Adjustments › Gradient Map…", "Image › Adjustments › Grain…",
            "Image › Mode › RGB Color", "Image › Mode › 8 Bits/Channel",
            "Image › Image Rotation › Flip Canvas Horizontal", "Image › Image Rotation › Flip Canvas Vertical", "Image › Trim…",
            "Layer › New › Group…", "Layer › New › Group from Layers…", "Layer › Duplicate Layer…", "Layer › Delete › Layer",
            "Layer › Rename Layer…",
            "Layer › Layer Style › Copy Layer Style", "Layer › Layer Style › Paste Layer Style",
            "Layer › Layer Style › Clear Layer Style",
            "Layer › Layer Content Options…",
            "Layer › Layer Mask › Reveal All", "Layer › Layer Mask › Hide All", "Layer › Layer Mask › Reveal Selection",
            "Layer › Layer Mask › Hide Selection", "Layer › Layer Mask › Delete", "Layer › Layer Mask › Apply",
            "Layer › Remove Background…", "Layer › Hide All Other Layers", "Layer › Arrange › Move Out of Group",
            "Layer › Flatten Image",
            "Type › Panels › Character", "Type › Panels › Paragraph",
            "Select › Color Range…", "Select › Subject", "Select › Modify › Expand…", "Select › Modify › Contract…",
            "Select › Load Selection…",
            "View › Screen Mode › Standard Screen Mode", "View › Show › Pixel Grid",
            "View › Snap To › Guides", "View › Snap To › Grid", "View › Snap To › Layers", "View › Snap To › Document Bounds",
            "View › Guides › Clear Guides", "View › Grid Settings…", "View › Enter Full Screen",
            "Window › Minimize", "Window › Zoom",
            "Window › Workspace › Essentials (Default)", "Window › Workspace › Reset Essentials",
            "Help › Features in Progress…",
        ]
        titles += DockPanel.windowMenuOrder.map { "Window › \($0.title)" }
        titles += CanvasRotation.allCases.map { "Image › Image Rotation › \($0.rawValue)" }
        titles += LayerAlignment.allCases.map { "Layer › Align › \($0.rawValue)" }
        titles += LayerDistribution.allCases.map { "Layer › Distribute › \($0.menuTitle)" }
        titles += FilterKind.filterMenu.flatMap { submenu in submenu.kinds.compactMap { $0 }.map { "Filter › \(submenu.title) › \($0.rawValue)…" } }
        titles += AdjustmentKind.allCases.map { "Layer › New Adjustment Layer › \($0.rawValue)" }
        titles += PlannedFeature.assignableMenuCommands
        titles += LayerStylePage.all.map { "Layer › Layer Style › \($0.title)…" }
        return titles
    }()

    static let all: [ShortcutDefinition] = {
        func entry(_ title: String, _ key: String, _ modifiers: Int = 0, menu: Bool = false) -> ShortcutDefinition {
            .init(title: title, group: menu ? "Menus" : "Canvas & Layers", original: ShortcutChord(key, modifiers))
        }
        // Modifier bits: 1 Command, 2 Option, 4 Control, 8 Shift.
        var result: [ShortcutDefinition] = [
            entry("Settings", "k", 1, menu: true), entry("Hide Lamina", "h", 5, menu: true), entry("Hide Others", "h", 3, menu: true),
            entry("New", "n", 1, menu: true), entry("New from Clipboard", "n", 3, menu: true), entry("Open", "o", 1, menu: true),
            entry("Close", "w", 1, menu: true),
            entry("Save", "s", 1, menu: true), entry("Save As", "s", 9, menu: true), entry("Save a Copy", "s", 3, menu: true),
            entry("Export As", "w", 11, menu: true),
            entry("Undo", "z", 1, menu: true), entry("Redo", "z", 9, menu: true),
            entry("Cut", "x", 1, menu: true), entry("Copy", "c", 1, menu: true), entry("Copy Merged", "c", 9, menu: true),
            entry("Paste", "v", 1, menu: true), entry("Search", "f", 1, menu: true),
            entry("Fill", ShortcutChord.functionKey(5), 8, menu: true),
            entry("Free Transform", "t", 1, menu: true), entry("Keyboard Shortcuts", "k", 11, menu: true),
            entry("Levels", "l", 1, menu: true), entry("Curves", "m", 1, menu: true), entry("Hue/Saturation", "u", 1, menu: true),
            entry("Color Balance", "b", 1, menu: true), entry("Black & White", "b", 11, menu: true),
            entry("Invert", "i", 1, menu: true),
            entry("Image Size", "i", 3, menu: true), entry("Canvas Size", "c", 3, menu: true),
            entry("New Layer", "n", 9, menu: true), entry("Layer Via Copy", "j", 1, menu: true),
            entry("Toggle Clipping Mask", "g", 3, menu: true), entry("Group Layers", "g", 1, menu: true),
            entry("Ungroup Layers", "g", 9, menu: true), entry("Hide Layers", ",", 1, menu: true),
            entry("Bring Forward", "]", 1, menu: true), entry("Send Backward", "[", 1, menu: true),
            entry("Lock Layers", "/", 1, menu: true),
            entry("Merge Down", "e", 1, menu: true), entry("Merge Visible", "e", 9, menu: true),
            entry("Select All", "a", 1, menu: true), entry("Deselect", "d", 1, menu: true),
            entry("Inverse Selection", "i", 9, menu: true), entry("Feather", ShortcutChord.functionKey(6), 8, menu: true),
            entry("Last Filter", "f", 5, menu: true), entry("Camera Raw Filter", "a", 9, menu: true),
            entry("Lens Correction", "r", 9, menu: true), entry("Liquify", "x", 9, menu: true),
            entry("Proof Colors", "y", 1, menu: true), entry("Gamut Warning", "y", 9, menu: true),
            entry("Zoom In", "=", 1, menu: true), entry("Zoom Out", "-", 1, menu: true),
            entry("Fit on Screen", "0", 1, menu: true), entry("100%", "1", 1, menu: true),
            entry("Extras", "h", 1, menu: true), entry("Show Grid", "'", 1, menu: true), entry("Show Guides", ";", 1, menu: true),
            entry("Show Rulers", "r", 1, menu: true), entry("Snap", ";", 9, menu: true), entry("Lock Guides", ";", 3, menu: true),
        ]
        // Fill straight from the swatches, and Fill…'s second key: no menu items of their own, window-wide outside text
        // fields (`CanvasView`'s key monitor).
        result += [entry("Fill with foreground color", "\u{7f}", 2), entry("Fill with background color", "\u{7f}", 1),
                   entry("Fill… (second shortcut)", "\u{7f}", 8)]
        for (title, key) in [("Select tool", "a"), ("Move / Transform tool", "v"), ("Hand tool", "h"),
            ("Zoom tool", "z"), ("Brush tool", "b"), ("Eraser", "e"), ("Spot Healing", "j"),
            ("Clone Stamp", "s"), ("Type tool", "t"), ("Gradient / Paint Bucket", "g"), ("Shape tool", "u"),
            ("Eyedropper tool", "i"), ("Rectangular / Elliptical Marquee", "m"), ("Object Selection / Magic Wand", "w"),
            ("Lasso / Polygonal Lasso", "l"), ("Blur / Smudge", "r"), ("Dodge / Burn", "o"), ("Crop tool", "c"),
            ("Pen tool", "p"),
            ("Swap foreground/background", "x"), ("Reset colors", "d"),
            ("Temporary Hand tool (hold)", " "), ("Delete selection / layer / effect / lasso point", "\u{7f}"),
            ("Apply current canvas operation", "\r"), ("Cancel current canvas operation", "\u{1b}"),
            ("Decrease brush size", "["), ("Increase brush size", "]")] {
            result.append(entry(title, key))
        }
        // Photoshop's screen-mode and panel keys, for screen modes and hiding the panels (in progress, TASK-78).
        result += [entry("Next screen mode", "f"), entry("Previous screen mode", "f", 8),
                   entry("Show or hide panels", "\t"), entry("Show or hide panels but the toolbar", "\t", 8)]
        // Photoshop's / toggles the lock last chosen in the Layers panel, Lock transparent pixels at first.
        result.append(entry("Toggle the last layer lock", "/"))
        result += [entry("Decrease brush hardness", "[", 8), entry("Increase brush hardness", "]", 8),
                   entry("Previous blend mode", "-", 8), entry("Next blend mode", "=", 8)]
        // Shift and the key of a slot with several tools: the slot's next tool (`EditorSession.pressToolKey`).
        for (title, key) in [("Next marquee tool", "m"), ("Next lasso tool", "l"), ("Next Object Selection / Magic Wand", "w"),
            ("Next Gradient / Paint Bucket", "g"), ("Next Blur / Smudge", "r"), ("Next Dodge / Burn", "o"), ("Next shape tool", "u"),
            ("Next brush tool", "b"), ("Next crop tool", "c")] {
            result.append(entry(title, key, 8))
        }
        for digit in 0...9 { result.append(entry("Opacity digit \(digit) (type two for exact %)", String(digit))) }
        for (direction, key) in [("Left", "\u{f702}"), ("Right", "\u{f703}"), ("Up", "\u{f700}"), ("Down", "\u{f701}")] {
            result += [entry("Nudge \(direction) 1 px", key), entry("Nudge \(direction) 10 px", key, 8),
                       entry("Move selected pixels \(direction) 1 px", key, 1), entry("Move selected pixels \(direction) 10 px", key, 9)]
        }
        result.append(.init(title: "Finish editing text", group: "Text Editing", original: ShortcutChord("\r", 1)))
        for (title, key) in [("Decrease tracking", "\u{f702}"), ("Increase tracking", "\u{f703}"),
                             ("Decrease leading", "\u{f700}"), ("Increase leading", "\u{f701}")] {
            result.append(.init(title: title, group: "Text Editing", original: ShortcutChord(key, 2)))
            result.append(.init(title: title + " by 10", group: "Text Editing", original: ShortcutChord(key, 10)))
        }
        result.append(entry("Toggle Levels preview", "p", 2))
        result += assignableMenuCommands.map { .init(title: $0, group: moreGroup, original: .unassigned) }
        return result
    }()
}

@MainActor @Observable
final class ShortcutSettings {
    static let shared = ShortcutSettings()
    private(set) var overrides: [String: ShortcutChord] = [:]
    @ObservationIgnored private let panel = FloatingPanelController(name: "keyboardShortcuts")
    private static let storageKey = "keyboardShortcuts.v1"
    /// One saved entry, nil when it can't be decoded (a hand-edited or damaged value), so the others still load.
    private struct SavedChord: Decodable {
        let chord: ShortcutChord?
        init(from decoder: Decoder) throws { chord = try? ShortcutChord(from: decoder) }
    }
    /// Entries renamed or moved since earlier versions saved them (the tools split apart, the transform commands moved
    /// to the Edit menu, the menus took their familiar names and places): a key set for the old name carries over. An
    /// old name may lead to another old name; `currentID(_:)` follows the chain.
    static let renamedIDs: [String: String] = {
        let more = ShortcutDefinition.moreGroup
        var renamed = [
            "Menus:Transform Layer / Selection": "Menus:Free Transform",
            "\(more):Layer › Flip Layer Horizontal": "\(more):Edit › Transform › Flip Horizontal",
            "\(more):Layer › Flip Layer Vertical": "\(more):Edit › Transform › Flip Vertical",
            "Canvas & Layers:Marquee / cycle shape": "Canvas & Layers:Rectangular / Elliptical Marquee",
            "Canvas & Layers:Magic": "Canvas & Layers:Object Selection / Magic Wand",
            "Canvas & Layers:Lasso / cycle mode": "Canvas & Layers:Lasso / Polygonal Lasso",
            "Canvas & Layers:Blur / Smudge / Liquify": "Canvas & Layers:Blur / Smudge",
            "Canvas & Layers:Cycle shape kind": "Canvas & Layers:Next shape tool",
            "Canvas & Layers:Switch Gradient / Paint Bucket": "Canvas & Layers:Next Gradient / Paint Bucket",
            // TASK-62: the menus in their familiar structure (docs/DESIGN.md, Menus and Shortcut changes).
            "Menus:New Canvas": "Menus:New", "Menus:Open Project": "Menus:Open", "Menus:Close Project": "Menus:Close",
            "Menus:Export PNG": "\(more):File › Export › Quick Export as PNG",
            "\(more):File › Export As…": "Menus:Export As",
            // TASK-65: Export JPEG… became Export As…'s JPEG format; a key set for it carries over unless it collides.
            "Menus:Export JPEG": "Menus:Export As",
            "\(more):File › Open Recent › Clear Menu": "\(more):File › Open Recent › Clear Recent File List",
            "\(more):File › Import Images…": "\(more):File › Place Embedded…",
            "\(more):Lamina › Hide Lamina": "Menus:Hide Lamina",
            "\(more):Edit › Keyboard Shortcuts…": "Menus:Keyboard Shortcuts",
            "\(more):Edit › Clear Selection Pixels": "\(more):Edit › Clear",
            "Menus:Content-Aware Fill": "\(more):Edit › Content-Aware Fill…",
            "Menus:Fill with Foreground": "Canvas & Layers:Fill with foreground color",
            "Menus:Fill with Background": "Canvas & Layers:Fill with background color",
            "Menus:Fit Canvas": "Menus:Fit on Screen", "Menus:Actual Pixels": "Menus:100%",
            "\(more):View › Pixel Grid": "\(more):View › Show › Pixel Grid",
            "\(more):View › Snap": "Menus:Snap",
            "\(more):View › Clear Guides": "\(more):View › Guides › Clear Guides",
            "Menus:Select Subject": "\(more):Select › Subject",
            "\(more):Select › Expand…": "\(more):Select › Modify › Expand…",
            "\(more):Select › Contract…": "\(more):Select › Modify › Contract…",
            "\(more):Select › Feather…": "Menus:Feather",
            // Load Selection… does what both did; Layer's Pixels' key wins if both had one (`init`).
            "\(more):Select › Layer's Pixels": "\(more):Select › Load Selection…",
            "\(more):Select › Mask's Black Areas": "\(more):Select › Load Selection…",
            "Menus:Invert Pixels / Mask": "Menus:Invert",
            "\(more):Image › Color Balance…": "Menus:Color Balance", "\(more):Image › Black & White…": "Menus:Black & White",
            "\(more):Image › Exposure…": "\(more):Image › Adjustments › Exposure…",
            "\(more):Image › Gradient Map…": "\(more):Image › Adjustments › Gradient Map…",
            "\(more):Image › Grain…": "\(more):Image › Adjustments › Grain…",
            "\(more):Image › Flip Canvas Horizontal": "\(more):Image › Image Rotation › Flip Canvas Horizontal",
            "\(more):Image › Flip Canvas Vertical": "\(more):Image › Image Rotation › Flip Canvas Vertical",
            "Menus:New Blank Layer": "Menus:New Layer", "Menus:Duplicate / Layer via Copy": "Menus:Layer Via Copy",
            "Menus:Move Layer Up": "Menus:Bring Forward", "Menus:Move Layer Down": "Menus:Send Backward",
            "Menus:Merge Layers": "Menus:Merge Down",
            "\(more):Layer › Merge Visible": "Menus:Merge Visible",
            "\(more):Layer › Show or Hide Layer": "Menus:Hide Layers",
            "\(more):Layer › Show or Hide All Other Layers": "\(more):Layer › Hide All Other Layers",
            "\(more):Layer › Move Out of Folder": "\(more):Layer › Arrange › Move Out of Group",
            "\(more):Layer › Edit Adjustment…": "\(more):Layer › Layer Content Options…",
            "\(more):Layer › Apply Layer Mask": "\(more):Layer › Layer Mask › Apply",
            "\(more):Layer › Delete Layer": "\(more):Layer › Delete › Layer",
            "\(more):Layer › Distribute › Horizontal Spacing": "\(more):Layer › Distribute › Horizontally",
            "\(more):Layer › Distribute › Vertical Spacing": "\(more):Layer › Distribute › Vertically",
            "\(more):Filter › Remove Background…": "\(more):Layer › Remove Background…",
            "\(more):Filter › Camera Raw Filter…": "Menus:Camera Raw Filter",
            "\(more):Filter › Lens Correction…": "Menus:Lens Correction",
        ]
        // Each filter moved into its category's submenu.
        for submenu in FilterKind.filterMenu {
            for kind in submenu.kinds.compactMap({ $0 }) {
                renamed["\(more):Filter › \(kind.rawValue)…"] = "\(more):Filter › \(submenu.title) › \(kind.rawValue)…"
            }
        }
        return renamed
    }()
    /// Where a key saved under `id` belongs now: `id` itself, or the name its command goes by today.
    static func currentID(_ id: String) -> String {
        var current = id
        // Bounded, so a mistaken loop in the table can't hang the launch.
        for _ in 0..<8 { guard let next = renamedIDs[current] else { break }; current = next }
        return current
    }
    private let defaults: UserDefaults
    /// `defaults` is the app's own everywhere but tests, which use a throwaway suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([String: SavedChord].self, from: data) else { return }
        // Take the saved overrides one at a time, keeping each that still fits: one that can't be read, one for a
        // command that has since gone, or one a newer rule or a new default now refuses, drops alone rather than
        // taking every other saved shortcut with it.
        let known = Set(ShortcutDefinition.all.map(\.id))
        // A key saved under a command's current name wins over one carried over from an old name; among old names
        // the first in order does, so the outcome never depends on how the saved dictionary happens to be ordered.
        var chords: [String: ShortcutChord] = [:]
        for (id, chord) in saved.compactMapValues(\.chord).sorted(by: { $0.key < $1.key }) {
            let current = Self.currentID(id)
            if current == id || chords[current] == nil { chords[current] = chord }
        }
        var accepted: [String: ShortcutChord] = [:]
        for (id, chord) in chords.sorted(by: { $0.key < $1.key }) where known.contains(id) {
            var trial = accepted
            trial[id] = chord
            if Self.problem(in: trial) == nil { accepted = trial }
        }
        overrides = accepted
    }
    func chord(_ definition: ShortcutDefinition) -> ShortcutChord { overrides[definition.id] ?? definition.original }
    func menu(_ key: KeyEquivalent, modifiers: EventModifiers) -> ShortcutChord {
        let bits = (modifiers.contains(.command) ? 1 : 0) | (modifiers.contains(.option) ? 2 : 0)
            | (modifiers.contains(.control) ? 4 : 0) | (modifiers.contains(.shift) ? 8 : 0)
        let original = ShortcutChord(ShortcutChord.recorded(key), bits)
        guard let definition = ShortcutDefinition.all.first(where: { $0.isMenu && $0.original == original }) else {
            assertionFailure("\(original.label) is used in a menu but isn't in ShortcutDefinition.all, so Keyboard Shortcuts can't show or change it.")
            return original
        }
        return chord(definition)
    }
    /// The key the person gave a menu command that ships without one; `.unassigned` until they do.
    func assigned(_ title: String) -> ShortcutChord {
        guard let definition = ShortcutDefinition.all.first(where: { $0.group == ShortcutDefinition.moreGroup && $0.title == title }) else {
            assertionFailure("“\(title)” isn't in ShortcutDefinition.assignableMenuCommands. Add it there so it appears in Keyboard Shortcuts.")
            return .unassigned
        }
        return chord(definition)
    }
    func native(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> ShortcutChord {
        let bits = (modifiers.contains(.command) ? 1 : 0) | (modifiers.contains(.option) ? 2 : 0)
            | (modifiers.contains(.control) ? 4 : 0) | (modifiers.contains(.shift) ? 8 : 0)
        let original = ShortcutChord(ShortcutChord.recorded(key), bits)
        guard let definition = ShortcutDefinition.all.first(where: { !$0.isMenu && $0.original == original }) else { return original }
        return chord(definition)
    }
    func show() {
        panel.show(title: "Keyboard Shortcuts", content: KeyboardShortcutsSheet(settings: self))
    }
    func close() { panel.close() }
    func save(_ values: [String: ShortcutChord]) {
        guard Self.problem(in: values) == nil, let data = try? JSONEncoder().encode(values) else { return }
        overrides = values
        defaults.set(data, forKey: Self.storageKey)
        close()
    }
    static func problem(in values: [String: ShortcutChord]) -> String? {
        var assigned: [ShortcutChord: String] = [:]
        for definition in ShortcutDefinition.all {
            let chord = values[definition.id] ?? definition.original
            if chord.isNone { continue }
            guard chord.key.count == 1, (0...15).contains(chord.modifiers) else { return "Choose a single key with optional modifiers." }
            if definition.group == "Text Editing", chord.modifiers & 7 == 0 {
                return "Text-editing shortcuts need Command, Option, or Control so they do not replace normal typing."
            }
            // A menu key without Command, Option or Control would take that key from every text field. Defaults are
            // exempt (Fill… is Shift-F5, as in Photoshop); only keys the person picks must follow it.
            if definition.isMenu || definition.group == ShortcutDefinition.moreGroup,
               let chosen = values[definition.id], chosen != definition.original, chosen.modifiers & 7 == 0 {
                return "Menu shortcuts need Command, Option, or Control, so they don't take keys you type."
            }
            // ⌘, is free: Settings… is ⌘K, and ⌘, hides layers, as in Photoshop.
            if [ShortcutChord("q", 1), ShortcutChord("m", 3)].contains(chord) {
                return "\(chord.label) is reserved by macOS."
            }
            if let other = assigned[chord] { return "\(chord.label) is assigned to both \(other) and \(definition.title)." }
            assigned[chord] = definition.title
        }
        return nil
    }

    /// Translate only at the existing canvas/layer responder boundary. Native text
    /// fields and dialog controls retain their normal typing and navigation behavior.
    func canvasEvent(_ event: NSEvent) -> NSEvent? {
        let input = ShortcutChord(event)
        // A key that types nothing (a dead key on some layouts) reads as no key, which a cleared command also is.
        guard !overrides.isEmpty, !input.isNone else { return event }
        if let definition = ShortcutDefinition.all.first(where: { $0.group == "Canvas & Layers" && chord($0) == input }) {
            return definition.original == input ? event : definition.original.event(like: event)
        }
        if ShortcutDefinition.all.contains(where: { $0.group != "Text Editing" && $0.original == input && chord($0) != input }) { return nil }
        // Letter tool shortcuts traditionally also accept Shift. Follow the base
        // assignment unless Shift has its own explicit command (e.g. cycle shape).
        if input.modifiers == 8 {
            let plain = ShortcutChord(input.key)
            if let definition = ShortcutDefinition.all.first(where: { !$0.isMenu && $0.original.modifiers == 0 && chord($0) == plain }) {
                return ShortcutChord(definition.original.key, 8).event(like: event)
            }
            if ShortcutDefinition.all.contains(where: { !$0.isMenu && $0.original == plain && chord($0) != plain }) { return nil }
        }
        return event
    }

    func textEvent(_ event: NSEvent) -> NSEvent? {
        let input = ShortcutChord(event)
        guard !overrides.isEmpty, !input.isNone else { return event }
        let definitions = ShortcutDefinition.all.filter { $0.group == "Text Editing" || $0.original == ShortcutChord("\u{1b}") }
        if let definition = definitions.first(where: { chord($0) == input }) {
            return definition.original == input ? event : definition.original.event(like: event)
        }
        if definitions.contains(where: { $0.original == input && chord($0) != input }) { return nil }
        return event
    }
}

extension View {
    func configuredNativeShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> some View {
        keyboardShortcut(ShortcutSettings.shared.native(key, modifiers: modifiers).keyboardShortcut)
    }
    func configuredKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View {
        keyboardShortcut(ShortcutSettings.shared.menu(key, modifiers: modifiers).keyboardShortcut)
    }
    /// For menu items without a default key: applies the one the person assigned in Keyboard Shortcuts, if any.
    func assignableShortcut(_ title: String) -> some View {
        keyboardShortcut(ShortcutSettings.shared.assigned(title).keyboardShortcut)
    }
}

struct KeyboardShortcutsSheet: View {
    /// The sections, in order. Every definition's group must be one of them (a test checks).
    static let groups = ["Menus", ShortcutDefinition.moreGroup, "Canvas & Layers", "Text Editing"]
    /// The draft with `id` set to no key: what ⊗ does.
    static func clearing(_ id: String, in draft: [String: ShortcutChord]) -> [String: ShortcutChord] {
        var draft = draft
        draft[id] = .unassigned
        return draft
    }
    let settings: ShortcutSettings
    @State private var draft: [String: ShortcutChord]
    @State private var search = ""
    @State private var recording: String?
    init(settings: ShortcutSettings) { self.settings = settings; _draft = State(initialValue: settings.overrides) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Click a shortcut, then press its new key combination; ⊗ removes it. Changes apply when you save.")
                .foregroundStyle(.secondary)
            TextField("Search shortcuts", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Self.groups, id: \.self) { group in
                        Text(group).font(.headline).padding(.top, 8)
                        ForEach(ShortcutDefinition.all.filter { $0.group == group && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) }) { definition in
                            HStack {
                                Text(definition.title)
                                Spacer()
                                ShortcutRecorder(chord: draft[definition.id] ?? definition.original,
                                    recording: recording == definition.id,
                                    start: { recording = definition.id },
                                    finish: { chord in
                                        if let chord { draft[definition.id] = chord }
                                        recording = nil
                                    })
                                    .frame(width: 150, height: 26)
                                // Clearing frees the key for another command; Restore Defaults brings it back.
                                Button {
                                    recording = nil
                                    draft = Self.clearing(definition.id, in: draft)
                                } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                                    .help("No shortcut")
                                    .accessibilityLabel("Remove the shortcut for \(definition.title)")
                                    .disabled((draft[definition.id] ?? definition.original).isNone)
                            }
                        }
                    }
                    Divider().padding(.vertical, 8)
                    Text("Contextual keys & mouse gestures").font(.headline)
                    Text("Text fields keep standard macOS editing keys. Dialogs share the Apply/Cancel assignments above. Numeric fields use Up/Down, with Shift for larger steps. ⌘Q quits; the window's green button enters full screen. The shortcut editor itself always uses Return to save and Esc to cancel when not recording.")
                    Text("Option temporarily selects the eyedropper in painting tools. Shift constrains shapes/movement or adds to a selection; Option subtracts from selections or draws from center. Command-drag moves selected pixels; Command-Option-drag copies them. Option-drag duplicates layers/groups/effects; Option-click at a layer boundary toggles clipping. Command-click a thumbnail loads its selection. Control bypasses snapping. Right-drag adjusts brush size. Modifier-and-mouse gestures are fixed.")
                }.padding(.trailing, 8)
            }.frame(height: 465)
            // Only a conflict takes room here; an empty line left a wide gap above the buttons.
            if let problem = ShortcutSettings.problem(in: draft) {
                Text(problem)
                    .foregroundStyle(.orange).font(.callout).lineLimit(2)
                    .frame(height: 22, alignment: .topLeading)
            }
            Divider()
            HStack {
                Button("Restore Defaults") { recording = nil; draft = [:] }
                Spacer()
                Button("Cancel") { settings.close() }.keyboardShortcut(.cancelAction)
                Button("Save") { settings.save(draft) }.keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(recording != nil || ShortcutSettings.problem(in: draft) != nil)
            }
        }.padding(24).frame(width: 660).fixedSize()
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let chord: ShortcutChord
    let recording: Bool
    let start: () -> Void
    let finish: (ShortcutChord?) -> Void
    func makeNSView(context: Context) -> RecorderButton { RecorderButton() }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.start = start; button.finish = finish; button.recording = recording
        button.title = recording ? "Press keys…" : chord.label
        button.setAccessibilityLabel(recording ? "Press a shortcut" : chord.label)
        if recording, button.window?.firstResponder !== button { button.window?.makeFirstResponder(button) }
    }
    final class RecorderButton: NSButton {
        var start: (() -> Void)?
        var finish: ((ShortcutChord?) -> Void)?
        var recording = false
        override var acceptsFirstResponder: Bool { true }
        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded; target = self; action = #selector(beginRecording)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func beginRecording() { window?.makeFirstResponder(self); recording = true; start?() }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard recording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
            keyDown(with: event); return true
        }
        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            let chord = ShortcutChord(event)
            guard chord.key.count == 1 else { NSSound.beep(); return }
            recording = false
            finish?(chord)
            window?.makeFirstResponder(nil)
        }
    }
}
