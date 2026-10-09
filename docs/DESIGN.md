# Lamina design spec

- **Theme:** Familiar bench
- **Product:** Lamina, a macOS image editor for compositing and photo work
- **Framework:** SwiftUI and AppKit (macOS 26), Metal canvas
- **Supported appearances:** light and dark, following macOS, with an override in Settings
- **Target window:** 1500 × 860 pt, the usable area of a 14-inch MacBook Pro at default scaling
- **Visual reference:** [references/redesign_v2.html](references/redesign_v2.html), the approved interactive mockup
- **Policy:** decision-9 · **Delivery:** milestone m-5, Familiar workspace (TASK-51 to TASK-66)

This is the maintained spec for Lamina's interface. Every change to what people see (a tool, a menu item, a panel, a
dialog, a shortcut, a color, a size) updates this file in the same commit. If the app and this file disagree, one of
them is a bug: fix the one that is wrong, never leave them apart.

Status markers used below: **shipping** (in the app), **m-5** (being rebuilt by the milestone), **in progress (TASK-n)**
(a planned feature shown as a placeholder, see [In-progress placeholders](#in-progress-placeholders)).

## Overview and north star

**Familiar bench.** Someone who has spent years in Photoshop, Affinity or a similar editor sits down at Lamina and their
hands already know where everything is: tools in a column at the left, a context bar above the canvas, panels docked at
the right, Levels under Image ▸ Adjustments, Free Transform on ⌘T. Lamina offers that familiar layout with the names
people already use, then gets out of the way.

Familiar does not mean copied. Lamina is not a clone of any product: it never reproduces another app's visuals, icons,
colors, typefaces or branding. It draws everything with native macOS controls, SF Symbols and system colors, so it looks
like a well-made Mac app that happens to be laid out the way image editors are.

What the design is not:

- Not a novel layout. When familiar editors agree on where something goes, Lamina puts it there. When they disagree,
  the most widely known convention wins, which is usually Photoshop's.
- Not a dark-only "pro" skin. It follows the Mac's appearance.
- Not crowded. Lamina shows only what it can do, plus clearly marked planned features. No disabled ghosts of features
  nobody is building.

## Naming

- Use the established name for every tool, command, option and panel: "Rectangular Marquee Tool", "Free Transform",
  "Layer Via Copy", "Show Transform Controls", "Feather", "Merge Down".
- A Lamina-only feature uses the same vocabulary and sits in the nearest conventional place (Bloom / Glow goes in
  Filter ▸ Stylize; live filter layers go in Layer ▸ New Adjustment Layer under their own separator).
- Groups of layers are **groups**, never folders. Adjustment layers are edited in **Properties**.
- Menu items that open a dialog end with an ellipsis (…). American spelling throughout.
- Labels in options bars and dialogs end with a colon ("Opacity:", "Width:"); checkbox labels and panel headings don't.

## Workspace layout

The window is one frame with five regions. Sizes are in points.

| Region | Size | Contents |
| --- | --- | --- |
| Title bar | 38 high (the system's unified toolbar draws it about 40 on macOS 26) | Traffic lights, New (+), document tabs. Nothing else. |
| Options bar | 36 high | The active tool's icon, then its settings (see [Options bars](#options-bars)). |
| Toolbar | 44 wide | One column of tool slots, colors at the bottom. |
| Canvas column | the rest | Pasteboard, the document centered on it, the status bar under it. |
| Status bar | 22 high, under the canvas only | Editable zoom field, document size and resolution, tool hint at the right. |
| Panel icon column | 34 wide | Collapsed panels: History. |
| Dock | 292 wide (240 to 360, resizable) | Properties \| Adjustments group (about 340 high) over the Layers group (the rest). |

Rules:

- At 1500 × 860 pt nothing is clipped and nothing scrolls except panel contents. The canvas keeps at least
  1100 × 740 pt.
- Document tabs read `Golden Hour @ 44.5% (Golden hour, RGB/8)`: name, zoom (one decimal at most), active layer, mode
  and depth; without an active layer `Name @ 25% (RGB/8)`, and before a document exists just the name. Every tab shows
  its own document's zoom and layer. When the tabs don't fit, the widest narrow first, down to 140 pt, their labels
  truncating in the middle; past that the oldest move into the "N more tabs" menu. The help tag shows the full label.
- Fit, 100% and zoom buttons do not live in the title bar. Zoom lives in View, the status bar and the Hand and Zoom bars.
  The tab strip takes the title bar's width less the traffic lights and New (`ProjectTabStrip.titleBarInset`).
- The canvas starts 36 pt below the title bar for every tool. Switching tools never moves the canvas: every tool's
  settings sit in one 36 pt bar, and No Tool (A) shows only its icon (`circle.slash`).
- The status bar reads, left to right: the zoom field (`88.53%`, 58 pt wide; Return or leaving the field applies it,
  Up and Down step 1%, Shift 10%), `2400 px × 1500 px (72 ppi)`, then the active tool's hint, right-aligned, cut off
  at its end when the column is narrow. Busy work ("Working…", "Importing images…") shows in the hint's place.
- Status: **shipping** (TASK-52). The frame is `ContentView` (`editorStack`); the options bar is `OptionsBar`
  (`UI/OptionsBar.swift`), the tool → icon mapping `ToolIcon` (`UI/ToolIcon.swift`, with a size: 18 pt in the toolbar,
  16 pt in the options bar and flyouts), the zoom field `ZoomField` (`UI/StatusBar.swift`); the hint is the tool's
  `hint`. The toolbar is `ToolbarColumn` (TASK-55, see [Toolbar](#toolbar)): at 1500 × 860 pt every slot and the colors
  fit with about 90 pt to spare. The panel icon column and the dock shipped with TASK-58 (see [Dock and panels](#dock-and-panels)): at
  1500 × 860 pt with the dock at its default width the canvas measures about 1115 × 761 pt (at the dock's widest,
  360 pt, about 1047 pt wide).

## Colors and surfaces

Native controls (buttons, pop-ups, checkboxes, text fields, menus, sheets) draw themselves with system colors; never
recolor them. Everything Lamina draws itself takes a **named role**, defined once in code with a light and a dark value.
No literal grays (`Color(white:)`, hex) in interface code. The roles live in `Sources/LaminaApp/UI/ColorRoles.swift`
(`ColorRole`, with `.color` for SwiftUI, `.nsColor` for AppKit and `resolved(for:)` for layer and Metal colors), and
`ColorRoleTests` checks them against this table. **Shipping** (TASK-51).

| Role | Used for | Light | Dark | System equivalent |
| --- | --- | --- | --- | --- |
| window | behind everything | `#F5F5F7` | `#1D1D1F` | `windowBackgroundColor` |
| chrome | title bar, options bar, toolbar, status bar, panel icon column | `#ECECEE` | `#29292C` | own role |
| panel | dock panels | `#F6F6F8` | `#2B2B2E` | own role |
| panelHeader | panel tab rows | `#E3E3E6` | `#232326` | own role |
| field | custom wells, histogram and curve backgrounds | `#FFFFFF` | `#18181A` | `textBackgroundColor` |
| control | custom buttons, active tab, task bar buttons | `#E0E0E4` | `#3B3B40` | own role |
| hover | hovered tool slots, rows, cells | `#DCDCE1` | `#38383C` | own role |
| activeTool | the selected tool slot, pressed icon buttons | `#C9C9CF` | `#55555B` | own role |
| edge | lines between regions | `#C3C3C8` | `#111113` | own role |
| separator | rows, sections, dividers inside bars | `#E2E2E6` | `#232326` | `separatorColor` |
| text / secondaryText / tertiaryText | labels, values, hints | `#1D1D1F` / `#6E6E73` / `#A1A1A6` | `#E6E6E9` / `#A3A3AA` / `#75757C` | `labelColor` family |
| icon | tool and panel icons | `#3A3A3E` | `#D6D6DB` | own role |
| accent | default buttons, checkboxes, focus | system accent | system accent | `controlAccentColor` |
| selection | selected layer, history state, list rows | `#CFE0FB` | `#2A5596` | own role |
| pasteboard | the area around the document | `#C6C6CB` | `#202022` | own role |

- Every role takes the values in this table, accent excepted (the system's). The system equivalents are not used:
  on current macOS they don't keep this hierarchy (`windowBackgroundColor` is white in light, lighter than `chrome`).
- Regions are separated by a 1 pt `edge` line, never by shadows or gradients.
- The document, its thumbnails and canvas overlays look the same in both appearances: transform box and handles
  `#3E8BFF` with white handle fills, marching ants black and white, crop shield black at 32%. Fixed too: the
  transparency checkerboard and the document's shadow and edge, guides and grid in their chosen colors, brush and
  sample-ring cursors, and what shows tones or colors (Levels' black, gray and white sliders, color wheels and fields,
  Camera Raw's colored slider tracks, the Color Range mask preview).
- Custom wells (histograms, curves, the Camera Raw scopes) are `field` with `separator` grid lines and `text` curves
  and points; image previews in dialogs (Export, Camera Raw develop, filter previews) sit on `pasteboard`; swatch and well borders are
  `edge`; pressed mode buttons in dialogs and options bars are `activeTool`; selected history states and effect rows
  are `selection`.
- The options bar, toolbar, status bar and panel icon column sit on `chrome`, the dock's panels on `panel` with
  their tab rows on `panelHeader`, and the active document tab is a `control` capsule with an `edge` outline.
- Appearance follows macOS and switches live. Lamina ▸ Settings… (⌘K) opens the Lamina Settings window (an AppKit
  window, `SettingsWindow` in `UI/SettingsView.swift`: a SwiftUI `Settings` scene would keep its own ⌘, item), whose
  Appearance setting (System, Light, Dark, as radio buttons) is saved as `appearance` in UserDefaults and applied to the whole app
  through `NSApp.appearance`, alerts and open and save panels included. **Shipping** (TASK-51).
- The mockup's colored change dots are review aids, not app colors.

## Typography

SF Pro (the system font) everywhere; no bundled typefaces.

| Use | Size and weight |
| --- | --- |
| Menus, dialog body text | 13 regular (system default) |
| Options bar, panels, layer names, field values | 12 regular |
| Panel section headings, Properties title | 11.5–12 semibold |
| Status bar, layer sub-rows, Adjustments grid labels | 10–11 regular |

Every numeric field uses monospaced digits so values don't jitter while scrubbing. Units sit tight against their value
("40 px", "100%").

## Iconography

- SF Symbols first, at the symbol weight that matches 1.5 pt strokes; draw a custom icon only when no symbol reads as
  the tool. Custom icons are SwiftUI shapes (like today's `GradientToolIcon`) with the same stroke weight and corner
  treatment as the symbols around them.
- Sizes: 18 pt in toolbar slots and the Adjustments grid, 16 pt in options bars, menus (the toolbar's flyouts too)
  and the panel icon column, 15 pt in panels and footers.
- Icons take the `icon` role; the active tool's icon takes `text`. No colored icons except the color swatches.
- A slot whose group has more than one tool shows a small triangle in its bottom-right corner (4 pt, inset 3 pt,
  `secondaryText`).

| Tool | Icon |
| --- | --- |
| Move | four-headed arrow, `arrow.up.and.down.and.arrow.left.and.right` (never a resize arrow) |
| Rectangular / Elliptical Marquee | `rectangle.dashed` / `circle.dashed` |
| Lasso / Polygonal Lasso | `lasso` / custom polygonal loop |
| Object Selection / Magic Wand | custom dashed box with pointer / `wand.and.stars` |
| Crop | `crop` |
| Eyedropper | `eyedropper` |
| Spot Healing Brush | `bandage` |
| Brush | `paintbrush.pointed` |
| Clone Stamp | custom stamp |
| Eraser | `eraser` |
| Gradient / Paint Bucket | custom filled square / custom bucket |
| Blur / Smudge | `drop` / `hand.point.up.left` |
| Dodge / Burn | custom paddle, solid so it doesn't read as Zoom's magnifier / custom hand cupped under a spot of light |
| Horizontal Type | a serif "T" (not "Aa"), the system's serif face |
| Rectangle / Ellipse / Line | `rectangle.fill` / `oval.fill` / `line.diagonal` |
| Hand / Zoom | `hand.raised` / `magnifyingglass` |
| Pen (in progress) | `pencil.tip` |
| Path Selection / Direct Selection (in progress) | `cursorarrow` / `point.topleft.down.to.point.bottomright.curvepath` |
| Mixer Brush / Palette Knife (in progress) | `paintbrush` / custom palette knife (`PaletteKnifeToolIcon`) |
| Polygon / Star (in progress) | `hexagon.fill` / `star.fill` |
| Stroke options / path operations (shape bars, in progress) | `lineweight` / `square.on.square` |
| History panel | `clock.arrow.circlepath` |

Status: **shipping** (TASK-55). `ToolIcon` (`Sources/LaminaApp/UI/ToolIcon.swift`) is the one tool → icon mapping:
`ToolIcon.symbol(for:)` gives each symbol, and the custom icons are SwiftUI drawings beside it (`DodgeToolIcon`,
`BurnToolIcon`, `TypeToolIcon`, `PaletteKnifeToolIcon`; `GradientToolIcon`, `PaintBucketToolIcon`, `CloneStampToolIcon`,
`PolygonalLassoToolIcon`, `ObjectSelectionToolIcon` sit with their tools' bars), stroked 1.5 pt at 18 pt.
`ToolIcon.menuImage(for:)` renders them as template images for menus.

## Elevation and depth

Chrome is flat: regions sit side by side, separated by `edge` lines. Only transient things float, and they float with
the system's materials and shadows: menus, tool flyouts, pop-overs (brush picker, sliders), the in-progress message,
the Contextual Task Bar and dialogs. Nothing in the chrome uses gradients, glows or inner shadows.

## Components

### Toolbar

One column, top to bottom. A slot shows the last tool used from its group; holding the mouse on a slot or right-clicking
it opens a flyout listing the group's tools with icon, name and key. A tool's key picks its slot's last-used tool; Shift
plus the key, with that slot's tool active, picks the next tool in the slot (round to the first), and from any other
tool picks the slot's last-used one. A held key counts once. Help tags and accessibility labels read "Tool name (Key)".
Status: the separate tools, their keys and Shift cycling are **shipping** (TASK-54: `NavigationTool` and `ToolSlot` in
`Sources/LaminaApp/Document/NavigationTool.swift`, with each slot's last tool in `EditorSession.slotTools`); so is the
slot column with flyouts (TASK-55), described below. The planned tools in this table are **shipping** as placeholders (TASK-53): `ToolSlot.items` lists them in
flyout order, P shows the Pen's message, and Shift-cycling passes through them (see
[In-progress placeholders](#in-progress-placeholders)).

The column (`ToolbarColumn`, `Sources/LaminaApp/UI/Toolbar.swift`) is 44 pt wide on `chrome`, 6 pt from the top:

- One 32 × 30 slot per `ToolSlot`, 1 pt apart, with a 22 × 1 pt `separator` line (4 pt above and below) where the
  table below has a separator (`ToolSlot.startsGroup`). A slot shows `EditorSession.shownItem(in:)`: the active tool
  when it's the slot's, else the slot's last-used tool, else (Pen, Path Selection) its first planned item. The active
  slot sits on `activeTool` with its icon in `text`; a hovered one on `hover`; the rest show `icon` on `chrome`. Corners
  6 pt.
- A click chooses the shown item through `EditorSession.choose(_:)`, so a planned one shows its message. Holding the
  mouse 0.35 s, right-clicking or Control-clicking opens the flyout: a native menu beside the slot's top right listing
  the slot's items in flyout order, each with its 16 pt icon, its name ("Elliptical Marquee Tool") and the slot's key
  at the right; a checkmark marks the shown item. Held open, dragging onto an item and letting go chooses it. Planned
  items are listed like the others, with the "· In progress" help tag. The icon is drawn in the item's title, since
  macOS 27 leaves menu items' own images out of menus.
- Each slot (`ToolSlotControl`, AppKit, over the SwiftUI drawing) is a button to VoiceOver labeled "Tool name (Key)"
  and reported selected when active; its Show Menu action opens the flyout. Its help tag is the same label (with
  "· In progress" for a planned item).
- The colors follow 10 pt below the last slot (`ColorPaletteControls`): the foreground swatch over the background one,
  swap (X) at the top right, default colors (D) at the bottom left.
- The column scrolls, without a scroller, only in a window too short for it (`IndicatorlessScrollView`).

Each tool remembers its settings. Brush and Spot Healing share one tip (size, hardness, opacity); Eraser, Dodge and Burn,
Blur and Smudge, Clone Stamp and Liquify each keep their own, and settings saved before the split start Eraser, Dodge
and Burn from the Brush's tip and Liquify from Blur's. Flow, Smoothing and the pressure buttons are shared by Brush,
Eraser, Dodge and Burn. Each slot's last tool lasts while the document is open; which of Dodge and Burn the Dodge slot
holds carries over to new documents with the brush settings.

| Slot | Tools, in flyout order | Key |
| --- | --- | --- |
| Move | Move Tool | V |
| Marquee | Rectangular Marquee Tool, Elliptical Marquee Tool | M |
| Lasso | Lasso Tool, Polygonal Lasso Tool | L |
| Object selection | Object Selection Tool, Magic Wand Tool | W |
| *separator* | | |
| Crop | Crop Tool | C |
| *separator* | | |
| Eyedropper | Eyedropper Tool | I |
| *separator* | | |
| Spot healing | Spot Healing Brush Tool | J |
| Brush | Brush Tool, Mixer Brush Tool (in progress, TASK-47), Palette Knife Tool (in progress, TASK-50) | B |
| Clone | Clone Stamp Tool | S |
| Eraser | Eraser Tool | E |
| Gradient | Gradient Tool, Paint Bucket Tool | G |
| Blur | Blur Tool, Smudge Tool | R (a Lamina extra) |
| Dodge | Dodge Tool, Burn Tool | O |
| *separator* | | |
| Pen | Pen Tool (in progress, TASK-28) | P |
| Type | Horizontal Type Tool | T |
| Path selection | Path Selection Tool, Direct Selection Tool (both in progress, TASK-28) | A once TASK-28 ships; until then A stays "no tool" |
| Shapes | Rectangle Tool, Ellipse Tool, Polygon Tool (in progress, TASK-32), Star Tool (in progress, TASK-32), Line Tool | U |
| *separator* | | |
| Hand | Hand Tool | H |
| Zoom | Zoom Tool | Z |
| Colors | Foreground over background swatches, default colors and swap controls | D, X |

Liquify is not a toolbar tool: Filter ▸ Liquify… (⇧⌘X) picks the Liquify brush, with its own bar (brush picker,
Strength, then Cancel and Done). Done (Return) goes back to the tool chosen before and keeps the strokes; Cancel
(Escape) jumps History back to where Liquify was chosen, so Redo can bring the strokes back, then goes back too.
Picking any other tool keeps the strokes, as Done does. The menu item is dimmed without a layer's pixels to push (an
empty layer, a mask targeted). Status: **shipping** (TASK-54). Tools familiar editors have and Lamina has no task for
(Artboard, Frame, Quick Selection, Healing Brush, History Brush, Sponge and so on) don't appear.

### Options bars

Each bar starts with the active tool's icon (16 pt, `text`, in a 44 pt slot with the tool's name as its help tag and
accessibility label; no tool name is written out), then groups separated by 1 × 20 pt `separator` dividers (│ below).
Fit Screen fits the document with a margin, as View ▸ Fit Canvas does; Fill Screen zooms until the document covers the
whole canvas area, centered. Controls: icon
buttons 24 × 22, pop-ups and fields 22 high, percent fields with a slider pop-up. Edits in progress end with Cancel and
Commit icon buttons at the far right. Status: **m-5** (TASK-57 for the rest); the Move and Free Transform bars are
**shipping** (TASK-56: `MoveToolBar`, `FreeTransformBar`; `OptionsBarDivider` and `OptionsBarIconButton` are the shared
divider and 24 × 22 icon button).

| Tool | Bar, left to right |
| --- | --- |
| Move | Auto-Select ☐ · Show Transform Controls ☑ │ Align Left, Horizontal Centers, Right · Distribute Vertically · Align Top, Vertical Centers, Bottom · Distribute Horizontally · ••• Align & Distribute menu |
| Free Transform (while transforming) | Reference point │ X px · Y px │ W % · link · H % │ angle ° │ Interpolation: Nearest Neighbor, Bilinear, Bicubic │ … Cancel ⊘ · Commit ✓ |

The Move bar's align buttons are dimmed until two or more layers are selected, or a selection is there to line one
layer up with; the distribute buttons (vertical and horizontal spacing) until three are. The ••• menu has every Align
(Left, Horizontal Centers, Right, Top, Vertical Centers, Bottom Edges) and Distribute (Horizontal and Vertical
Centers, Horizontal and Vertical Spacing) command, and with one layer selected it lines it up with the canvas.

The Free Transform bar replaces the Move bar while a Free Transform waits for Commit: Edit ▸ Free Transform (⌘T; the
selected pixels when there is a selection), Edit ▸ Transform ▸ Distort, or a press on a handle of the transform box
(resize, rotate, ⌘ to distort), as in familiar editors. More drags, typed values, flips and arrow nudges join the same
edit; Commit (✓, Return) applies it as one undo step and Cancel (⊘, Escape) puts everything back. A press inside the
box (or anywhere, with Show Transform Controls off) only moves the layer, applied when let go, and leaves the Move bar
in place. The reference point (3 × 3, the center by default) is where X and Y measure, and what typed W, H and angle
and rotation drags keep in place; the canvas marks it with a ringed cross. W and H are percentages of the layer's
pixels drawn 1:1 (of the box when several layers are transformed), and the link keeps the aspect ratio (Shift flips
it during a handle drag). Interpolation names Lamina's per-layer sampling (Nearest, Smooth, High quality) for display
only: saved projects don't change; chosen for several layers, it goes to each of them. While distorting, the numbers
are dimmed: the corner handles are the controls.
| Rectangular / Elliptical Marquee | New, Add, Subtract selection icons │ Feather: 0 px (for the next selection) · Anti-alias (dimmed for rectangles) |
| Lasso / Polygonal Lasso | selection icons │ Feather · Anti-alias |
| Object Selection | selection icons │ Sample All Layers · Edge (Lamina) │ Select Subject |
| Magic Wand | selection icons │ Sample Size · Tolerance · Anti-alias · Contiguous · Sample All Layers │ Select Subject |
| Crop | Ratio (Ratio, Original Ratio, 1:1 (Square), 4:3, 16:9, …) · W ⇄ H · Clear │ … Cancel · Commit |
| Eyedropper | Show Sampling Ring |
| Spot Healing Brush | brush picker │ Type: Content-Aware \| Create Texture \| Proximity Match │ pressure for size |
| Brush | brush picker (Size, Hardness; bristle presets in progress, TASK-46, shipping as a Presets pop-up at the start of today's bar until TASK-57 builds the picker) │ Opacity · pressure for opacity · Flow │ Smoothing │ pressure for size |
| Clone Stamp | brush picker │ Opacity · pressure for opacity │ Aligned · Sample: Current Layer, All Layers │ pressure for size |
| Eraser | brush picker │ Opacity · pressure for opacity · Flow · Smoothing │ pressure for size |
| Gradient | gradient preset picker · Linear, Radial │ Opacity · Reverse |
| Paint Bucket | Fill: Foreground │ Opacity · Tolerance · Anti-alias · Contiguous · All Layers |
| Blur / Smudge | brush picker │ Strength · Radius (Blur only, Lamina) │ pressure for size |
| Dodge / Burn | brush picker │ Range: Shadows, Midtones, Highlights · Exposure │ pressure for size |
| Horizontal Type | font family · font style · size │ Left, Center, Right · color · Character panel │ … Cancel · Commit (leading and tracking are in Properties ▸ Character, shipping with TASK-59) |
| Rectangle / Ellipse / Line | Fill swatch · Stroke swatch and width (in progress, TASK-32) · stroke options (in progress, TASK-34) │ path operations (in progress, TASK-34) │ Radius (Rectangle) or Weight (Line). This order and the placeholders ship with TASK-53 (the stroke swatch shows "none": an empty `field` well crossed by a `secondaryText` line; the width reads "1 px"); the labels keep today's wording, without colons, until TASK-57 |
| Hand | 100% · Fit Screen · Fill Screen (shipping, TASK-52) |
| Zoom | Zoom In, Zoom Out │ Scrubby Zoom │ 100% · Fit Screen · Fill Screen (the three buttons ship with TASK-52; the rest is TASK-57) |

The painting bars carry no color swatch: color comes from the toolbar's swatches, black and white for masks included.

### Dock and panels

Tab groups with a 26 pt tab row and a panel menu (≡) at the right; the active tab is `text` with an underline.
Status: the frame is **shipping** (TASK-58); Adjustments' grid (TASK-60) and Properties (TASK-59) are **shipping**;
Layers' contents are **m-5** (TASK-61).

- Right of the canvas: the 34 pt panel icon column (`chrome`, 28 pt buttons with 16 pt icons, the open panel's
  button on `activeTool`), then the dock, 292 pt wide by default and 240–360 pt by dragging its left edge. Properties
  | Adjustments sits on top, 340 pt high with its tab row by default; Layers takes the rest. Dragging the line between
  them moves the split; the top group keeps at least 120 pt and Layers at least 160 pt (a split set in a taller window
  shows clamped). Both lines take the drag across an 8 pt band centered on them, with the resize pointer. Width, split, closed panels and the top group's front tab are remembered (UserDefaults `dockWidth`,
  `dockTopHeight`, `dockClosedPanels`, `dockTopTab`).
- The panel menu (≡) holds Close (the front tab's panel) and Close Tab Group. A group with every panel closed collapses
  and gives its height to the other; with every dock panel closed only the icon column stays and the canvas takes the
  dock's width. Renaming a layer opens Layers again; adding an adjustment layer, double-clicking one (its thumbnail)
  and Layer ▸ Layer Content Options… open Properties and bring it to the front.
- Window lists Adjustments, History, Layers and Properties alphabetically, as familiar editors do. A panel is checked
  while it is on screen (open and in front of its group); choosing a checked panel closes it, choosing any other opens
  it and brings it to the front. Window ▸ Workspace ▸ Essentials (Default) is the only workspace and always checked;
  Reset Essentials restores the default width and split, opens every dock panel with Properties in front, and closes
  History. All of them take a shortcut in Keyboard Shortcuts; none has a default key.
- Layers moved in unchanged, its own title row included, until TASK-61. Properties reads "No properties" only before a
  document exists.
- Code: `UI/Dock.swift` (`DockArea`, `Dock`, `DockGroup`, `PanelIconColumn`, `HistoryFlyout`, `DockResizeEdge`),
  `UI/DockLayout.swift` (`DockLayout.shared`, `DockPanel`), `UI/DockCommands.swift` (the Window items). A panel fills
  its tab through `Dock`'s content builder: `PropertiesPanel` (`UI/PropertiesPanel.swift`), `AdjustmentsPanel`
  (`UI/AdjustmentsPanel.swift`), `LayersPanel`.

- **Properties** shows what is selected. **Shipping** (TASK-59).

  | Selection | Title | Sections |
  | --- | --- | --- |
  | Nothing (document) | Document | Canvas (W · link · H, in the ruler units; Resolution, Pixels/Inch) · Rulers & Grids (Units: Pixels, Inches, Centimeters, Millimeters; Grid, Guides, Rulers checkboxes) · Quick Actions: Image Size, Crop, Trim, Rotate |
  | Pixel layer, shape layer | Pixel Layer, Shape Layer | Transform (W · link · H, X · Y, angle, Flip Horizontal, Flip Vertical) · Align and Distribute (six align buttons, then four distribute buttons) · Layer (Interpolation: Lamina's per-layer sampling) · Quick Actions: Remove Background, Select Subject |
  | Type layer | Type Layer | Transform · Character (family, style, size, leading, tracking, color) · Paragraph (Left, Center, Right) |
  | Group, or several layers | Layer Group, *n* Layers | Transform · Align and Distribute |
  | Adjustment layer | the kind ("Curves") | the adjustment's controls, live · footer: Clip to Layer Below, Reset to Adjustment Defaults, Hide/Show Layer, Delete Layer |
  | Layer mask (its thumbnail targeted) | Layer Mask | Masks (Refine: Color Range…, Invert) · footer: Load Selection from Mask, Apply Mask, Delete Mask |

  - The title row (32 pt) shows the kind's 15 pt icon in `icon` and its name in 12 pt semibold; Curves' icon is turned
    a quarter, as in Layers. Sections have an 11.5 pt semibold heading with a chevron that folds them; which headings
    are folded is remembered for every selection (ToolDefaults `propertiesCollapsed`). Sections are separated by
    `separator` lines, padded 10 pt, and scroll when the group is too short; the footer (30 pt, 15 pt icons) stays at
    the bottom. Fields use monospaced digits; row labels in the panel have no colon ("Resolution", "Units",
    "Interpolation"), except inside the adjustment controls it shares with the dialogs ("Channel:", "Hue:"). Quick
    actions are `control` plates two to a row.
  - Every change is one undo step and goes through the path its menu or bar uses. Transform fields work as the Free
    Transform bar's (`TransformValueField`): typed, stepped or scrubbed values show at once and apply when the field
    is done, and during a Free Transform they join it. W and H are the box's own size in pixels (kept at its top
    left, linked by the Move tool's aspect lock); X and Y the top left of the upright bounds around it; the angle
    turns it about its middle. Canvas W and H apply as Canvas Size… (around the center, transparent), Resolution as
    Image Size… without resampling; both wait for Return or leaving the field. Rotate rotates 90° clockwise, and
    holding it offers Image ▸ Image Rotation's three.
  - A type layer that is only selected changes as a whole and at once (Character's color through the app's picker,
    one step however long it stays open; Cancel leaves none). While its text is being edited, the changes go to the
    selected letters and are applied with the text, as the Type bar's are. Leading (empty is Auto) and tracking are
    here only, not in the Type bar.
  - An adjustment layer's controls are the dialogs' own (`LevelsControls`, `HueSaturationControls`, `CurvesControls`,
    `FilterControls` with `compact`: each slider's title above it), writing to the layer as they move. A drag is one
    undo step, closed when the mouse button comes up; a typed value or a menu choice is one step. Levels counts the
    layers below the adjustment for its histogram and Auto. The eyedroppers and Hue/Saturation's targeted adjustment
    stay in Image ▸ Adjustments' dialogs. Reset puts back what a new layer of the kind starts with (a Gradient Map
    from the current colors), keeping a Grain or Add Noise layer's pattern. Invert has no settings and says so.
  - Color Range… on a mask opens Select ▸ Color Range… aimed at it: OK makes the mask from the colors picked (white
    where they match), as one "Mask Color Range" step, and leaves the selection as it was. Invert inverts the mask.
  - Code: `UI/PropertiesPanel.swift` (panel, sections, document, transform, align, mask), `UI/PropertiesCharacter.swift`
    (Character, Paragraph, `FontFamilyPopUp`), `UI/AdjustmentProperties.swift` (controls, footer),
    `Document/PropertiesEditing.swift` (`PropertiesKind`, `changeProperty` and the edits it makes).

- **Adjustments** (**shipping**, TASK-60): a grid of labeled icons that add an adjustment layer in one click, in this
  order: Grain, Levels, Curves, Exposure, Hue/Saturation, Color Balance, Black & White, Invert, Gradient Map; then a
  "Filter layers" section (11.5 pt semibold heading with a 9.5 pt "Lamina" tag, `secondaryText` on `control`): Gaussian
  Blur, Motion Blur, Add Noise. Each cell is an 18 pt `icon` symbol over its 10 pt name, on `hover` under the pointer
  (5 pt corners), with a help tag naming the adjustment; columns are at least 62 pt, so four fit a row at 292 pt and
  three at 240, and the grid reflows as the dock is resized. A click does what Layer ▸ New Adjustment Layer does (one
  undo step; the new layer goes above the active one and is selected) and brings Properties to the front. The grid
  is dimmed under the menu's rule: no document, or layers can't be edited right now.

  | Adjustment | Symbol | Adjustment | Symbol |
  | --- | --- | --- | --- |
  | Grain | `film` | Black & White | `circle.lefthalf.filled` |
  | Levels | `chart.bar.xaxis` | Invert | `circle.lefthalf.filled.inverse` |
  | Curves | `point.bottomleft.forward.to.point.topright.scurvepath` | Gradient Map | `rectangle.split.3x1` |
  | Exposure | `plusminus.circle` | Gaussian Blur | `camera.aperture` |
  | Hue/Saturation | `drop.halffull` | Motion Blur | `wind` |
  | Color Balance | `slider.horizontal.3` | Add Noise | `aqi.medium` |

  Code: `UI/AdjustmentsPanel.swift` (`AdjustmentsPanel.adjustments`, `filterLayers`, `AdjustmentKind.panelSymbol`).
- **Layers** (TASK-61): blend mode menu and Opacity on top; one-line 32 pt rows (eye, thumbnail, link, mask thumbnail,
  name, fx badge); clicking the layer or mask thumbnail picks what edits target; styled layers list an "Effects" row and
  one 22 pt row per effect, each with an eye. Footer, left to right: Add a layer style (menu: Blending Options… │
  Stroke… · Inner Shadow… · Inner Glow… · Color Overlay… · Outer Glow… · Drop Shadow…, each opening the Layer Style
  dialog on its page; **shipping**, TASK-64, in today's footer), Add layer mask, New fill or adjustment layer, New
  group, New layer, Delete. Double-clicking an effect row opens the Layer Style dialog on that effect (**shipping**).
- **History** lives in the panel icon column. Clicking its icon opens it as a floating panel, 240 pt wide and up to
  420 pt high, at the top right of the canvas column against the icon column (`panel` with an `edge` outline, 6 pt
  corners and the system shadow), with a History tab row and its panel menu; it stays open while you work and closes
  from its icon, Close in its panel menu or Window ▸ History. It lists the states (Initial State first), with Undo and
  Redo and the number of steps kept in its footer; clicking a state goes back or forward to it. It starts closed.

### Menus

Separators are shown as │. Items not listed don't exist. Status: **m-5** (TASK-62). Edit ▸ Free Transform ⌘T and
Edit ▸ Transform ▸ (Distort │ Flip Horizontal · Flip Vertical) are **shipping** (TASK-56), replacing Layer ▸ Transform
Layer / Transform Selection and Flip Layer Horizontal / Vertical; TASK-62 puts them in the order below. During a Free
Transform, Flip turns the box over across the reference point as part of the edit (dimmed while distorting);
otherwise it flips the selected layers about their middle at once. Until TASK-62, View ▸ Show Transform Controls stays
in the View menu with no shortcut. The in-progress menu items ship with TASK-53 in today's menus, as close to these
places as today's order allows: Save a Copy… after Save As…, Rasterize and Convert to Editable Vectors after Apply
Layer Mask, Combine Shapes ▸ and Release to Layers after Move Layer Down, and in Window, Contextual Task Bar between
the panels and the open documents (in `DockCommands`). TASK-62 moves them with the rest. Layer ▸ Layer Style ▸
(Blending Options… │ the six effects │ Copy, Paste and Clear Layer Style) is **shipping** (TASK-64); the new items have
no keys and can be given one (Keyboard Shortcuts, More Menu Commands). Layer ▸ Layer Content Options… (was Edit
Adjustment…, a key set for it carries over) is **shipping** (TASK-59): with an adjustment layer selected it shows
Properties; TASK-62 puts it in the order below.

- **Lamina:** About Lamina · Check for Updates… │ Settings… ⌘K │ Services ▸ │ Hide Lamina ⌃⌘H · Hide Others ⌥⌘H · Show All │ Quit Lamina ⌘Q
- **File:** New… ⌘N · New from Clipboard ⌥⌘N · Open… ⌘O · Open Recent ▸ │ Close ⌘W │ Save ⌘S · Save As… ⇧⌘S · Save a Copy… ⌥⌘S (in progress: layered Photoshop files, TASK-27) │ Export ▸ (Quick Export as PNG │ Export As… ⌥⇧⌘W) │ Place Embedded…
- **Edit:** Undo ⌘Z · Redo ⇧⌘Z │ Cut ⌘X · Copy ⌘C · Copy Merged ⇧⌘C · Paste ⌘V · Clear │ Fill… ⇧F5 · Stroke… · Content-Aware Fill… │ Free Transform ⌘T · Transform ▸ (Distort │ Flip Horizontal · Flip Vertical) │ Keyboard Shortcuts… ⌥⇧⌘K
- **Image:** Adjustments ▸ (Levels… ⌘L · Curves… ⌘M · Exposure… │ Hue/Saturation… ⌘U · Color Balance… ⌘B · Black & White… ⌥⇧⌘B │ Invert ⌘I · Gradient Map… │ Grain…) │ Image Size… ⌥⌘I · Canvas Size… ⌥⌘C · Image Rotation ▸ (180° · 90° Clockwise · 90° Counter Clockwise │ Flip Canvas Horizontal · Flip Canvas Vertical) · Trim…
- **Layer:** New ▸ (Layer… ⇧⌘N │ Group… · Group from Layers… │ Layer Via Copy ⌘J) · Duplicate Layer… · Delete ▸ Layer │ Rename Layer… · Layer Style ▸ (Blending Options… │ Stroke… · Inner Shadow… · Inner Glow… · Color Overlay… · Outer Glow… · Drop Shadow… │ Copy Layer Style · Paste Layer Style · Clear Layer Style) │ New Adjustment Layer ▸ (Grain… │ Levels… · Curves… · Exposure… │ Hue/Saturation… · Color Balance… · Black & White… │ Invert · Gradient Map… │ Gaussian Blur… · Motion Blur… · Add Noise…) · Layer Content Options… │ Layer Mask ▸ (Reveal All · Hide All · Reveal Selection · Hide Selection │ Delete · Apply) · Create Clipping Mask ⌥⌘G · Remove Background │ Rasterize (in progress, TASK-32) · Convert to Editable Vectors (in progress, TASK-35) │ Group Layers ⌘G · Ungroup Layers ⇧⌘G · Hide Layers ⌘, · Hide All Other Layers │ Arrange ▸ (Bring Forward ⌘] · Send Backward ⌘[ │ Move Out of Group) · Combine Shapes ▸ (in progress, TASK-34) · Release to Layers (in progress, TASK-34) │ Align ▸ (Top Edges · Vertical Centers · Bottom Edges │ Left Edges · Horizontal Centers · Right Edges) · Distribute ▸ (Vertical Centers · Horizontal Centers │ Horizontally · Vertically) │ Merge Down ⌘E (Merge Layers with several selected) · Merge Visible ⇧⌘E · Flatten Image
- **Type:** Panels ▸ (Character · Paragraph), both opening Properties
- **Select:** All ⌘A · Deselect ⌘D · Inverse ⇧⌘I │ Color Range… · Subject │ Modify ▸ (Expand… · Contract… · Feather… ⇧F6) │ Load Selection…
- **Filter:** Last Filter ⌃⌘F │ Camera Raw Filter… ⇧⌘A · Lens Correction… ⇧⌘R · Liquify… ⇧⌘X │ Blur ▸ (Gaussian Blur… · Motion Blur…) · Noise ▸ Add Noise… · Pixelate ▸ Dither… · Render ▸ Vignette… · Sharpen ▸ (Unsharp Mask… │ Tonal Contrast…) · Stylize ▸ Bloom / Glow… · Other ▸ High Pass…
- **View:** Zoom In ⌘+ · Zoom Out ⌘− · Fit on Screen ⌘0 · 100% ⌘1 │ Extras ⌘H · Show ▸ (Grid ⌘' · Guides ⌘; · Pixel Grid) │ Rulers ⌘R │ Snap ⇧⌘; · Snap To ▸ (Guides · Grid · Layers · Document Bounds) │ Guides ▸ (Lock Guides ⌥⌘; · Clear Guides) │ Grid Settings…
- **Window:** Workspace ▸ (Essentials (Default) │ Reset Essentials) │ Adjustments · History · Layers · Properties │ Contextual Task Bar (in progress, TASK-67) │ open documents. The Workspace submenu and the panel items are shipping (TASK-58), after the system's Minimize, Zoom and Bring All to Front.
- **Help:** Search

### Shortcut changes

What changes from the shortcuts Lamina shipped before m-5 (applied by TASK-62; custom shortcuts people set carry over):

| Command | Before | After |
| --- | --- | --- |
| Filter ▸ Last Filter | ⌘F | ⌃⌘F |
| Layer ▸ Merge Visible | none | ⇧⌘E |
| File ▸ Export ▸ Quick Export as PNG (was Export PNG…) | ⇧⌘E | none |
| File ▸ Export ▸ Export As… | none | ⌥⇧⌘W (Export JPEG… and its ⌥⇧⌘S fold into it) |
| Select ▸ Subject | ⌥⌘A | none |
| View ▸ Extras | none | ⌘H (Show Transform Controls becomes a Move bar checkbox only; ⌘H left it with TASK-56) |
| Edit ▸ Free Transform (was Layer ▸ Transform Layer / Transform Selection) | ⌘T | ⌘T (shipping, TASK-56) |
| Hide Lamina | none | ⌃⌘H |
| Edit ▸ Fill… | none | ⇧F5, also ⇧⌫ |
| Edit ▸ Content-Aware Fill… | ⇧⌫ | none |
| Color Balance… / Black & White… | none | ⌘B / ⌥⇧⌘B |
| Camera Raw Filter… / Lens Correction… / Liquify… | none | ⇧⌘A / ⇧⌘R / ⇧⌘X (Liquify… shipped with TASK-54, at the top of the Filter menu until TASK-62 orders it) |
| Select ▸ Modify ▸ Feather… | none | ⇧F6 |
| Layer ▸ Hide Layers | none | ⌘, |
| Edit ▸ Keyboard Shortcuts… | none | ⌥⇧⌘K |
| Lamina ▸ Settings… | none (no Settings window) | ⌘K (shipping, TASK-51) |
| File ▸ Save a Copy… / Pen Tool | none | ⌥⌘S / P (shipping as placeholders, TASK-53) |
| Tools (shipped with TASK-54) | B with Tab cycling modes, R for Smear | E Eraser, O Dodge and Burn, R Blur and Smudge, Shift plus key cycles a slot; Tab does nothing on the canvas |

### Dialogs

- Settings on the left; OK (default), Cancel, any extra buttons (Auto, Reset) and the Preview checkbox stacked in a
  100 pt column on the right, 18 pt from the settings, inside 20 pt margins. This applies to adjustment, filter,
  selection (Expand, Contract, Feather, Color Range, Load Selection), Stroke, Fill, Trim, Canvas Size and Layer Style
  dialogs. **Shipping** (TASK-63) for Levels, Curves, Hue/Saturation, Exposure, Black & White, Color Balance, Gradient
  Map, Grain, every Filter menu dialog, Color Range, Expand, Contract, Feather, Stroke, Trim and Canvas Size, and for
  Layer Style (TASK-64).
- Image Size puts Cancel and OK in a row at the bottom right (**shipping**, TASK-63); New Document and Export As follow
  (TASK-65).
- One layout in code: `DialogLayout` (`Sources/LaminaApp/UI/DialogLayout.swift`) takes the settings, `confirm` and
  `cancel`, and optionally `extras` (column buttons and controls), a `preview` binding, a `status` line ("Applying…"
  with a spinner), a `title` heading for dialogs shown as sheets (which have no title bar), `defaultTitle` and
  `placement: .bottom`. `DialogButton` is a column-wide button, `DialogRow` a right-aligned "Label:" row and
  `DialogGroup` a titled group box; `DialogPreviewToggle` is the Preview checkbox, for a dialog that puts it in its
  extras with something under it (Layer Style's swatch). Floating panels (adjustments, filters, Color Range, Expand/Contract/Feather) and
  window sheets (Stroke, Trim, Canvas Size, Image Size) keep their presentation and share the layout.
- Column contents, top to bottom: Levels has OK, Cancel, Auto (click for Contrast; its menu has Color and Color +
  neutral midtones), Reset, the black, gray and white point eyedroppers, Preview. Curves has OK, Cancel, Reset, Preview.
  Hue/Saturation has OK, Cancel, Reset, Preview. Color Range has OK, Cancel, the Sample, Add and Remove eyedroppers,
  Invert (no Preview: the selection always updates). Filters have OK, Cancel, Preview; Remove Background and
  Content-Aware Fill keep a status line there while their preview is worked out. Stroke, Trim, Canvas Size and
  Expand/Contract/Feather have OK and Cancel.
- Filter dialogs share one frame (`FilterPreview`): a 340 × 220 preview of the layer, with zoom out, the percentage and
  zoom in under it (6.25% to 1600%, starting at 100% of the layer's pixels, centered on the selection or the layer),
  then the settings, each slider paired with a field and its unit ("Pixels", "%", "°", "levels") in a column of its own.
  Dragging the preview pans it; while the mouse is down it shows the layer before the filter. It crops the image the
  canvas previews, so it costs no extra rendering (on layers longer than 2048 px that preview is reduced, so 100% is
  enlarged from it), and it keeps rendering when the canvas Preview is off. Image adjustments (Image ▸ Adjustments)
  have no preview frame, as in Photoshop. Adjustment layers have no dialog: they are edited in Properties, with the
  same controls.
- Camera Raw Filter is the exception: its full-height panel stays docked to the window's right edge, with Preview and
  then Cancel and OK at the bottom right. Its histogram well has an `edge` border.
- Labels end with a colon and sit right-aligned before their control ("Width:", "Radius:"), or above a slider in
  Hue/Saturation and Color Range ("Fuzziness:"), as in Photoshop. Groups of settings sit in titled boxes ("Stroke",
  "Location", "Blending", "Based On", "Trim Away", "Current Size: 13.7 MB", "New Size: 13.7 MB"). Familiar settings come
  first, Lamina-only ones after them (Hue/Saturation's Apply outside this range instead, Canvas Size's Lock original
  aspect ratio, explanatory notes).
- Selection dialogs name their one setting as Photoshop does: Expand By:, Contract By:, Feather Radius:, in pixels.
  Stroke has Width (px) and Color (Foreground Color or Background Color) under Stroke, Inside, Center and Outside under
  Location, and Opacity (%) under Blending. Canvas Size's units menu sits beside both Width and Height and changes
  both; Image Size's Constrain aspect ratio is a link toggle between Width and Height.
- Layer Style is one dialog (**shipping**, TASK-64; `LayerStyleDialog` in a floating panel, model in
  `Document/LayerStyle.swift`). On the left a 170 pt list: Blending Options, a separator, then Stroke, Inner Shadow,
  Inner Glow, Color Overlay, Outer Glow and Drop Shadow, each with a checkbox; the selected row is `selection`. In the
  middle the page's title and its settings in titled groups:
  - Blending Options: General Blending with Blend Mode (grouped as the Layers panel's menu) and Opacity, the layer's own.
  - Stroke: Structure with Size, Position (Outside, Inside), Opacity and Color.
  - Inner Shadow and Drop Shadow: Structure with Opacity, Angle, Distance, Size (the blur) and Color.
  - Inner Glow and Outer Glow: Structure with Opacity and Color, then Elements with Size.
  - Color Overlay: Color with Color and Opacity.

  Sliders pair with a field and a unit column (%, px, °); a typed value past the slider's end is kept. Angle is a
  28 pt dial (drag to point it at the light) and a field, -180° to 180°. Color is an `edge`-bordered well that opens
  the app's color picker, previewing as it changes. The column holds OK, Cancel, Preview and, under it, a 64 pt swatch:
  the style drawn on a gray square on white, its sizes scaled down when they would overflow. The dialog keeps one size
  whatever the page.
- In Layer Style, a checkbox turns its effect on (at the defaults: a new stroke or color overlay takes the background
  color) or off without changing the page; clicking an effect's name shows its page and turns it on, as Photoshop
  does, and so does opening the dialog on an effect (its menu item, the fx menu, a double-click on its row). Every
  change previews on the canvas; Preview off shows the layer as it was. OK applies everything as one "Layer Style"
  undo step (none when nothing changed); an effect turned on and off again in the dialog isn't kept, while one the
  layer already had and the dialog turned off stays, hidden, as its eye would leave it. Cancel or closing the panel
  puts the layer's effects, blend mode and opacity back exactly. While it is open other layer edits, Undo, saving and
  `lamina` edits wait ("The Layer Style dialog is open.").
- Return confirms, Escape cancels, ⌥P toggles Preview, and the canvas previews live while a dialog is open.

### Contextual Task Bar

A floating bar under the selection, active layer or transform box with the next likely actions: Select Subject and
Remove Background for a pixel layer; Modify Selection, Invert Selection, Create Mask, Fill Selection and Deselect for a
selection; rotate and flip while transforming. Status: **in progress (TASK-67)**, after m-5.

### In-progress placeholders

A feature with an open Backlog task shows its control where it will live. Using it (click, menu choice or tool key)
shows a non-blocking message over the top of the canvas, "*Name* is in progress", that goes away after a few seconds or
on the next click and is announced to VoiceOver. A placeholder looks like a shipping control (its help tag ends with
"In progress") and never changes the document, the selection or the active tool. Status: **shipping** (TASK-53).

| Placeholder | Where | Delivered by |
| --- | --- | --- |
| Pen Tool | toolbar, its own slot before Type, P | TASK-28 |
| Path Selection Tool, Direct Selection Tool | toolbar slot after Type, no key yet (A stays No Tool) | TASK-28 |
| Mixer Brush Tool | Brush flyout | TASK-47 |
| Palette Knife Tool | Brush flyout | TASK-50 |
| Polygon Tool, Star Tool | Shapes flyout | TASK-32 |
| Bristle presets: Flat Bristle, Round Bristle, Fan, Dry Brush | brush picker (until TASK-57, a Presets pop-up at the start of the Brush bar) | TASK-46 |
| Shape Stroke: the stroke swatch and width | shape tool bars | TASK-32 |
| Stroke Options, Path Operations | shape tool bars | TASK-34 |
| Save a Copy… ⌥⌘S | File, after Save As… | TASK-27 |
| Rasterize | Layer | TASK-32 |
| Convert to Editable Vectors | Layer | TASK-35 |
| Combine Shapes ▸ (Unite Shapes, Subtract Front Shape, Unite Shapes at Overlap, Subtract Shapes at Overlap), Release to Layers | Layer | TASK-34 |
| Contextual Task Bar | Window | TASK-67 |

How it works (`Sources/LaminaApp/Document/PlannedFeature.swift`):

- `PlannedFeature` is the registry: one case per name in this table, with its `name`, the `task` that delivers it and
  its `home` (`.toolbar`, `.menu("Layer › Rasterize")` or `.optionsBar(tools)`). `PlannedFeatureTests` checks every
  case against this table and that each one has a way in.
- Every placeholder calls `EditorSession.showInProgress(_:)` and nothing else. It sets `inProgressNotice` (one at a time:
  a new one replaces the one showing), which `InProgressNoticeView` (`UI/InProgressNoticeView.swift`) draws centered
  12 pt below the top of the canvas: 12 pt `text` in a `regularMaterial` capsule with an `edge` outline and a soft
  shadow, fading in and out, never taking clicks. It goes after 3 s (`InProgressNotice.duration`) or at the next mouse
  down anywhere in the app, which still goes where it was aimed. VoiceOver hears the message as an announcement.
- Planned tools are items of their toolbar slot: `ToolSlot.items` lists `SlotItem.tool` and `SlotItem.planned` entries
  in flyout order, while `ToolSlot.tools` keeps the tools that work. Pen and Path Selection are slots of their own with
  planned items only. Choosing a planned item (`EditorSession.choose(_:)`, from the toolbar, its key or Shift-cycling)
  shows its message and leaves the tool and the slot's last-used tool as they were. While the message shows, Shift and
  the slot's key step on from it, so Shift-U goes Rectangle, Ellipse, Polygon, Star, Line, and Shift-B Brush, Mixer
  Brush, Palette Knife, Brush.
- Help tags read "Pen Tool (P) · In progress", "Shape Stroke · In progress" (macOS shows none on menu items, so menu
  placeholders are told apart only by their message). Menu placeholders are `PlannedMenuItem`,
  bar controls `BristlePresetsMenu` and `ShapeStrokePlaceholders` (`UI/PlannedControls.swift`). Menu items without a
  default key take one in Keyboard Shortcuts like any other (`PlannedFeature.assignableMenuCommands`).

When a feature task with visible interface is created, add its row, its `PlannedFeature` case and its placeholder. When
the task ships, the real control replaces the placeholder and the row and case go. When a task is dropped, its
placeholder goes too.

## Accessibility and quality bar

- Every tool has a key, every command a menu item, and every menu item can take a shortcut in Keyboard Shortcuts.
- VoiceOver labels name the control as shown ("Brush Tool (B)", "Opacity, 100 percent"); icon-only buttons always have
  a label and a help tag.
- Text roles meet 4.5:1 contrast on their background in both appearances; icons meet 3:1.
- Hit targets are at least 22 × 22 pt; toolbar slots 32 × 30.
- Respect Reduce Motion (the marching ants stop animating), Reduce Transparency (floating surfaces turn opaque) and
  Increase Contrast.
- Return or Escape in a field hands focus back to the canvas, so tool keys work straight away.
- Tests that put windows in front carry the `.showsWindows` trait (AGENTS.md).

## Implementation notes for agents

- Read this file before touching the interface, and update it in the same commit as any interface change. Before
  finishing a task, compare what shipped with this file.
- Before adding a feature, decide where familiar editors put it and what they call it, then place it there. If they
  have no equivalent, use their vocabulary and the nearest place, and note the choice here.
- Use native controls and SF Symbols; take every custom color from a named role. The mockup
  ([references/redesign_v2.html](references/redesign_v2.html)) shows layout and contents, not pixels to copy; its HTML
  imitates controls that the app draws natively.
- The frame lives in `Sources/LaminaApp/ContentView.swift`, menus in `LaminaMain.swift`, tool bars in
  `Sources/LaminaApp/UI/*Controls.swift`, the dock in `UI/Dock.swift` and `UI/DockLayout.swift`, panels in
  `UI/PropertiesPanel.swift`, `UI/AdjustmentsPanel.swift`, `UI/LayersPanel.swift` and `UI/HistoryPanel.swift`, shortcuts in
  `UI/KeyboardShortcuts.swift` (`ShortcutDefinition.all`). Custom shortcuts for menu commands without a default are
  saved by menu title, so renaming an item means carrying its saved key over.
- `lamina` commands and the MCP server don't depend on menu names, but README, website and screenshots do
  (`brand/README.md`).

## Do's and don'ts

- **Do** put a command where switchers will look first, with the name they will look for.
- **Do** keep every region's size from this spec; check the window at 1500 × 860 pt in both appearances.
- **Do** show planned features as placeholders and remove the placeholder when the feature ships.
- **Do** update this file in the same commit as the interface change.
- **Don't** copy another product's visuals, icons, colors or wording beyond the established names of things.
- **Don't** hide a tool inside another tool's mode picker.
- **Don't** add title-bar buttons, floating adjustment panels or per-effect panels.
- **Don't** hard-code a gray, or force an appearance.
- **Don't** show disabled controls for features nobody plans to build.

## Closing note

Lamina earns trust in the first minute by being where people expect it to be, and keeps it by staying small, native and
quiet. Every change answers one question: would someone coming from their old editor find this without looking?
