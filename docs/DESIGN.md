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
| Title bar | 38 high | Traffic lights, New (+), document tabs. Nothing else. |
| Options bar | 36 high | The active tool's icon, then its settings (see [Options bars](#options-bars)). |
| Toolbar | 44 wide | One column of tool slots, colors at the bottom. |
| Canvas column | the rest | Pasteboard, the document centered on it, the status bar under it. |
| Status bar | 22 high, under the canvas only | Editable zoom field, document size and resolution, tool hint at the right. |
| Panel icon column | 34 wide | Collapsed panels: History. |
| Dock | 292 wide (240 to 360, resizable) | Properties \| Adjustments group (about 340 high) over the Layers group (the rest). |

Rules:

- At 1500 × 860 pt nothing is clipped and nothing scrolls except panel contents. The canvas keeps at least
  1100 × 740 pt.
- Document tabs read `Golden Hour @ 44.5% (Golden hour, RGB/8)`: name, zoom, active layer, mode and depth. Long names
  truncate in the middle.
- Fit, 100% and zoom buttons do not live in the title bar. Zoom lives in View, the status bar and the Hand and Zoom bars.
- The canvas starts 36 pt below the title bar for every tool. Switching tools never moves the canvas.

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
  and points; image previews in dialogs (Export, Camera Raw develop) sit on `pasteboard`; swatch and well borders are
  `edge`; pressed mode buttons in dialogs and options bars are `activeTool`; selected history states and effect rows
  are `selection`.
- Until the frame is rebuilt (TASK-52, TASK-55, TASK-58), the bars, tool rail and status bar sit on `chrome`, the side
  panels on `panel`, and the active document tab is a `control` capsule with an `edge` outline.
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
- Sizes: 18 pt in toolbar slots, 16 pt in options bars and menus, 15 pt in panels and footers.
- Icons take the `icon` role; the active tool's icon takes `text`. No colored icons except the color swatches.
- A slot whose group has more than one tool shows a small triangle in its bottom-right corner.

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
| Dodge / Burn | custom paddle / custom cupped hand |
| Horizontal Type | a serif "T" (not "Aa") |
| Rectangle / Ellipse / Line | `rectangle.fill` / `oval.fill` / `line.diagonal` |
| Hand / Zoom | `hand.raised` / `magnifyingglass` |
| History panel | `clock.arrow.circlepath` |

## Elevation and depth

Chrome is flat: regions sit side by side, separated by `edge` lines. Only transient things float, and they float with
the system's materials and shadows: menus, tool flyouts, pop-overs (brush picker, sliders), the in-progress message,
the Contextual Task Bar and dialogs. Nothing in the chrome uses gradients, glows or inner shadows.

## Components

### Toolbar

One column, top to bottom. A slot shows the last tool used from its group; holding the mouse on a slot or right-clicking
it opens a flyout listing the group's tools with icon, name and key. Shift plus a tool's key cycles its group. Help tags
and accessibility labels read "Tool name (Key)". Status: **m-5** (TASK-54 splits the tools, TASK-55 builds the toolbar).

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
Strength, then Cancel and Done). Tools familiar editors have and Lamina has no task for (Artboard, Frame, Quick
Selection, Healing Brush, History Brush, Sponge and so on) don't appear.

### Options bars

Each bar starts with the active tool's icon, then groups separated by 1 × 20 pt dividers (│ below). Controls: icon
buttons 24 × 22, pop-ups and fields 22 high, percent fields with a slider pop-up. Edits in progress end with Cancel and
Commit icon buttons at the far right. Status: **m-5** (TASK-56 for Move and Free Transform, TASK-57 for the rest).

| Tool | Bar, left to right |
| --- | --- |
| Move | Auto-Select ☐ · Show Transform Controls ☑ │ Align Left, Horizontal Centers, Right · Distribute Vertically · Align Top, Vertical Centers, Bottom · Distribute Horizontally (dimmed below two layers) · ••• Align & Distribute menu |
| Free Transform (while transforming) | Reference point │ X · Y │ W % · link · H % │ angle │ Interpolation: Nearest Neighbor, Bilinear, Bicubic │ … Cancel · Commit |
| Rectangular / Elliptical Marquee | New, Add, Subtract selection icons │ Feather: 0 px (for the next selection) · Anti-alias (dimmed for rectangles) |
| Lasso / Polygonal Lasso | selection icons │ Feather · Anti-alias |
| Object Selection | selection icons │ Sample All Layers · Edge (Lamina) │ Select Subject |
| Magic Wand | selection icons │ Sample Size · Tolerance · Anti-alias · Contiguous · Sample All Layers │ Select Subject |
| Crop | Ratio (Ratio, Original Ratio, 1:1 (Square), 4:3, 16:9, …) · W ⇄ H · Clear │ … Cancel · Commit |
| Eyedropper | Show Sampling Ring |
| Spot Healing Brush | brush picker │ Type: Content-Aware \| Create Texture \| Proximity Match │ pressure for size |
| Brush | brush picker (Size, Hardness; bristle presets in progress, TASK-46) │ Opacity · pressure for opacity · Flow │ Smoothing │ pressure for size |
| Clone Stamp | brush picker │ Opacity · pressure for opacity │ Aligned · Sample: Current Layer, All Layers │ pressure for size |
| Eraser | brush picker │ Opacity · pressure for opacity · Flow · Smoothing │ pressure for size |
| Gradient | gradient preset picker · Linear, Radial │ Opacity · Reverse |
| Paint Bucket | Fill: Foreground │ Opacity · Tolerance · Anti-alias · Contiguous · All Layers |
| Blur / Smudge | brush picker │ Strength · Radius (Blur only, Lamina) │ pressure for size |
| Dodge / Burn | brush picker │ Range: Shadows, Midtones, Highlights · Exposure │ pressure for size |
| Horizontal Type | font family · font style · size │ Left, Center, Right · color · Character panel │ … Cancel · Commit |
| Rectangle / Ellipse / Line | Fill swatch · Stroke swatch and width (in progress, TASK-32) · stroke options (in progress, TASK-34) │ path operations (in progress, TASK-34) │ Radius (Rectangle) or Weight (Line) |
| Hand | 100% · Fit Screen · Fill Screen |
| Zoom | Zoom In, Zoom Out │ Scrubby Zoom │ 100% · Fit Screen · Fill Screen |

The painting bars carry no color swatch: color comes from the toolbar's swatches, black and white for masks included.

### Dock and panels

Tab groups with a 26 pt tab row and a panel menu (≡) at the right; the active tab is `text` with an underline.
Status: **m-5** (TASK-58).

- **Properties** shows what is selected (TASK-59):

  | Selection | Sections |
  | --- | --- |
  | Nothing (document) | Canvas (W, H, resolution) · Rulers & Grids (units, grid, guides, rulers) · Quick Actions: Image Size, Crop, Trim, Rotate |
  | Pixel layer | Transform (W, H, X, Y, angle, flips) · Align and Distribute · Interpolation (Lamina's per-layer sampling) · Quick Actions: Remove Background, Select Subject |
  | Type layer | Transform · Character (family, style, size, leading, tracking, color) · Paragraph (alignment) |
  | Group | Transform · Align and Distribute |
  | Adjustment layer | the adjustment's controls, live, with a footer: clip to layer, reset, visibility, delete |
  | Layer mask | Refine: Color Range…, Invert · footer: load selection from mask, apply, delete |

- **Adjustments** (TASK-60): a grid of labeled icons that add an adjustment layer in one click, in this order: Grain,
  Levels, Curves, Exposure, Hue/Saturation, Color Balance, Black & White, Invert, Gradient Map; then a "Filter layers"
  section (Lamina): Gaussian Blur, Motion Blur, Add Noise.
- **Layers** (TASK-61): blend mode menu and Opacity on top; one-line 32 pt rows (eye, thumbnail, link, mask thumbnail,
  name, fx badge); clicking the layer or mask thumbnail picks what edits target; styled layers list an "Effects" row and
  one 22 pt row per effect, each with an eye. Footer, left to right: Add a layer style (menu: Blending Options…, Stroke,
  Inner Shadow, Inner Glow, Color Overlay, Outer Glow, Drop Shadow), Add layer mask, New fill or adjustment layer, New
  group, New layer, Delete.
- **History** lives in the panel icon column and opens beside the dock.

### Menus

Separators are shown as │. Items not listed don't exist. Status: **m-5** (TASK-62).

- **Lamina:** About Lamina · Check for Updates… │ Settings… ⌘K │ Services ▸ │ Hide Lamina ⌃⌘H · Hide Others ⌥⌘H · Show All │ Quit Lamina ⌘Q
- **File:** New… ⌘N · New from Clipboard ⌥⌘N · Open… ⌘O · Open Recent ▸ │ Close ⌘W │ Save ⌘S · Save As… ⇧⌘S · Save a Copy… ⌥⌘S (in progress: layered Photoshop files, TASK-27) │ Export ▸ (Quick Export as PNG │ Export As… ⌥⇧⌘W) │ Place Embedded…
- **Edit:** Undo ⌘Z · Redo ⇧⌘Z │ Cut ⌘X · Copy ⌘C · Copy Merged ⇧⌘C · Paste ⌘V · Clear │ Fill… ⇧F5 · Stroke… · Content-Aware Fill… │ Free Transform ⌘T · Transform ▸ (Distort │ Flip Horizontal · Flip Vertical) │ Keyboard Shortcuts… ⌥⇧⌘K
- **Image:** Adjustments ▸ (Levels… ⌘L · Curves… ⌘M · Exposure… │ Hue/Saturation… ⌘U · Color Balance… ⌘B · Black & White… ⌥⇧⌘B │ Invert ⌘I · Gradient Map… │ Grain…) │ Image Size… ⌥⌘I · Canvas Size… ⌥⌘C · Image Rotation ▸ (180° · 90° Clockwise · 90° Counter Clockwise │ Flip Canvas Horizontal · Flip Canvas Vertical) · Trim…
- **Layer:** New ▸ (Layer… ⇧⌘N │ Group… · Group from Layers… │ Layer Via Copy ⌘J) · Duplicate Layer… · Delete ▸ Layer │ Rename Layer… · Layer Style ▸ (Blending Options… │ Stroke… · Inner Shadow… · Inner Glow… · Color Overlay… · Outer Glow… · Drop Shadow… │ Copy Layer Style · Paste Layer Style · Clear Layer Style) │ New Adjustment Layer ▸ (Grain… │ Levels… · Curves… · Exposure… │ Hue/Saturation… · Color Balance… · Black & White… │ Invert · Gradient Map… │ Gaussian Blur… · Motion Blur… · Add Noise…) · Layer Content Options… │ Layer Mask ▸ (Reveal All · Hide All · Reveal Selection · Hide Selection │ Delete · Apply) · Create Clipping Mask ⌥⌘G · Remove Background │ Rasterize (in progress, TASK-32) · Convert to Editable Vectors (in progress, TASK-35) │ Group Layers ⌘G · Ungroup Layers ⇧⌘G · Hide Layers ⌘, · Hide All Other Layers │ Arrange ▸ (Bring Forward ⌘] · Send Backward ⌘[ │ Move Out of Group) · Combine Shapes ▸ (in progress, TASK-34) · Release to Layers (in progress, TASK-34) │ Align ▸ (Top Edges · Vertical Centers · Bottom Edges │ Left Edges · Horizontal Centers · Right Edges) · Distribute ▸ (Vertical Centers · Horizontal Centers │ Horizontally · Vertically) │ Merge Down ⌘E (Merge Layers with several selected) · Merge Visible ⇧⌘E · Flatten Image
- **Type:** Panels ▸ (Character · Paragraph), both opening Properties
- **Select:** All ⌘A · Deselect ⌘D · Inverse ⇧⌘I │ Color Range… · Subject │ Modify ▸ (Expand… · Contract… · Feather… ⇧F6) │ Load Selection…
- **Filter:** Last Filter ⌃⌘F │ Camera Raw Filter… ⇧⌘A · Lens Correction… ⇧⌘R · Liquify… ⇧⌘X │ Blur ▸ (Gaussian Blur… · Motion Blur…) · Noise ▸ Add Noise… · Pixelate ▸ Dither… · Render ▸ Vignette… · Sharpen ▸ (Unsharp Mask… │ Tonal Contrast…) · Stylize ▸ Bloom / Glow… · Other ▸ High Pass…
- **View:** Zoom In ⌘+ · Zoom Out ⌘− · Fit on Screen ⌘0 · 100% ⌘1 │ Extras ⌘H · Show ▸ (Grid ⌘' · Guides ⌘; · Pixel Grid) │ Rulers ⌘R │ Snap ⇧⌘; · Snap To ▸ (Guides · Grid · Layers · Document Bounds) │ Guides ▸ (Lock Guides ⌥⌘; · Clear Guides) │ Grid Settings…
- **Window:** Workspace ▸ (Essentials (Default) │ Reset Essentials) │ Adjustments · History · Layers · Properties │ Contextual Task Bar (in progress, TASK-67) │ open documents
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
| View ▸ Extras | none | ⌘H (Show Transform Controls becomes a Move bar checkbox only) |
| Hide Lamina | none | ⌃⌘H |
| Edit ▸ Fill… | none | ⇧F5, also ⇧⌫ |
| Edit ▸ Content-Aware Fill… | ⇧⌫ | none |
| Color Balance… / Black & White… | none | ⌘B / ⌥⇧⌘B |
| Camera Raw Filter… / Lens Correction… / Liquify… | none | ⇧⌘A / ⇧⌘R / ⇧⌘X |
| Select ▸ Modify ▸ Feather… | none | ⇧F6 |
| Layer ▸ Hide Layers | none | ⌘, |
| Edit ▸ Keyboard Shortcuts… | none | ⌥⇧⌘K |
| Lamina ▸ Settings… | none (no Settings window) | ⌘K (shipping, TASK-51) |
| Tools | B with Tab cycling modes, R for Smear | E Eraser, O Dodge and Burn, R Blur and Smudge, Shift plus key cycles a slot |

### Dialogs

- Settings on the left; OK (default), Cancel, any extra buttons (Auto, Reset) and the Preview checkbox stacked in a
  100 pt column on the right. This applies to adjustment, filter, selection (Expand, Contract, Feather, Color Range,
  Load Selection), Stroke, Fill, Trim, Canvas Size and Layer Style dialogs. Status: **m-5** (TASK-63).
- Image Size, New Document and Export As put Cancel and the default button in a row at the bottom right (TASK-65).
- Filter dialogs share one frame: a preview with zoom out, percentage and zoom in, then the settings, each slider paired
  with a field.
- Groups of settings sit in titled boxes ("Structure", "Blending", "Location"). Familiar settings come first, Lamina-only
  ones after them.
- Layer Style is one dialog: effects listed on the left with checkboxes, the selected effect's settings in the middle,
  buttons and a preview swatch on the right (TASK-64).
- Return confirms, Escape cancels, and the canvas previews live while a dialog is open.

### Contextual Task Bar

A floating bar under the selection, active layer or transform box with the next likely actions: Select Subject and
Remove Background for a pixel layer; Modify Selection, Invert Selection, Create Mask, Fill Selection and Deselect for a
selection; rotate and flip while transforming. Status: **in progress (TASK-67)**, after m-5.

### In-progress placeholders

A feature with an open Backlog task shows its control where it will live. Using it (click, menu choice or tool key)
shows a non-blocking message over the top of the canvas, "*Name* is in progress", that goes away after a few seconds or
on the next click and is announced to VoiceOver. A placeholder looks like a shipping control (its help tag ends with
"In progress") and never changes the document, the selection or the active tool. TASK-53 builds the message and the
registry.

| Placeholder | Where | Delivered by |
| --- | --- | --- |
| Pen Tool | toolbar, P | TASK-28 |
| Path Selection Tool, Direct Selection Tool | toolbar slot after Type | TASK-28 |
| Mixer Brush Tool | Brush flyout | TASK-47 |
| Palette Knife Tool | Brush flyout | TASK-50 |
| Polygon Tool, Star Tool | Shapes flyout | TASK-32 |
| Bristle presets (Flat Bristle, Round Bristle, Fan, Dry Brush) | brush picker | TASK-46 |
| Stroke swatch and width | shape tool bars | TASK-32 |
| Stroke options, path operations | shape tool bars | TASK-34 |
| Save a Copy… | File | TASK-27 |
| Rasterize | Layer | TASK-32 |
| Convert to Editable Vectors | Layer | TASK-35 |
| Combine Shapes ▸, Release to Layers | Layer | TASK-34 |
| Contextual Task Bar | Window | TASK-67 |

When a feature task with visible interface is created, add its row and its placeholder. When the task ships, the real
control replaces the placeholder and the row goes. When a task is dropped, its placeholder goes too.

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
  `Sources/LaminaApp/UI/*Controls.swift`, panels in `UI/LayersPanel.swift` and `UI/HistoryPanel.swift`, shortcuts in
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
