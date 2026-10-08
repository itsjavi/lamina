---
id: TASK-46
title: Bristle brushes that paint like oil
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
updated_date: '2026-10-08 23:24'
labels:
  - painting
milestone: m-3
dependencies:
  - TASK-43
references:
  - Sources/LaminaApp/Document/BrushStroke.swift
  - backlog/docs/research/doc-3 - Agent-painting-research.md
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/paint/src/presets.rs
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/paint/src/dynamics.rs
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/brush/src/calli.rs
priority: medium
type: feature
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina's brush is a round tip (diameter, hardness, flow, opacity, pressure), so strokes look like a digital airbrush, by hand or from an agent. The oil-painting experiment (doc-3) shows what makes paint read as oil: strands of slightly varied color across each stroke, ragged ends, strokes that turn with their direction, and canvas grain. PhotoCraft stamps a bristle image turned by the direction; VectorCraft draws strands, which hold up better along long strokes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A bristle tip lays strands across the stroke, each with its own slight color and value variation, wobble and ragged start and end, turning with the stroke's direction
- [ ] #2 Paint load: a stroke starts loaded and runs dry along its length at a set rate, its strands thinning out unevenly
- [ ] #3 Canvas grain is sampled in document space: paint catches on the weave's peaks, and the grain stays put where strokes cross
- [ ] #4 Oil presets (at least flat bristle, round bristle, fan and dry brush) in the Brush tool's options, and by name in `paint-strokes`
- [ ] #5 Painting is deterministic for a given seed, and the pixel loops live in CPixels within the brush benchmark's budget (`BrushPerformanceTests`)
- [ ] #6 Tests cover determinism, strands following the direction and grain fixed in document space
<!-- AC:END -->
