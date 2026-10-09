---
id: TASK-63
title: 'Dialogs in the familiar layout, and one pattern for filter dialogs'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 04:56'
labels: []
milestone: m-5
dependencies:
  - TASK-51
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina's dialogs are floating panels with their own layouts and OK and Cancel at the bottom. Switchers expect settings on the left and OK, Cancel, extra buttons and Preview stacked on the right, and filters in one pattern: a preview with zoom, then the settings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Adjustment, filter, selection, Stroke, Fill, Trim, Canvas Size, Load Selection and Color Range dialogs put OK, Cancel, extra buttons and the Preview checkbox in a right-hand column, as docs/DESIGN.md shows
- [ ] #2 Image Size, New Document and Export As keep Cancel and the default button at the bottom right
- [ ] #3 Every filter dialog uses the same frame: a preview with zoom out, percentage and zoom in, then the settings
- [ ] #4 Labels, units and field order follow docs/DESIGN.md, with Lamina-only settings after the familiar ones
- [ ] #5 Return, Escape and the live canvas preview behave as today, and the existing dialog tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shared layout in UI/DialogLayout.swift: DialogLayout (settings left, 100 pt button column right: OK default/Return, Cancel/Escape, extra buttons, Preview checkbox, status line) with a .bottom placement (Cancel then default button at the bottom right) for Image Size; DialogLabel/dialog rows with colon labels; reusable by TASK-62 (Fill, Load Selection).
2. FilterPreview (UI/FilterPreview.swift): crop of the filter edit's own preview image (the filtered layer the canvas shows), zoom out / percentage / zoom in, drag to pan, hold to see the original; keep rendering the dialog preview while the canvas Preview is off (canvas gate previewImage(for:) unchanged).
3. FilterSheet: filters (not Image adjustments, not Camera Raw) get the preview frame then the settings; every non-Camera Raw kind uses DialogLayout; Curves gets Output:/Input: fields; Camera Raw keeps its docked layout with Cancel and OK at the bottom right and an edge border on its histogram well.
4. Levels, Hue/Saturation, Color Range, Expand/Contract/Feather, Stroke, Trim, Canvas Size in DialogLayout with mockup labels, groups and button columns; Image Size in the bottom variant. Lamina-only settings after familiar ones.
5. DESIGN.md Dialogs section with component names and sizes; tests (swift build, targeted suites, full swift test); screenshots of Levels, a filter, Canvas Size, Stroke into backlog/assets/task-63.
<!-- SECTION:PLAN:END -->
