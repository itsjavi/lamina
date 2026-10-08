---
id: TASK-49
title: 'Paint thickness: layers keep it and the canvas lights it as relief'
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
updated_date: '2026-10-08 23:22'
labels:
  - painting
milestone: m-4
dependencies: []
references:
  - docs/project-format.md
  - backlog/docs/research/doc-3 - Agent-painting-research.md
priority: low
type: feature
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Thick paint catches the light: ridges along bristle marks and where the brush lifts, flat in thin glazes. Nothing in Lamina models it, nor in PhotoCraft or VectorCraft (doc-3); the oil-painting experiment faked it with a height map baked into an Overlay layer, which can't follow later edits. This task gives layers the data and the canvas the lighting; brushes that lay thickness are TASK-50.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A pixel layer can carry a thickness channel, a grayscale image next to its pixels like a mask, saved in the project (a format version bump in docs/project-format.md and ProjectManifest.current) and described in the guide for writing projects
- [ ] #2 The canvas, previews and exports light thickness as relief with a light direction, depth and gloss, on the Metal canvas and in the export path alike
- [ ] #3 Moving, transforming, resizing, cropping, duplicating and merging keep thickness aligned with the pixels; erasing removes it
- [ ] #4 PSD export bakes the lighting into the pixels
- [ ] #5 Tests cover the project round trip, lighting against a reference image and alignment through transforms
<!-- AC:END -->
