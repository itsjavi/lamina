---
id: TASK-47
title: 'Wet paint: a mixer brush that picks up and blends color'
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
updated_date: '2026-10-08 23:24'
labels:
  - painting
milestone: m-3
dependencies:
  - TASK-46
references:
  - Sources/LaminaApp/Document/SmudgeLiquify.swift
  - backlog/docs/research/doc-3 - Agent-painting-research.md
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/paint/src/mixer.rs
priority: low
type: feature
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Oil paint mixes on the canvas: a stroke drags the paint it crosses, and its own color changes and runs out. Lamina's Smudge (`SmudgeLiquify.swift`) pushes pixels but carries no paint, and the Brush lays a fixed color. PhotoCraft's mixer brush (reservoir, pickup, mix, depletion; doc-3) is the model.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A mixer brush keeps a reservoir (color and amount) that the stroke lays, picks up canvas color at a set wetness, blends at a set mix and depletes at a set load, with bristle tips as well as round ones
- [ ] #2 Pickup samples the current layer or all visible layers, as chosen
- [ ] #3 In the Brush tool the reservoir carries over between strokes and can be cleaned or reloaded; in `paint-strokes` it starts from the stroke's color unless told to carry over, so commands stay deterministic
- [ ] #4 Available in the Brush tool and in `paint-strokes`, with presets (for example wet blend and dry scumble)
- [ ] #5 Per-dab sampling runs in CPixels within the brush benchmark's budget; tests cover pickup, depletion and determinism
<!-- AC:END -->
