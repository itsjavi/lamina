---
id: TASK-58
title: 'Right dock: Properties and Adjustments over Layers, History as a panel icon'
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
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today one 252 pt side panel switches between Layers and History. Familiar editors dock tab groups at the right (Properties and Adjustments above Layers) with less-used panels such as History collapsed to icons beside them. The dock is the frame the Properties, Adjustments and Layers panel tasks build in.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The right side holds a column of panel icons (History) and a dock of two tab groups, Properties | Adjustments above Layers, sized as in docs/DESIGN.md
- [ ] #2 The dock can be resized within its range and the split between groups dragged, and both are remembered
- [ ] #3 Clicking the History icon opens the History panel beside the dock and clicking it again closes it; History keeps today's behavior
- [ ] #4 Window lists Adjustments, History, Layers and Properties to show or hide them, and Window ▸ Workspace ▸ Reset Essentials restores the layout
- [ ] #5 In a 1500 × 860 pt window the canvas keeps at least 1100 × 740 pt
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
