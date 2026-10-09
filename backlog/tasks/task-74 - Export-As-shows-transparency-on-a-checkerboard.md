---
id: TASK-74
title: Export As shows transparency on a checkerboard
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/b1db93d'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: enhancement
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Export As previews the encoded file on the pasteboard color, so transparent areas look the same as the margin around the image and Transparency on or off is hard to judge. Photoshop's Export As shows transparency on a checkerboard. Upstream b1db93d draws the canvas checkerboard behind the preview; Lamina's FilterPreview already draws one (its fixed colors are allowed by DESIGN.md's Colors and surfaces), which can be shared.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Export As draws the canvas checkerboard behind the image only (not the margin), at every zoom, so transparent pixels read as transparent
- [ ] #2 The filter preview and Export As share one checkerboard drawing, and DESIGN.md's Export As entry says it
<!-- AC:END -->
