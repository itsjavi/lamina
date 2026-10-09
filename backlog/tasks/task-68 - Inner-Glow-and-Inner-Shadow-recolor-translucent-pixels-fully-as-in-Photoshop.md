---
id: TASK-68
title: 'Inner Glow and Inner Shadow recolor translucent pixels fully, as in Photoshop'
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/9cb57db'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: bug
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Inner Glow and Inner Shadow are filled over the already-composited pixels and their coverage is multiplied by the layer's shape, so on translucent pixels they only partly recolor, the same flaw TASK-9 fixed for Color Overlay. Upstream fixed both in 9cb57db (CPU in Document/LayerEffects.swift, the brush-stroke surface in Rendering/LayerEffectsSurface.swift, the Metal kernel in Rendering/MetalLayerEffects.swift); Lamina's code still matches upstream's code before that commit, and TASK-9's source-atop and mix() are already there. Upstream added no tests. Port with Co-authored-by: Robbie <1269226+robbietilton@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Inner Glow and Inner Shadow recolor a translucent pixel fully, keeping its alpha, on the GPU canvas, the brush-stroke surface and CPU rendering (export, merge)
- [ ] #2 Opaque pixels render as before, and InnerGlowTests' CPU and Metal parity test still passes
- [ ] #3 New tests cover translucent pixels for both effects on both paths (gpu: true and false), modeled on ColorOverlayTests
<!-- AC:END -->
