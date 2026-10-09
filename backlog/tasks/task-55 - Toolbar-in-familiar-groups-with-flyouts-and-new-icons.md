---
id: TASK-55
title: 'Toolbar in familiar groups, with flyouts and new icons'
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-54
  - TASK-52
  - TASK-53
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 56 pt tool rail lists 16 tools in Lamina's own order, and the Move tool's resize-arrow icon reads as Scale. Switchers expect a single column grouped as in docs/DESIGN.md, flyouts for tools that share a slot, and the four-headed move arrow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A 44 pt single-column toolbar shows the groups, order and separators in docs/DESIGN.md, including the in-progress placeholders listed there
- [ ] #2 A slot shows the last tool used from its group; holding the mouse on it or right-clicking opens a flyout with each tool's icon, name and key
- [ ] #3 The Move tool uses the four-headed arrow, and every tool icon follows the icon rules in docs/DESIGN.md
- [ ] #4 Foreground and background swatches sit at the bottom with the default-colors and swap controls (D, X)
- [ ] #5 Help tags and accessibility labels read "Tool name (Key)", and the toolbar fits an 860 pt window without scrolling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
