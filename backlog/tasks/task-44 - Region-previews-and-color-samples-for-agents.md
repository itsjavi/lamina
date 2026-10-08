---
id: TASK-44
title: Region previews and color samples for agents
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
labels:
  - agents
milestone: m-3
dependencies:
  - TASK-42
references:
  - backlog/docs/research/doc-3 - Agent-painting-research.md
priority: medium
type: feature
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
To check and correct its work an agent looks at `render-preview`, and image tokens grow with pixels: a full-canvas preview big enough to show strokes is expensive, a small one hides them. Matching a color on the canvas means reading it off an image. Targeted feedback makes correction rounds (a look, then a few dozen inline strokes) cheap. Research: doc-3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `render-preview` takes a region in document pixels and renders only that area, at up to `max_size`, so a detail can be inspected at full resolution
- [ ] #2 `sample-colors` returns hex colors at given points, or averaged over given rectangles, from the composite or from one layer
- [ ] #3 A region can be the changed bounds an earlier edit returned, so the agent looks at exactly what it changed
- [ ] #4 Tests cover regions at the canvas edges, scaled previews, and sampling from the composite and from a layer
<!-- AC:END -->
