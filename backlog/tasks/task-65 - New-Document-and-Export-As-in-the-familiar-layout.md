---
id: TASK-65
title: New Document and Export As in the familiar layout
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
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
- [ ] #1 File ▸ New… (⌘N) shows preset tabs and cards on the left and Preset Details (name, width, height and units, orientation, resolution, background contents) on the right, with Close and Create at the bottom; the empty window's welcome view uses the same layout
- [ ] #2 File ▸ Export ▸ Export As… (⌥⇧⌘W) is one dialog with a Format menu for every format Lamina writes, a live preview and the chosen format's settings; Export PNG… and Export JPEG… go
- [ ] #3 File ▸ Export ▸ Quick Export as PNG goes straight to the save panel with PNG settings, with no default shortcut, leaving ⇧⌘E to Merge Visible
- [ ] #4 Saved export settings carry over and the export tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
