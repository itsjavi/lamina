---
id: TASK-93
title: Lock transparent pixels
status: To Do
assignee: []
created_date: '2026-10-09 22:52'
labels: []
milestone: m-1
dependencies:
  - TASK-92
priority: medium
type: feature
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's first Lock button (and / by default) confines edits to a layer's existing pixels: painting, fills, gradients, filters and adjustments keep every pixel's alpha, so a shape can be recolored without spilling outside it. Lamina's Lock row shows it as an in-progress placeholder (TASK-92 shipped the other locks). It needs the brush, fill, gradient, eraser and filter paths (C kernels and Metal) to preserve alpha when the lock is on, and a format addition (a transparentPixels lock in LayerLocks, version bump).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With Lock transparent pixels on, every paint, fill, gradient, filter and adjustment applied to the layer keeps each pixel's alpha; the Eraser is refused
- [ ] #2 The lock is saved in projects, read from PSD files, and / toggles it as in Photoshop
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
