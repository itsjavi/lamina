---
id: TASK-59
title: Properties panel
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-58
  - TASK-56
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina has no Properties panel: transform numbers live in the Move bar, adjustment layers open floating panels, type settings crowd the Type bar and mask actions hide in menus. Switchers expect one panel that shows the settings of whatever is selected.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Properties shows the states in docs/DESIGN.md: the document (canvas size, resolution, units, quick actions) when no layer is selected, a pixel layer (Transform, Align and Distribute, Interpolation, and the quick actions Remove Background and Select Subject), a type layer (Transform, Character, Paragraph), a group, an adjustment layer and a layer mask
- [ ] #2 Adjustment layers are edited in Properties, live, with its footer (clip to layer, reset, visibility, delete); the floating panels for adjustment layers go, while Image ▸ Adjustments keeps its dialogs
- [ ] #3 Leading and tracking move from the Type bar to Character
- [ ] #4 Every edit made in Properties is one undo step and agrees with the canvas, the menus and the lamina commands
- [ ] #5 Tests cover each state and that edits survive saving and reopening
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
