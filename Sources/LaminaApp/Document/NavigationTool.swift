import Foundation
import LaminaCore

/// Every tool, in toolbar order (docs/DESIGN.md, Toolbar). Tools that familiar editors show apart are apart here too,
/// even where they share an engine: Brush, Eraser, Dodge and Burn all paint through the brush tip; the marquees and
/// lassos all draw a `LassoDraft`; Rectangle, Ellipse and Line all draw a `ShapeDraft`.
enum NavigationTool: String, CaseIterable {
    case move
    case rectangularMarquee, ellipticalMarquee
    case lasso, polygonalLasso
    case objectSelection, magicWand
    case crop, eyedropper
    case spotHealing, brush, cloneStamp, eraser
    case gradient, paintBucket
    case blur, smudge
    case dodge, burn
    case type
    case rectangle, ellipse, line
    case hand, zoom
    /// Filter ▸ Liquify…'s brush. It has no slot and no key: the menu picks it, and its bar's Done and Cancel leave it.
    case liquify
    /// No tool (A): nothing in the toolbar is selected and canvas clicks do nothing.
    case idle

    /// The toolbar slot this tool shares with the others of its group, nil for Liquify and No Tool.
    var slot: ToolSlot? { ToolSlot.allCases.first { $0.tools.contains(self) } }
    /// Tools that paint with the brush tip, sharing its size, hardness, opacity, and keys.
    var isBrushTool: Bool { [.brush, .spotHealing, .cloneStamp, .eraser, .blur, .smudge, .dodge, .burn, .liquify].contains(self) }
    /// The Brush and the tools that were once its modes. Flow, the pressure buttons and Smoothing are theirs; the other
    /// brush tools lay their full tip.
    var usesBrushDynamics: Bool { [.brush, .eraser, .dodge, .burn].contains(self) }
    /// Smudge and Liquify move the layer's pixels (`WarpStroke`) rather than painting through the tip.
    var warps: Bool { self == .smudge || self == .liquify }
    /// Tools that draw and edit selections, sharing modifiers, moving, and nudging.
    var isSelectionTool: Bool { lassoKind != nil || self == .objectSelection || self == .magicWand }
    /// The outline a selection tool drags out; nil for the click tools (Object Selection, Magic Wand) and the rest.
    var lassoKind: LassoKind? {
        switch self {
        case .rectangularMarquee: .rectangle
        case .ellipticalMarquee: .ellipse
        case .lasso: .freehand
        case .polygonalLasso: .polygonal
        default: nil
        }
    }
    /// The shape a shape tool draws on a new layer.
    var shapeKind: ShapeKind? {
        switch self {
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .line: .line
        default: nil
        }
    }
    /// Dodge lightens and Burn darkens; nil for the tools that don't tone.
    var toneLightens: Bool? { self == .dodge ? true : self == .burn ? false : nil }

    /// The name in options bars and menus: "Rectangular Marquee".
    var title: String {
        switch self {
        case .move: "Move"
        case .rectangularMarquee: "Rectangular Marquee"
        case .ellipticalMarquee: "Elliptical Marquee"
        case .lasso: "Lasso"
        case .polygonalLasso: "Polygonal Lasso"
        case .objectSelection: "Object Selection"
        case .magicWand: "Magic Wand"
        case .crop: "Crop"
        case .eyedropper: "Eyedropper"
        case .spotHealing: "Spot Healing Brush"
        case .brush: "Brush"
        case .cloneStamp: "Clone Stamp"
        case .eraser: "Eraser"
        case .gradient: "Gradient"
        case .paintBucket: "Paint Bucket"
        case .blur: "Blur"
        case .smudge: "Smudge"
        case .dodge: "Dodge"
        case .burn: "Burn"
        case .type: "Horizontal Type"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .hand: "Hand"
        case .zoom: "Zoom"
        case .liquify: "Liquify"
        case .idle: "No Tool"
        }
    }
    /// The key that picks it, as the toolbar shows it.
    var key: String? { slot.map { $0.key.uppercased() } ?? (self == .idle ? "A" : nil) }
    /// Help tag and accessibility label: "Rectangular Marquee Tool (M)".
    var label: String {
        switch self {
        case .liquify: "Liquify (⇧⌘X)"
        case .idle: "No Tool (A)"
        default: "\(title) Tool" + (key.map { " (\($0))" } ?? "")
        }
    }
    /// The SF Symbol for tools without an icon of their own (`ToolIcon`).
    var symbol: String {
        switch self {
        case .move: "arrow.up.left.and.arrow.down.right"
        case .rectangularMarquee: "rectangle.dashed"
        case .ellipticalMarquee: "circle.dashed"
        case .lasso, .polygonalLasso: "lasso"
        case .objectSelection, .magicWand: "wand.and.stars"
        case .crop: "crop"
        case .eyedropper: "eyedropper"
        case .spotHealing: "bandage"
        case .brush: "paintbrush.pointed"
        case .cloneStamp: "seal"
        case .eraser: "eraser"
        case .gradient: "square.bottomhalf.filled"
        case .paintBucket: "drop.halffull"
        case .blur: "drop"
        case .smudge: "hand.point.up.left"
        case .dodge: "sun.max"
        case .burn: "flame"
        case .type: "textformat"
        case .rectangle: "rectangle.fill"
        case .ellipse: "oval.fill"
        case .line: "line.diagonal"
        case .hand: "hand.draw"
        case .zoom: "magnifyingglass"
        case .liquify: "water.waves"
        case .idle: "circle.slash"
        }
    }
    /// What the status bar says the tool does, and its keys.
    var hint: String {
        switch self {
        case .move: "Drag to move · Handles to resize · Circle to rotate · 1–0 layer opacity · Space to pan"
        case .rectangularMarquee: "Drag a rectangle · Shift add · Option subtract · Shift again mid-drag square · Drag inside to move · ⌘-drag moves pixels · Delete clears · ⌘D deselect · Shift-M for Elliptical"
        case .ellipticalMarquee: "Drag an ellipse · Shift add · Option subtract · Shift again mid-drag circle · Drag inside to move · Delete clears · ⌘D deselect · Shift-M for Rectangular"
        case .lasso: "Drag to select · Drag inside to move · Shift add · Option subtract · Delete clears · ⌥⌫/⌘⌫ fill · ⌘D deselect · Shift-L for Polygonal"
        case .polygonalLasso: "Click corners · Click start, double-click or Enter to close · Delete removes corner · Escape cancel · Shift-L for Lasso"
        case .objectSelection: "Click an object to select its outline · Shift add · Option subtract · Drag inside to move · ⌘-drag moves pixels · Delete clears · ⌘D deselect · Shift-W for Magic Wand"
        case .magicWand: "Click to select similar colors · Shift add · Option subtract · Drag inside to move · ⌘-drag moves pixels · Delete clears · ⌘D deselect · Shift-W for Object Selection"
        case .crop: "Drag to crop · Enter apply · Escape cancel · Space to pan"
        case .eyedropper: "Click or drag to pick the foreground color · Space to pan"
        case .spotHealing: "Drag over blemishes to heal · [ ] size · Shift-[ ] hardness · Escape cancel · Space to pan"
        case .brush: "Drag to paint · [ ] size · Shift-[ ] hardness · 1–0 opacity · Escape cancel · Space to pan"
        case .cloneStamp: "Option-click to set the source · Drag to clone · [ ] size · Shift-[ ] hardness · 1–0 opacity · Space to pan"
        case .eraser: "Drag to erase · [ ] size · Shift-[ ] hardness · 1–0 opacity · Escape cancel · Space to pan"
        case .gradient: "Drag to draw · Drag ends to adjust · Shift 45° · 1–0 opacity · Enter apply · Escape cancel · Shift-G for Paint Bucket"
        case .paintBucket: "Click to fill similar colors · Option-click picks a color · 1–0 opacity · Shift-G for Gradient · Space to pan"
        case .blur: "Drag to soften · [ ] size · Shift-[ ] hardness · 1–0 strength · Shift-R for Smudge · Space to pan"
        case .smudge: "Drag to smudge · [ ] size · Shift-[ ] hardness · 1–0 strength · Shift-R for Blur · Space to pan"
        case .dodge: "Drag to lighten · [ ] size · Shift-[ ] hardness · 1–0 opacity · Shift-O for Burn · Escape cancel · Space to pan"
        case .burn: "Drag to darken · [ ] size · Shift-[ ] hardness · 1–0 opacity · Shift-O for Dodge · Escape cancel · Space to pan"
        case .type: "Drag a text box · Click text to edit · Drag box handles to resize · ⌘Return finish · Escape cancel"
        case .rectangle: "Drag to draw a rectangle on a new layer · Shift square · Option from center · Shift-U for the next shape · Escape cancel · Space to pan"
        case .ellipse: "Drag to draw an ellipse on a new layer · Shift circle · Option from center · Shift-U for the next shape · Escape cancel · Space to pan"
        case .line: "Drag to draw a line on a new layer · Shift 45° · Option from center · Shift-U for the next shape · Escape cancel · Space to pan"
        case .hand: "Drag to pan · Pinch to zoom"
        case .zoom: "Click to zoom in · Option-click to zoom out · Drag right or left to zoom smoothly · Space to pan"
        case .liquify: "Drag to push pixels · [ ] size · Shift-[ ] hardness · 1–0 strength · Return Done · Escape Cancel · Space to pan"
        case .idle: "No tool selected · Press a tool's key to pick one · Space to pan"
        }
    }
}

/// A place in the toolbar: the tools that share it, in flyout order, and the key that picks them. The key picks the
/// slot's last-used tool (`EditorSession.tool(in:)`); Shift and the key steps through the slot's tools.
enum ToolSlot: CaseIterable {
    case move, marquee, lasso, objectSelection, crop, eyedropper, spotHealing, brush, cloneStamp, eraser, gradient, blur,
         dodge, type, shapes, hand, zoom

    var tools: [NavigationTool] {
        switch self {
        case .move: [.move]
        case .marquee: [.rectangularMarquee, .ellipticalMarquee]
        case .lasso: [.lasso, .polygonalLasso]
        case .objectSelection: [.objectSelection, .magicWand]
        case .crop: [.crop]
        case .eyedropper: [.eyedropper]
        case .spotHealing: [.spotHealing]
        case .brush: [.brush]
        case .cloneStamp: [.cloneStamp]
        case .eraser: [.eraser]
        case .gradient: [.gradient, .paintBucket]
        case .blur: [.blur, .smudge]
        case .dodge: [.dodge, .burn]
        case .type: [.type]
        case .shapes: [.rectangle, .ellipse, .line]
        case .hand: [.hand]
        case .zoom: [.zoom]
        }
    }

    /// Lowercase, as the canvas reads keys.
    var key: String {
        switch self {
        case .move: "v"
        case .marquee: "m"
        case .lasso: "l"
        case .objectSelection: "w"
        case .crop: "c"
        case .eyedropper: "i"
        case .spotHealing: "j"
        case .brush: "b"
        case .cloneStamp: "s"
        case .eraser: "e"
        case .gradient: "g"
        // A Lamina extra: familiar editors give Blur and Smudge no key.
        case .blur: "r"
        case .dodge: "o"
        case .type: "t"
        case .shapes: "u"
        case .hand: "h"
        case .zoom: "z"
        }
    }
}

extension EditorSession {
    /// The tool a slot shows and its key picks: the one last used there, or its first.
    func tool(in slot: ToolSlot) -> NavigationTool { slotTools[slot] ?? slot.tools[0] }

    /// Whether `key` (lowercase) picks a tool: a slot's key, or A for No Tool.
    static func isToolKey(_ key: String) -> Bool { key == "a" || ToolSlot.allCases.contains { $0.key == key } }

    /// A tool key from the canvas or the Layers panel. The plain key picks its slot's last-used tool; with Shift, and
    /// that slot's tool already chosen, it picks the next one in the slot, round to the first.
    func pressToolKey(_ key: String, shift: Bool = false) {
        if key == "a" { selectTool(.idle); return }
        guard let slot = ToolSlot.allCases.first(where: { $0.key == key }) else { return }
        if shift, let index = slot.tools.firstIndex(of: tool) {
            selectTool(slot.tools[(index + 1) % slot.tools.count])
        } else {
            selectTool(tool(in: slot))
        }
    }

    /// Filter ▸ Liquify…: the Liquify brush, until Done keeps its strokes or Cancel takes them back.
    var canLiquify: Bool { tool != .liquify && canPaint && !isMaskSelected && activeLayer?.asset != nil }
    func beginLiquify() {
        guard canLiquify else { return }
        selectTool(.liquify)
    }
    /// Done: back to the tool chosen before, keeping the strokes.
    func finishLiquify() {
        guard tool == .liquify else { return }
        selectTool(liquifyEntry?.tool ?? .move)
    }
    /// Cancel: the document back where it was when Liquify was chosen (one History jump, so Redo brings the strokes
    /// back), then the tool chosen before. Steps undone past that point stay undone.
    func cancelLiquify() {
        guard tool == .liquify, canUseHistory, let entry = liquifyEntry else { return }
        if history.position > entry.position { jumpToHistory(entry.position) }
        selectTool(entry.tool)
    }
}
