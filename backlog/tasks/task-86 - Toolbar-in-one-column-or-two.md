---
id: TASK-86
title: Toolbar in one column or two
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/189'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: feature
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's toolbar has a double arrow at its top that switches between one column and two, for short screens. Lamina's is always one column. Upstream's open PR #189 adds it. Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A double-arrow button at the toolbar's top switches between one and two columns; the choice is remembered
- [ ] #2 In two columns the slots keep their order, flyouts and keys, and the canvas takes the width back
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
