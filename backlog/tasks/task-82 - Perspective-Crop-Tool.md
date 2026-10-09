---
id: TASK-82
title: Perspective Crop Tool
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/206'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: feature
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's Perspective Crop Tool, in the Crop slot (C, Shift-C), crops to four corners dragged onto a skewed rectangle (a photographed sign or document) and straightens it into an upright rectangle. Lamina has Distort and Camera Raw's geometry but no four-corner crop (upstream issue #206). Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Perspective Crop Tool sits after the Crop Tool in the Crop slot; dragging places a box whose four corners move freely, with Commit and Cancel in its options bar
- [ ] #2 Commit straightens the area into a rectangle sized from the corners and crops the document to it, as one undo step
- [ ] #3 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
