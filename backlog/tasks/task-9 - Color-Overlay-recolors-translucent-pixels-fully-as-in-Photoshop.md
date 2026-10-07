---
id: TASK-9
title: 'Color Overlay recolors translucent pixels fully, as in Photoshop'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/211'
  - 'https://github.com/robbietilton/Compositor/pull/214'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: bug
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Color Overlay is mixed over the already-composited pixels by their alpha, so translucent pixels are only partly recolored (upstream issue #211; confirmed in Rendering/MetalLayerEffects.swift and Document/LayerEffects.swift). Upstream PR #214 recolors the layer's own pixels instead (source-atop on the CPU, mix() in the Metal kernel); its author couldn't run the tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Color Overlay replaces the color of the layer's own pixels, translucent ones included, on the GPU canvas and in CPU rendering (export, merge)
- [ ] #2 A test shows GPU and CPU output match, and PR #214's tests pass
<!-- AC:END -->
