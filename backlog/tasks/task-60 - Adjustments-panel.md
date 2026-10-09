---
id: TASK-60
title: Adjustments panel
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-58
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adding an adjustment layer takes the Layers panel's menu today. Familiar editors offer an Adjustments panel: a grid of labeled icons that add one in a click.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Adjustments shows Lamina's adjustment kinds as a grid of labeled icons in the order docs/DESIGN.md gives, with Lamina's filter layers (Gaussian Blur, Motion Blur, Add Noise) in their own section
- [ ] #2 Clicking one adds that adjustment layer above the active layer as Layer ▸ New Adjustment Layer does, as one undo step, and shows it in Properties
- [ ] #3 Help tags name each adjustment, and the grid reflows with the dock's width
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
