---
id: TASK-63
title: 'Dialogs in the familiar layout, and one pattern for filter dialogs'
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
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
