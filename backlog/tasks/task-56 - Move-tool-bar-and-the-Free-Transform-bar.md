---
id: TASK-56
title: Move tool bar and the Free Transform bar
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-52
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Move tool's bar holds X, Y, W, H, Scale, angle, Sampling and Flip, so the Move tool doubles as a transform panel and ⌘H toggles its controls. Familiar editors keep the Move bar to Auto-Select, transform controls and alignment, show the numbers in a Free Transform bar only while transforming (⌘T or dragging a handle), and otherwise keep them in the Properties panel.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Move bar shows Auto-Select, Show Transform Controls, the align and distribute buttons (dimmed until two or more layers are selected) and a menu with the rest of Align and Distribute
- [ ] #2 Transforming a layer or a selection (Edit ▸ Free Transform, ⌘T, or dragging a handle) shows the Free Transform bar: reference point, X and Y, W and H in percent with a link, angle, Interpolation, and Cancel and Commit at the right end
- [ ] #3 Interpolation offers Nearest Neighbor, Bilinear and Bicubic, mapped from today's Nearest, Smooth and High quality without changing saved projects
- [ ] #4 Flip Horizontal and Flip Vertical move to Edit ▸ Transform, and ⌘H no longer toggles transform controls
- [ ] #5 Each transform is still one undo step and the existing transform tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
