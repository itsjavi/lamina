import AppKit

/// A feature with an open Backlog task, shown where it will live (docs/DESIGN.md, In-progress placeholders). Using its
/// control shows "<name> is in progress" (`EditorSession.showInProgress`) and nothing else. When the task ships, the
/// real control replaces the placeholder and its case goes; when a task is dropped, so does its case.
enum PlannedFeature: String, CaseIterable, Identifiable {
    case penTool, pathSelectionTool, directSelectionTool
    case mixerBrushTool, paletteKnifeTool
    case polygonTool, starTool
    case flatBristle, roundBristle, fanBristle, dryBrush
    case shapeStroke, strokeOptions, pathOperations
    case saveACopy
    case rasterize, convertToEditableVectors
    case uniteShapes, subtractFrontShape, uniteShapesAtOverlap, subtractShapesAtOverlap, releaseToLayers
    case contextualTaskBar
    case fullScreenModeWithMenuBar, fullScreenMode, hidePanels
    case search
    case navigator
    case pencilTool
    case perspectiveCropTool
    case fillOpacity
    case colorLookup
    case effectBlendMode, spread, choke, centerStroke
    case twoColumnToolbar
    case customizeToolbar
    case proofSetup, proofColors, gamutWarning
    case sixteenBitsPerChannel, thirtyTwoBitsPerChannel
    case lockTransparentPixels

    /// Where its control lives.
    enum Home: Equatable {
        /// A toolbar slot's flyout (`ToolSlot.items`).
        case toolbar
        /// A menu item, by its path as Keyboard Shortcuts lists it ("Layer › Rasterize").
        case menu(String)
        /// A control in these tools' options bars.
        case optionsBar([NavigationTool])
        /// A control in this panel or dialog ("Layers", "Layer Style", "Toolbar").
        case panel(String)
        /// A key on the canvas, as Keyboard Shortcuts would name it ("Tab").
        case key(String)
    }

    var id: Self { self }

    /// The name the message and help tags use: "Pen Tool", "Flat Bristle".
    var name: String {
        switch self {
        case .penTool: "Pen Tool"
        case .pathSelectionTool: "Path Selection Tool"
        case .directSelectionTool: "Direct Selection Tool"
        case .mixerBrushTool: "Mixer Brush Tool"
        case .paletteKnifeTool: "Palette Knife Tool"
        case .polygonTool: "Polygon Tool"
        case .starTool: "Star Tool"
        case .flatBristle: "Flat Bristle"
        case .roundBristle: "Round Bristle"
        case .fanBristle: "Fan"
        case .dryBrush: "Dry Brush"
        case .shapeStroke: "Shape Stroke"
        case .strokeOptions: "Stroke Options"
        case .pathOperations: "Path Operations"
        case .saveACopy: "Save a Copy"
        case .rasterize: "Rasterize"
        case .convertToEditableVectors: "Convert to Editable Vectors"
        case .uniteShapes: "Unite Shapes"
        case .subtractFrontShape: "Subtract Front Shape"
        case .uniteShapesAtOverlap: "Unite Shapes at Overlap"
        case .subtractShapesAtOverlap: "Subtract Shapes at Overlap"
        case .releaseToLayers: "Release to Layers"
        case .contextualTaskBar: "Contextual Task Bar"
        case .fullScreenModeWithMenuBar: "Full Screen Mode With Menu Bar"
        case .fullScreenMode: "Full Screen Mode"
        case .hidePanels: "Hide Panels"
        case .search: "Search"
        case .navigator: "Navigator"
        case .pencilTool: "Pencil Tool"
        case .perspectiveCropTool: "Perspective Crop Tool"
        case .fillOpacity: "Fill Opacity"
        case .colorLookup: "Color Lookup"
        case .effectBlendMode: "Effect Blend Mode"
        case .spread: "Spread"
        case .choke: "Choke"
        case .centerStroke: "Center Stroke"
        case .twoColumnToolbar: "Two-Column Toolbar"
        case .customizeToolbar: "Customize Toolbar"
        case .proofSetup: "Proof Setup"
        case .proofColors: "Proof Colors"
        case .gamutWarning: "Gamut Warning"
        case .sixteenBitsPerChannel: "16 Bits/Channel"
        case .thirtyTwoBitsPerChannel: "32 Bits/Channel"
        case .lockTransparentPixels: "Lock transparent pixels"
        }
    }

    /// The Backlog task that delivers it.
    var task: String {
        switch self {
        case .penTool, .pathSelectionTool, .directSelectionTool: "TASK-28"
        case .mixerBrushTool: "TASK-47"
        case .paletteKnifeTool: "TASK-50"
        case .polygonTool, .starTool, .shapeStroke, .rasterize: "TASK-32"
        case .flatBristle, .roundBristle, .fanBristle, .dryBrush: "TASK-46"
        case .strokeOptions, .pathOperations, .uniteShapes, .subtractFrontShape, .uniteShapesAtOverlap,
             .subtractShapesAtOverlap, .releaseToLayers: "TASK-34"
        case .saveACopy: "TASK-27"
        case .convertToEditableVectors: "TASK-35"
        case .contextualTaskBar: "TASK-67"
        case .fullScreenModeWithMenuBar, .fullScreenMode, .hidePanels: "TASK-78"
        case .search: "TASK-79"
        case .navigator: "TASK-80"
        case .pencilTool: "TASK-81"
        case .perspectiveCropTool: "TASK-82"
        case .fillOpacity: "TASK-83"
        case .colorLookup: "TASK-84"
        case .effectBlendMode, .spread, .choke, .centerStroke: "TASK-85"
        case .twoColumnToolbar: "TASK-86"
        case .customizeToolbar: "TASK-87"
        case .proofSetup, .proofColors, .gamutWarning: "TASK-89"
        case .sixteenBitsPerChannel, .thirtyTwoBitsPerChannel: "TASK-90"
        case .lockTransparentPixels: "TASK-93"
        }
    }

    var home: Home {
        switch self {
        case .penTool, .pathSelectionTool, .directSelectionTool, .mixerBrushTool, .paletteKnifeTool, .polygonTool,
             .starTool, .pencilTool, .perspectiveCropTool: .toolbar
        case .flatBristle, .roundBristle, .fanBristle, .dryBrush: .optionsBar([.brush])
        case .shapeStroke, .strokeOptions, .pathOperations: .optionsBar([.rectangle, .ellipse, .line])
        case .saveACopy: .menu("File › Save a Copy…")
        case .rasterize: .menu("Layer › Rasterize")
        case .convertToEditableVectors: .menu("Layer › Convert to Editable Vectors")
        case .uniteShapes, .subtractFrontShape, .uniteShapesAtOverlap, .subtractShapesAtOverlap:
            .menu("Layer › Combine Shapes › \(name)")
        case .releaseToLayers: .menu("Layer › Release to Layers")
        case .contextualTaskBar: .menu("Window › Contextual Task Bar")
        case .fullScreenModeWithMenuBar, .fullScreenMode: .menu("View › Screen Mode › \(name)")
        case .hidePanels: .key("Tab")
        case .search: .menu("Edit › Search")
        case .navigator: .menu("Window › Navigator")
        case .fillOpacity, .lockTransparentPixels: .panel("Layers")
        case .colorLookup: .menu("Image › Adjustments › Color Lookup…")
        case .effectBlendMode, .spread, .choke, .centerStroke: .panel("Layer Style")
        case .twoColumnToolbar: .panel("Toolbar")
        case .customizeToolbar: .menu("Edit › Toolbar…")
        case .proofSetup: .menu("View › Proof Setup › Custom…")
        case .proofColors, .gamutWarning: .menu("View › \(name)")
        case .sixteenBitsPerChannel, .thirtyTwoBitsPerChannel: .menu("Image › Mode › \(name)")
        }
    }

    /// The toolbar slot a planned tool sits in, nil for the rest.
    var slot: ToolSlot? { ToolSlot.allCases.first { $0.items.contains(.planned(self)) } }
    /// As a menu item or control names it: the menu's last word for a menu item ("Save a Copy…", "Custom…"), the name
    /// for the rest.
    var title: String { menuPath?.components(separatedBy: " › ").last ?? name }
    /// Accessibility label: "Pen Tool (P)" for a tool with a key, the name for the rest.
    var label: String { name + (slot?.key.map { " (\($0.uppercased()))" } ?? "") }
    /// Help tag: what a shipping control's says, then "In progress".
    var helpTag: String { "\(label) · In progress" }
    /// What the message says.
    var message: String { "\(name) is in progress" }
    /// The bristle presets of the brush picker, in its order.
    static let bristlePresets: [PlannedFeature] = [.flatBristle, .roundBristle, .fanBristle, .dryBrush]
    /// Layer ▸ Combine Shapes ▸, in menu order.
    static let combineShapes: [PlannedFeature] = [.uniteShapes, .subtractFrontShape, .uniteShapesAtOverlap, .subtractShapesAtOverlap]
    /// Layer Style's planned settings, in the order its pages show them.
    static let layerStyleOptions: [PlannedFeature] = [.effectBlendMode, .spread, .choke, .centerStroke]
    /// Menu items that ship with a key, by the title Keyboard Shortcuts lists them under: Save a Copy… ⌥⌘S, Search ⌘F,
    /// Proof Colors ⌘Y, Gamut Warning ⇧⌘Y.
    static let defaultKeyTitles: [PlannedFeature: String] = [
        .saveACopy: "Save a Copy", .search: "Search", .proofColors: "Proof Colors", .gamutWarning: "Gamut Warning",
    ]
    /// Menu items without a default key, which Keyboard Shortcuts lets people give one.
    static var assignableMenuCommands: [String] {
        allCases.filter { defaultKeyTitles[$0] == nil }.compactMap(\.menuPath)
    }
    /// Its menu path, for a menu item.
    var menuPath: String? {
        guard case .menu(let path) = home else { return nil }
        return path
    }

    /// The SF Symbol of an options-bar placeholder that shows one (planned tools' icons are `ToolIcon`'s).
    var symbol: String {
        switch self {
        case .strokeOptions: "lineweight"
        case .pathOperations: "square.on.square"
        default: "hammer"
        }
    }
}

/// The message a placeholder shows: one at a time, over the top of the canvas.
struct InProgressNotice: Equatable {
    let feature: PlannedFeature
    /// Each showing is its own, so the timer of one shown earlier doesn't take down the one that replaced it.
    let id = UUID()
    /// How long it stays when nobody clicks.
    static let duration: Duration = .seconds(3)

    /// Has VoiceOver read the message out, without moving its focus.
    static func announce(_ message: String) {
        guard let app = NSApp else { return }
        NSAccessibility.post(element: app.mainWindow ?? app, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}

extension EditorSession {
    /// Every placeholder's one action: the message, read out to VoiceOver, replacing any message already showing. It
    /// leaves the document, the selection, the tool and the toolbar slots as they were.
    func showInProgress(_ feature: PlannedFeature, for duration: Duration = InProgressNotice.duration) {
        let notice = InProgressNotice(feature: feature)
        inProgressNotice = notice
        announceInProgress(feature.message)
        Task { [weak self] in
            try? await Task.sleep(for: duration)
            if self?.inProgressNotice?.id == notice.id { self?.inProgressNotice = nil }
        }
    }

    /// Planned features' keys on the canvas: F steps to the next screen mode and Shift-F to the previous one, Tab and
    /// Shift-Tab hide the panels (TASK-78). False for any other key.
    @discardableResult
    func pressPlannedKey(_ key: String, shift: Bool = false) -> Bool {
        switch key {
        case "f": showInProgress(shift ? .fullScreenMode : .fullScreenModeWithMenuBar)
        case "\t": showInProgress(.hidePanels)
        default: return false
        }
        return true
    }

    /// The next click takes the message away (`InProgressNoticeView`).
    func dismissInProgressNotice() {
        if inProgressNotice != nil { inProgressNotice = nil }
    }
}
