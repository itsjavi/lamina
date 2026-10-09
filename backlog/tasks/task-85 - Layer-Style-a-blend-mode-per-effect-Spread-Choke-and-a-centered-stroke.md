---
id: TASK-85
title: 'Layer Style: a blend mode per effect, Spread, Choke and a centered stroke'
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/64'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's effects each have a Blend Mode (shadows Multiply, glows Screen by default), Drop Shadow and Outer Glow a Spread, Inner Shadow and Inner Glow a Choke, and Stroke a Center position. Lamina's Layer Style dialog has none of them, and PSD import can't map them. Upstream's closed PR #64 had center stroke and shadow spread/choke. Saving them changes the project format. Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each effect page has Blend Mode, Drop Shadow and Outer Glow have Spread, Inner Shadow and Inner Glow have Choke, and Stroke's Position has Center, as in Photoshop
- [ ] #2 They render the same on the GPU canvas and CPU rendering (tests on both paths) and are saved in projects
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
