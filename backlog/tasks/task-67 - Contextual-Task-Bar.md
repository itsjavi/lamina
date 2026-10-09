---
id: TASK-67
title: Contextual Task Bar
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
dependencies:
  - TASK-59
  - TASK-55
  - TASK-62
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: low
type: feature
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Familiar editors float a small bar under the selection or the active layer with the next likely actions: Select Subject and Remove Background on a pixel layer; Invert, Fill, a mask from the selection and Deselect on a selection; rotate and flip while transforming. decision-9 accepts it as a follow-up once m-5's panels and menus have landed; until then Window ▸ Contextual Task Bar shows as in progress (docs/DESIGN.md).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A bar floats under the selection, the active layer or the transform box with the actions docs/DESIGN.md lists for each context, and never covers the object
- [ ] #2 It can be hidden from Window ▸ Contextual Task Bar or its own menu and moved, and the choice is remembered
- [ ] #3 Its buttons run the same commands as the menus, each as one undo step
- [ ] #4 It follows the appearance and stays legible over any image
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
