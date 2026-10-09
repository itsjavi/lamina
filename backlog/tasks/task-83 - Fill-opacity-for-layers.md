---
id: TASK-83
title: Fill opacity for layers
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/62'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop gives every layer Fill next to Opacity: Fill fades the layer's own pixels but not its layer effects, so a stroke or shadow can stay while the shape vanishes (upstream issue #62). Lamina has Opacity only. PSD import already reads fill and folds it into opacity (PSDReader), which this would keep apart. Saving fill changes the project format (a version bump in LaminaCore and docs/project-format.md). Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Layers panel shows Fill: under Opacity as in Photoshop, and Layer Style's Blending Options has Fill Opacity
- [ ] #2 Fill fades the layer's pixels and leaves its effects as they are, on the GPU canvas and CPU rendering; projects save and load it
- [ ] #3 PSD import keeps a layer's fill as fill
- [ ] #4 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
