---
id: TASK-62
title: 'Menus in the familiar structure, names and shortcuts'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 07:29'
labels: []
milestone: m-5
dependencies:
  - TASK-54
  - TASK-56
  - TASK-53
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina's menus hold the right commands in unfamiliar places: adjustments directly in Image, Free Transform and Flip in Layer, Expand, Contract and Feather loose in Select, two Snap toggles in View, and some shortcuts that familiar editors use differently (⌘F, ⇧⌘E, ⌥⌘A, ⌘H, ⇧⌫). docs/DESIGN.md has the menu tree and the shortcut changes. Custom shortcuts for menu commands without a default are saved by menu title (KeyboardShortcuts.swift), so renamed items need their saved keys carried over.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The menu bar matches docs/DESIGN.md: menus, items, order, separators, submenus and names, including its in-progress placeholders
- [x] #2 The shortcut changes in docs/DESIGN.md apply, the Keyboard Shortcuts window shows them, and no two commands share a key
- [x] #3 Shortcuts people customized for renamed or moved items carry over after the update
- [x] #4 Edit ▸ Fill… (⇧F5, and ⇧⌫) opens a Fill dialog over the existing fills, while ⌥⌫ and ⌘⌫ still fill directly
- [x] #5 Select ▸ Load Selection… opens a dialog that replaces Layer's Pixels and Mask's Black Areas
- [x] #6 View has one Snap toggle and an Extras toggle (⌘H) for grid, guides and selection edges, and Window lists the panels and Workspace
- [x] #7 Tests cover the shortcut changes, the carried-over custom shortcuts and the two new dialogs
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Menus (LaminaMain.swift): rebuild every menu to DESIGN.md's tree and menu-bar order (Lamina, File, Edit, Image, Layer, Type, Select, Filter, View, Window, Help), with its names, submenus, separators and placeholders; Remove Background moves to Layer; View built as a CommandMenu after Filter; Help keeps only Search.
2. Shortcuts (UI/KeyboardShortcuts.swift): apply the Shortcut changes table (⌃⌘F, ⇧⌘E, ⌥⌘A freed, ⌘H Extras, ⌃⌘H Hide, ⇧F5 Fill with ⇧⌫ as a second key, ⌘B, ⌥⇧⌘B, ⇧⌘A, ⇧⌘R, ⇧F6, ⌘, Hide Layers, ⌥⇧⌘K, ⌥⇧⌘W); function keys in ShortcutChord; ⌘, no longer reserved; renamed entries and every moved or renamed More Menu Commands title carried over through renamedIDs (resolved transitively, a key saved under the current id wins); ⌥⌫/⌘⌫ become window-wide keys without menu items.
3. Edit > Fill...: FillContents/FillOptions and EditorSession.fill (foreground, background, color, black, 50% gray, white, opacity; Content-Aware opens today's Content-Aware Fill); FillDialog in DialogLayout, a floating panel like the selection dialogs.
4. Select > Load Selection...: channels (each layer's Transparency, each mask as a document-sized channel), Invert, New/Add/Subtract; LoadSelectionDialog in DialogLayout; replaces Layer's Pixels and Mask's Black Areas.
5. View: one Snap (snapEnabled, saved as 'snap'; the session-only snappingEnabled folds into it); Extras (saved as 'extras') hides grid, guides, pixel grid and selection edges and turning one of them on shows Extras again.
6. Layer commands the new names need: Layer Mask submenu items, Hide Layers for the selected layers, Delete > Layer, New > Layer.../Group.../Group from Layers... and Duplicate Layer... open the new layer's name for editing.
7. Tests: shortcut changes and collisions, carried-over custom keys, Fill (each content kind, opacity, mask), Load Selection (transparency, mask, invert, operations), Extras, Snap.
8. DESIGN.md, README facts (Last Filter key), brand/README step names; Accessibility dump of the menu bar, screenshots of both dialogs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation (rebased onto main after TASK-59/60/61 landed):
- Menus: `LaminaMain.swift` now has one `Commands` per menu (App, File, Edit, Image, Layer, Type, Select, Filter, View) plus `DockCommands`; the shared layout lives in `FilterKind.filterMenu`, `AdjustmentKind.menuSections`, `LayerAlignment.menuSections`, `LayerDistribution.menuSections` (Keyboard Shortcuts reads the same). Layer Content Options… calls TASK-59's `session.showProperties()`; Type › Panels › Character/Paragraph do too.
- `UI/MenuBarOrder.swift` (installed in `applicationWillFinishLaunching`): SwiftUI always puts `CommandMenu`s after the system View menu, so View is a `CommandMenu` after Filter and the emptied system View menu (only Enter Full Screen left) is removed. Curves lost ⌘M to the system Minimize once it moved into Image › Adjustments (SwiftUI resolves duplicate keys in favour of the top-level item), so `.windowSize` is replaced by Lamina's own Minimize and Zoom without keys, and MenuBarOrder keeps them first in Window, above AppKit's tiling items. Both checks run (coalesced, async) whenever an item is added to the main menu or a top-level menu.
- Shortcuts (`UI/KeyboardShortcuts.swift`): Menus entries renamed to the new names (New, Open, Close, Fit on Screen, 100%, New Layer, Layer Via Copy, Bring Forward, Send Backward, Merge Down, Invert) and new defaults per the Shortcut changes table; ⌘, no longer reserved; F1–F12 supported (label, recording, synthesized events). ⌥⌫/⌘⌫ (fill from the swatches) and ⇧⌫ (Fill…'s second key) became Canvas & Layers entries handled by `CanvasView`'s window-wide key monitor (`handleFillKey`), outside text fields.
- Carry-over: `ShortcutSettings.renamedIDs` maps every renamed or moved entry (both Menus and More Menu Commands ids, every filter into its category submenu) and `currentID(_:)` follows chains. On load a key saved under the current id wins over a carried one, and among old ids the first in sorted order wins (Layer's Pixels over Mask's Black Areas for Load Selection…). A carried key that collides with a new default (e.g. a re-recorded ⇧⌘E for Export PNG vs Merge Visible) drops alone, as other refused overrides do.
- Snap merge: the session-only `snappingEnabled` (View's first Snap, moves/resizes/crops/marquees, reset to on every launch) folded into the saved `snapEnabled` ("snap", View's master switch that gated the Snap To targets and guide snapping). Since the first was always on at launch, behaviour at launch is unchanged and saved preferences keep working. Its old assignable key ("View › Snap") carries to the one Snap.
- Extras: `showsExtras` saved as "extras" (default on); `gridVisible`, `guidesVisible`, `pixelGridVisible`, `selectionEdgesVisible` gate drawing, the marching-ants timer, snapping to grid/guides and guide hit-testing. Show ▸ checkmarks stay each extra's own setting. Turning Grid, Guides or Pixel Grid on, adding a guide, or Grid Settings… turns Extras on (Photoshop does the same). I included the pixel grid because it sits in View › Show beside Grid and Guides and Photoshop's Extras hides it too (DESIGN.md says so).
- Fill (`Document/Fill.swift`, `UI/FillSheet.swift`) and Load Selection (`Document/LoadSelection.swift`, `UI/LoadSelectionSheet.swift`) are DialogLayout floating panels driven by `EditorSession.commandDialog`, which joins the edit/history/project gates and `busyReason`. Fill: Foreground/Background/Color…/Content-Aware/Black/50% Gray/White + Opacity; Content-Aware closes Fill and opens today's Content-Aware Fill (dimmed without a selection on pixels); masks fill with a color's brightness in DeviceGray (CGColor(gray:) was colour-matched off 128). Load Selection: each layer's Transparency and each Mask, top first, starting on the active layer's; a mask is a canvas-wide channel (its edge value beyond its pixels), computed as the traced outline or its complement in one boolean step (clipping first then complementing left a zero-area sliver with a non-empty bounding box), so inverting a reveal-all mask is exactly Mask's Black Areas (a test compares the coverage pixel for pixel).
- Decisions recorded in DESIGN.md: Remove Background… keeps its ellipsis (it is a dialog in Lamina); New › Layer…, Group…, Group from Layers… and Duplicate Layer… open the new layer's name for editing (Lamina has no such dialogs); Delete › Layer deletes layers only; Open Recent's Clear Menu became Clear Recent File List (mockup); Help keeps only Search (no help book); Load Selection's Operation group is disabled as a whole without a selection, because per-item `.disabled` doesn't take in SwiftUI radio-group pickers; Layer Mask › keeps the spec's six items (Lamina's Disable stays in the row menu).
- README: Last Filter's key fixed (⌃⌘F); brand/README's curves step says Layer › Layer Content Options…. The wider README, website and screenshot update for the new menus is TASK-66's.

Verification:
- `swift test`: 785 tests in 114 suites, 47 in 7 and 22 in 3, all passing after the rebase. New suites: FillTests, LoadSelectionTests, MenuCommandTests; KeyboardShortcutTests (shortcutChangesApply, functionKeysWorkAsShortcuts, customKeysOfRenamedAndMovedCommandsCarryOver, carriedKeysGiveWayToCurrentOnesAndNewDefaults, everyRenamedEntryLeadsToACommand, fillKeysTakeCustomShortcutsWithoutMenuItems); GuideTests (one Snap, Extras with guides and grid snapping); LastFilterTests (⌃⌘F). Each of the three feature commits was checked out and built on its own.
- Visual: `make dev`, launched with `open -g -n -a` on the demo project, menus read through Accessibility (AXMenuBar walk, no synthetic events), dialogs opened with AXPress on their menu items and captured with `screencapture -l` (the panels are off screen while the app is in the background, but capture fine): backlog/assets/task-62/fill-dark.png, fill-light.png, load-selection-dark.png, load-selection-light.png. The Dev app's `appearance` default was set to light for two captures and deleted afterwards.
- Not verifiable without synthetic key events: that ⇧F5, ⇧⌫, ⌃⌘F, ⌘M and ⌘H fire their items (the AX dump shows the key equivalents on the right items, and submenu key equivalents already worked before, e.g. View › Show › Grid ⌘'), the Help menu's Search field (AX lists no children for an unopened Help menu), and the Window reorder on a first open of that menu (AX-triggered insertion was reordered within a second).

Accessibility dump of the menu bar (Lamina Dev, rebased build 487; system items macOS adds — Services, Quit and Keep Windows, Writing Tools, AutoFill, Dictation, Emoji & Symbols, window tiling, Bring All to Front — left out):
- Lamina Dev: About Lamina Dev · Check for Updates… │ Settings… [⌘K] │ Hide Lamina [⌃⌘H] · Hide Others [⌥⌘H] · Show All │ Quit Lamina Dev [⌘Q]
- File: New… [⌘N] · New from Clipboard [⌥⌘N] · Open… [⌘O] · Open Recent ▸ (Golden Hour │ Clear Recent File List) │ Close [⌘W] │ Save [⌘S] · Save As… [⇧⌘S] · Save a Copy… [⌥⌘S] │ Export ▸ (Quick Export as PNG │ Export As… [⌥⇧⌘W] · Export JPEG… [⌥⇧⌘S]) │ Place Embedded…
- Edit: Undo [⌘Z] · Redo [⇧⌘Z] │ Cut [⌘X] · Copy [⌘C] · Copy Merged [⇧⌘C] · Paste [⌘V] · Clear │ Fill… [⇧F5] · Stroke… · Content-Aware Fill… │ Free Transform [⌘T] · Transform ▸ (Distort │ Flip Horizontal · Flip Vertical) │ Keyboard Shortcuts… [⌥⇧⌘K]
- Image: Adjustments ▸ (Levels… [⌘L] · Curves… [⌘M] · Exposure… │ Hue/Saturation… [⌘U] · Color Balance… [⌘B] · Black & White… [⌥⇧⌘B] │ Invert [⌘I] · Gradient Map… │ Grain…) │ Image Size… [⌥⌘I] · Canvas Size… [⌥⌘C] · Image Rotation ▸ (180° · 90° Clockwise · 90° Counter Clockwise │ Flip Canvas Horizontal · Flip Canvas Vertical) · Trim…
- Layer: New ▸ (Layer… [⇧⌘N] │ Group… · Group from Layers… │ Layer Via Copy [⌘J]) · Duplicate Layer… · Delete ▸ (Layer) │ Rename Layer… · Layer Style ▸ (Blending Options… │ Stroke… · Inner Shadow… · Inner Glow… · Color Overlay… · Outer Glow… · Drop Shadow… │ Copy Layer Style · Paste Layer Style · Clear Layer Style) │ New Adjustment Layer ▸ (Grain… │ Levels… · Curves… · Exposure… │ Hue/Saturation… · Color Balance… · Black & White… │ Invert · Gradient Map… │ Gaussian Blur… · Motion Blur… · Add Noise…) · Layer Content Options… │ Layer Mask ▸ (Reveal All · Hide All · Reveal Selection · Hide Selection │ Delete · Apply) · Create Clipping Mask [⌥⌘G] · Remove Background… │ Rasterize · Convert to Editable Vectors │ Group Layers [⌘G] · Ungroup Layers [⇧⌘G] · Hide Layers [⌘,] · Hide All Other Layers │ Arrange ▸ (Bring Forward [⌘]] · Send Backward [⌘[] │ Move Out of Group) · Combine Shapes ▸ (Unite Shapes · Subtract Front Shape · Unite Shapes at Overlap · Subtract Shapes at Overlap) · Release to Layers │ Align ▸ (Top Edges · Vertical Centers · Bottom Edges │ Left Edges · Horizontal Centers · Right Edges) · Distribute ▸ (Vertical Centers · Horizontal Centers │ Horizontally · Vertically) │ Merge Down [⌘E] · Merge Visible [⇧⌘E] · Flatten Image
- Type: Panels ▸ (Character · Paragraph)
- Select: All [⌘A] · Deselect [⌘D] · Inverse [⇧⌘I] │ Color Range… · Subject │ Modify ▸ (Expand… · Contract… · Feather… [⇧F6]) │ Load Selection…
- Filter: Last Filter [⌃⌘F] │ Camera Raw Filter… [⇧⌘A] · Lens Correction… [⇧⌘R] · Liquify… [⇧⌘X] │ Blur ▸ (Gaussian Blur… · Motion Blur…) · Noise ▸ (Add Noise…) · Pixelate ▸ (Dither…) · Render ▸ (Vignette…) · Sharpen ▸ (Unsharp Mask… │ Tonal Contrast…) · Stylize ▸ (Bloom / Glow…) · Other ▸ (High Pass…)
- View: Zoom In [⌘=] · Zoom Out [⌘-] · Fit on Screen [⌘0] · 100% [⌘1] │ ✓ Extras [⌘H] · Show ▸ (✓ Grid [⌘'] · ✓ Guides [⌘;] · ✓ Pixel Grid) │ ✓ Rulers [⌘R] │ ✓ Snap [⇧⌘;] · Snap To ▸ (✓ Guides · Grid · ✓ Layers · ✓ Document Bounds) │ Guides ▸ (Lock Guides [⌥⌘;] · Clear Guides) │ Grid Settings…
- Window: Minimize · Zoom │ Workspace ▸ (✓ Essentials (Default) │ Reset Essentials) │ Adjustments · History · ✓ Layers · ✓ Properties │ Contextual Task Bar
- Help: (Search, added by macOS)

Keyboard Shortcuts window (opened with AXPress on Edit › Keyboard Shortcuts…): Menus lists the new names in menu order with their keys (Hide Lamina ⌃⌘H, Export As ⌥⇧⌘W, …) and shows no conflict message; screenshot backlog/assets/task-62/keyboard-shortcuts-dark.png.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The menu bar now follows docs/DESIGN.md: Lamina, File, Edit, Image, Layer, Type, Select, Filter, View, Window, Help, with the familiar names, submenus and separators (Export, Image › Adjustments, Image Rotation, Layer › New, Delete, Layer Mask, Arrange, Align, Distribute, Select › Modify, the Filter categories, View › Show, Snap To, Guides, Type › Panels). Remove Background… moved to Layer. View is Lamina's own menu after Filter (`MenuBarOrder` removes the system one), and Minimize and Zoom are Lamina's own without ⌘M so Curves keeps it.

The Shortcut changes table applies: Last Filter ⌃⌘F, Merge Visible ⇧⌘E, Extras ⌘H, Hide Lamina ⌃⌘H, Fill… ⇧F5 and ⇧⌫, Color Balance ⌘B, Black & White ⌥⇧⌘B, Camera Raw Filter ⇧⌘A, Lens Correction ⇧⌘R, Feather ⇧F6, Hide Layers ⌘, and Keyboard Shortcuts ⌥⇧⌘K. ⌘F and ⌥⌘A are free, and F-keys are supported. Keys people gave renamed or moved commands carry over (`renamedIDs` with `currentID`; a key saved under the current name wins). New: the Fill dialog (colors, grays, Content-Aware, opacity; ⌥⌫ and ⌘⌫ still fill directly), the Load Selection dialog (transparency and masks, Invert, New/Add/Subtract; replaces Layer's Pixels and Mask's Black Areas), View › Extras (hides grid, guides, pixel grid and selection edges, keeping each one's setting) and one Snap that merges the two old toggles while keeping the saved "snap" preference.

Verified by `swift test` after rebasing onto main (785 + 47 + 22 tests, all passing; new FillTests, LoadSelectionTests, MenuCommandTests and shortcut, guide and Last Filter tests), by an Accessibility dump of the Dev app's menu bar matching the spec (in the notes), and by screenshots of Fill, Load Selection and Keyboard Shortcuts in backlog/assets/task-62. DESIGN.md documents the menus, shortcut changes and both dialogs. Key presses weren't sent (no synthetic events), so the keys firing is shown by the menu items' key equivalents and the unit tests.
<!-- SECTION:FINAL_SUMMARY:END -->
