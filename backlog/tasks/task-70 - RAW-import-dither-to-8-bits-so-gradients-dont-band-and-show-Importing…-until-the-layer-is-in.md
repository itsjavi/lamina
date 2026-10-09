---
id: TASK-70
title: >-
  RAW import: dither to 8 bits so gradients don't band, and show Importing…
  until the layer is in
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/6345432'
  - 'https://github.com/robbietilton/Compositor/commit/196342c'
  - 'https://github.com/robbietilton/Compositor/commit/0907f51'
  - 'https://github.com/robbietilton/Compositor/commit/6e6ca38'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: bug
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
RawImporter renders the developed RAW straight to RGBA8 (default CIContext, createCGImage .RGBA8), so smooth skies and gradients band. Upstream renders at 16 bits and rounds to 8 with fine noise (6345432), does that rounding in C so it takes 0.6 s instead of 15 s in debug builds (196342c, dither_quantize16 in DitherPixels.c), and keeps the RAW develop sheet open with Importing… until the layer is in (0907f51; Lamina's finishRawDevelop closes it at once, leaving no sign of work). 6e6ca38 splits a test expression CI couldn't type-check. Lamina's RawImporter, RawDevelopSheet and DitherPixels.c match upstream's code before these commits. Port with Co-authored-by: Robbie <1269226+robbietilton@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 RAW imports (and the develop preview) round 16-bit output to 8 bits with fine noise: a smooth gradient imports without bands, per upstream's RawDitherTests
- [ ] #2 The rounding runs in C (CPixels) and imports a 24 MP RAW in about a second in a debug build
- [ ] #3 The RAW develop sheet shows Importing… with OK dimmed until the layer is added, and DESIGN.md's Dialogs section describes the sheet
<!-- AC:END -->
