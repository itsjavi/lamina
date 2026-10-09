---
id: TASK-89
title: 'CMYK soft proofing: Proof Setup, Proof Colors and Gamut Warning'
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/245'
  - 'https://github.com/robbietilton/Compositor/issues/225'
  - 'https://github.com/robbietilton/Compositor/issues/229'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: feature
ordinal: 89000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop previews how an RGB image will print through a CMYK profile (View ▸ Proof Setup, Proof Colors ⌘Y) and marks colors the press can't reach (Gamut Warning ⇧⌘Y). Lamina has no color proofing; upstream issues #225 and #229 ask for CMYK, and open PR #245 (+561 lines, ColorSync transforms, a Core Graphics proof path, CMYK TIFF export) implements a version of it, unreviewed upstream. Research: doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 View ▸ Proof Setup picks a CMYK output profile and rendering intent; Proof Colors (⌘Y) shows the canvas through it; Gamut Warning (⇧⌘Y) marks out-of-gamut colors
- [ ] #2 Proofing changes only the view, never the document or exports, and costs the canvas no visible lag
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
