---
id: TASK-84
title: Image ▸ Adjustments ▸ Color Lookup (LUTs)
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/171'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's Color Lookup applies a 3D LUT (.cube, .3dl, .look) as an adjustment or adjustment layer; it is how color grades are shared. Lamina has none (upstream issue #171 asks for LUT adjustment layers and presets). Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Image ▸ Adjustments ▸ Color Lookup… and Layer ▸ New Adjustment Layer ▸ Color Lookup… load a .cube file and apply it with trilinear interpolation
- [ ] #2 As an adjustment layer it is edited in Properties, and the project keeps the LUT so it opens anywhere
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
