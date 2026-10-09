---
id: TASK-65
title: New Document and Export As in the familiar layout
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 08:06'
labels: []
milestone: m-5
dependencies:
  - TASK-63
  - TASK-62
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The new canvas sheet is Lamina's own, and exporting is split across Export PNG…, Export JPEG… and Export As…. Switchers expect a New Document dialog with preset tabs and Preset Details, one Export As dialog with a Format menu, and File ▸ Export ▸ Quick Export as PNG.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 File ▸ New… (⌘N) shows preset tabs and cards on the left and Preset Details (name, width, height and units, orientation, resolution, background contents) on the right, with Close and Create at the bottom; the empty window's welcome view uses the same layout
- [x] #2 File ▸ Export ▸ Export As… (⌥⇧⌘W) is one dialog with a Format menu for every format Lamina writes, a live preview and the chosen format's settings; Export PNG… and Export JPEG… go
- [x] #3 File ▸ Export ▸ Quick Export as PNG goes straight to the save panel with PNG settings, with no default shortcut, leaving ⇧⌘E to Merge Visible
- [x] #4 Saved export settings carry over and the export tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. New Document: rebuild UI/NewCanvasSheet.swift as NewDocumentView (one SwiftUI view, two presentations): segmented preset tabs (Recent, Photo, Print, Web, Mobile, Film & Video), preset cards (Clipboard first in Recent when the clipboard holds an image, then recent sizes, then Default Lamina Size), Preset Details (name, width/height + units, orientation buttons, resolution + Pixels/Inch or Pixels/Centimeter, Background Contents: Transparent, White, Black, Background Color). Model: NewCanvasSize gains resolution units and orientation; DocumentPreset catalog; recent sizes saved in UserDefaults.
2. EditorSession: createNewProject takes the name and background; a non-transparent background adds a filled bottom layer "Background" under Layer 1 inside the same New Canvas edit; the chosen name names the tab/window/Save panel until saved.
3. File > New... (and +): with a document open, a window sheet (DialogLayout .bottom, Close then Create; Return creates, Escape closes); Create opens the document in a new tab. An empty tab's welcome view shows the same layout inline, with Open... and Import Image... at the bottom left and Create at the right.
4. Export As: one sheet (DialogLayout .bottom, Cancel then Export): live zoomable preview with size and estimated file size under it, File Settings group with Format (every ExportFormat.available), Quality (lossy formats), Transparency (formats with alpha) and Matte (background for transparency). ExportOptions gains transparency; saved settings (format, per-format quality, per-format transparency, matte) in one ExportSettings type, keeping today's keys.
5. Quick Export as PNG: straight to the save panel, encoded with the saved PNG settings. Remove Export JPEG... and its shortcut entry; renamedIDs carries a custom Export JPEG key to Export As (dropped on collision).
6. Tests: New Document creation with each background and unit, presets/orientation/resolution units; Export As writing each format with transparency off; saved settings; shortcut carry-over/removal. swift build, targeted then full swift test.
7. DESIGN.md (Menus > File, Shortcut changes, Dialogs: New Document and Export As sections), screenshots in backlog/assets/task-65/, notes, ACs, summary.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Slice 1, New Document: NewCanvasSheet became NewDocumentView (UI/NewDocumentView.swift) with its model in Document/NewDocument.swift (NewCanvasSize gains Pixels/Centimeter and orientation; DocumentPreset catalog; RecentDocumentSizes). Decisions: File > New... with a document open is a window sheet (Photoshop's modal New Document) whose Create opens a new tab (ProjectWorkspace.newDocument replaces newCanvas, which opened an empty tab); an empty tab shows the same layout inline as its welcome, with Open... and Import Image... at the bottom left instead of Close (nothing to close), and File > New... there just refocuses Width. The sheet holds edits through showsNewDocument rather than isProjectBusy, which dimmed the dialog and showed Working... Default Lamina Size stays 1920 x 1080 px at 72 ppi (today's default; the mockup's 2400 x 1500 was illustrative). Clipboard card sits first in Recent only, as in Photoshop. A non-transparent background adds a filled Background layer under the blank selected Layer 1 inside the same New Canvas step (one undo entry as before), limited to one surface (200 MP). Preset Details labels sit above their fields without colons, as in the mockup and Photoshop's New Document. The chosen name names the tab, window and Save panel (EditorSession.chosenName) until saved. Segmented control needed 4 columns of cards (590 pt) to fit its six tabs.

Slice 2, Export As: ExportSheet is the one Export As dialog (DialogLayout .bottom, title Export As, Cancel then Export): 520 x 330 preview with zoom out/percentage/zoom in/Fit under it and the image and file size, a File Settings group with Format (ExportFormat.available), Quality (slider + percent field; Lossless for PNG/TIFF/PDF), Transparency and Matte. Decisions: Transparency is new (the mockup's checkbox): off fills transparent areas with the matte in any format (ExportOptions.transparency/fillsTransparency; ImageExporter.encodedData), JPEG always fills. The mockup's Matte popup is the existing color well (DialogColorSwatch), labeled Matte: with the help Background for transparency. Image Size, Metadata and Color Space groups (g:1) left out. ExportSettings keeps today's keys (exportAsFormat, jpegExportQuality, <format>ExportQuality) and adds <format>ExportTransparency and exportMatte (shared by every format), read through ToolDefaults.store so tests never touch the app's defaults; Cancel saves nothing. Quick Export as PNG (ProjectController.quickExportPNG) goes straight to the Save panel and encodes with ExportSettings.options(for: .png). Export JPEG... and its Menus:Export JPEG entry are gone; renamedIDs carries a custom key to Menus:Export As (ShortcutSettings already lets Export As's own key win and drops a colliding one). lamina export-document is unchanged (PNG/JPEG, AutomationTests pass). README line 94 still describes Export JPEG (⇧⌥⌘S): left to TASK-66, which owns the README and runs in parallel.

Verification: swift build; swift test (801 app tests in 114 suites, plus the 22 and 47 of the other targets) all pass, including NewCanvasTests (each Background Contents, units, Pixels/Centimeter, orientation, presets, Recent, name), ProjectWorkspaceTests.newDocumentOpensInANewTab, ExportFormatTests (every format round-trips, and with Transparency off fills with the matte; saved settings carry over), KeyboardShortcutTests.exportJPEGKeysMoveToExportAs, AutomationTests (export-document). make test-ui not run here (left to the orchestrator). Visual check on build/Lamina Dev.app, driven through Accessibility (menu items, tabs, cards, pop-ups, Create): backlog/assets/task-65/new-document.png (File > New... over Demo, Print > Letter, White background), created-with-white-background.png (Create opened Untitled 2 at 2550 x 3300 px, 300 ppi, Background under Layer 1), welcome.png (empty window), export-as-png.png and export-as-jpeg.png (File > Export > Export As..., PNG then JPEG). The File > Export submenu reads Quick Export as PNG, Export As... The Dev app's newDocumentRecent default written by the check was deleted afterwards; no export settings were saved (dialogs cancelled).

Quick Export as PNG checked on the Dev app: its menu item opens the Save panel sheet (window title Quick Export as PNG) straight away, with no dialog in between; the panel was dismissed without saving. The item has no default key and ⇧⌘E stays Merge Visible (KeyboardShortcutTests.shortcutChangesApply).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New Document and Export As now follow the familiar layout (docs/DESIGN.md, Dialogs). New Document (UI/NewDocumentView.swift, model in Document/NewDocument.swift) has preset tabs (Recent with a Clipboard card and the last sizes created, Photo, Print, Web, Mobile, Film & Video), cards, and Preset Details (name, width/height with units, orientation, resolution in pixels per inch or centimeter, Background Contents), with Close then Create. File > New... shows it as a sheet whose Create opens a new tab; the empty window shows the same layout as its welcome, with Open... and Import Image.... A background other than Transparent adds a filled Background layer under Layer 1 in the same step. Export As (UI/ExportSheet.swift) is the one export dialog: live preview with image and file size, Format for every format the Mac writes, Quality, Transparency and Matte, Cancel then Export; settings carry over under the old keys plus per-format Transparency and a shared matte (ExportSettings). Quick Export as PNG goes straight to the Save panel with PNG's saved settings. Export JPEG... and its shortcut entry are gone; a custom key carries over to Export As... unless it collides. Verified with swift test (all suites pass, new tests for each background and unit, presets, Recent, Transparency off in every format, saved settings, the shortcut carry-over) and on the Dev app through Accessibility, with screenshots in backlog/assets/task-65/. README's Export JPEG line is left to TASK-66.
<!-- SECTION:FINAL_SUMMARY:END -->
