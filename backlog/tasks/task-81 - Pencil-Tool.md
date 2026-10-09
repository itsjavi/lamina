---
id: TASK-81
title: Pencil Tool
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/164'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's Pencil Tool, in the Brush slot (B, Shift-B), paints hard-edged, aliased pixels with no softness, for pixel art and crisp masks. Lamina's Brush always anti-aliases. Upstream's closed PR #164 made it a Pixel mode of the Brush; Lamina keeps tools separate (DESIGN.md: don't hide a tool inside another tool's mode picker). Research: doc-1, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Pencil Tool sits after the Brush Tool in the Brush slot, with its own options bar (size, opacity, pressure) and settings
- [ ] #2 Strokes set whole pixels at full hardness with no anti-aliasing, at any zoom, on layers and masks
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
