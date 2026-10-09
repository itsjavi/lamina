---
id: TASK-80
title: Window ▸ Navigator
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/199'
  - 'https://github.com/robbietilton/Compositor/commit/3e09948'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's Navigator panel shows the whole image with a box around the part in view: dragging the box pans, and a zoom field and slider zoom. Lamina has none. Upstream merged one above its Layers panel (PR #199, 6490bb3) and then made it a minimap in the canvas corner from 300% (3e09948), which isn't Photoshop's design. Reusable: NavigatorGeometry and the viewport helpers, the log2 zoom slider, the geometry tests. Rebuild the thumbnail off the main thread (upstream composites synchronously on the CPU and doesn't scale effect sizes). Its likely home is the panel icon column, opening like History. Research: doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Window ▸ Navigator opens a Navigator panel with the image's thumbnail and a box around the part in view, in a color role
- [ ] #2 Dragging or clicking in the thumbnail pans the canvas; the zoom field, buttons and slider zoom it
- [ ] #3 The thumbnail updates after edits without blocking the main thread; tests cover the geometry
- [ ] #4 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
