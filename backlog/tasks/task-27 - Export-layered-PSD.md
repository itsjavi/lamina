---
id: TASK-27
title: Export layered PSD
status: To Do
assignee: []
created_date: '2026-10-07 20:36'
labels:
  - upstream
  - psd
milestone: m-1
dependencies:
  - TASK-2
references:
  - 'https://github.com/robbietilton/Compositor/pull/48'
  - 'https://github.com/robbietilton/Compositor/pull/40'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: feature
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decided in doc-1: PSD export if it's lossless and MIT-compatible. Write our own layered writer in CompositorCore (closed upstream PR #48's PSDLayeredWriter as the base, an MIT contribution; no third-party code). ImageIO only writes flat PSDs. Upstream deferred PSD export because users expect everything to stay editable, so the export must say what doesn't.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Exports a layered PSD that Photoshop and Lamina's importer open, pixel-exact for raster layers, masks, groups, opacity, blend modes, clipping and the composite
- [ ] #2 Live text, shapes, layer effects and Lamina-only adjustments map to their PSD equivalents where one exists, otherwise are written as pixels, and the export tells the user which layers were rasterized
- [ ] #3 Round-trip tests export and re-import through the PSD reader
<!-- AC:END -->
