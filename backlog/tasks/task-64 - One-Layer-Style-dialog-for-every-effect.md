---
id: TASK-64
title: One Layer Style dialog for every effect
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-63
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each layer effect opens its own floating panel today. Switchers expect one Layer Style dialog: the effects listed on the left with checkboxes, the selected effect's settings in the middle, and buttons and a preview swatch on the right.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Layer ▸ Layer Style and the Layers panel's fx menu open one Layer Style dialog
- [ ] #2 Its list shows Lamina's effects in the order docs/DESIGN.md gives; checking one turns it on and selecting one shows its settings
- [ ] #3 Settings use the familiar names (Size for today's Blur, Opacity, Angle, Distance) and preview live
- [ ] #4 OK applies every change as one undo step and Cancel restores the layer exactly
- [ ] #5 Copy, Paste and Clear Layer Style behave as today
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
