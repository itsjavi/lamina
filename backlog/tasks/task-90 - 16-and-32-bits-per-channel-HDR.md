---
id: TASK-90
title: 16 and 32 bits per channel (HDR)
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/224'
  - 'https://github.com/robbietilton/Compositor/issues/225'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: feature
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop edits at 8, 16 or 32 bits per channel (Image ▸ Mode), and 32-bit keeps HDR highlights. Lamina is 8-bit sRGB from layers to export, so HDR photos lose their highlights and smooth gradients band (upstream issues #224, #225; upstream plans its own HDR work). A pipeline-wide change: layer storage, C loops, Metal canvas, project format and export.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Image ▸ Mode offers 8, 16 and 32 Bits/Channel; converting keeps the image and every edit works at the chosen depth
- [ ] #2 HDR images open and export with their highlights (16-bit PNG and TIFF, HDR HEIC or AVIF), and the canvas shows them on HDR displays
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
