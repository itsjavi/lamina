---
id: DRAFT-3
title: Filter ▸ Pixelate ▸ Scanlines
status: Draft
assignee: []
created_date: '2026-10-09 16:33'
labels:
  - upstream
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/06c3a22'
  - 'https://github.com/robbietilton/Compositor/commit/1187736'
  - 'https://github.com/robbietilton/Compositor/commit/cdde327'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Not a Photoshop filter, so a draft: interesting as a Lamina extra next to Dither. Upstream split its Dither filter's Scanlines (CRT) style into a filter of its own (06c3a22, 1187736, cdde327): line spacing and thickness, a glow that eases off near white (off by default), dots by tone, wobble, displacement up to ±100 px with lines hiding those behind, threshold, color split, black level. Lamina's DitherPixels.c and .h are byte-identical to the fork base, so upstream's final files, Scanlines.swift and its 8 tests port almost whole; the controls would be rewritten in FilterSheet's style, and Dither would lose its Scanlines style. Research: doc-4.
<!-- SECTION:DESCRIPTION:END -->
