---
id: TASK-52
title: 'Workspace frame: options bar, status bar and title bar'
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The window's frame is the first thing a switcher scans. Today a 42 pt tool header with the tool's name sits over the canvas, the title bar carries Fit, 100% and zoom buttons, and a 30 pt status bar spans the whole window. Familiar editors put a compact context bar above the canvas that starts with the tool's icon, keep zoom and document size in a status bar under the canvas, and name document tabs "Name @ zoom% (Layer, RGB/8)". The frame also has to leave room for the dock inside 1500 × 860 pt.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The tool header becomes a 36 pt options bar that starts with the active tool's icon; tool names no longer appear as titles
- [ ] #2 The title bar keeps New and the document tabs only; Fit, 100% and the zoom buttons move to View and to the Hand and Zoom tool bars
- [ ] #3 Document tabs read "Name @ 44.5% (Layer name, RGB/8)" and truncate in the middle when crowded
- [ ] #4 A 22 pt status bar under the canvas only (not under the panels) shows an editable zoom field and the document's size and resolution, with the tool hints at its right
- [ ] #5 Metrics match docs/DESIGN.md, and in a 1500 × 860 pt window no control is clipped
- [ ] #6 Accessibility identifiers that tests use (zoomStatus, canvasDimensions, fitCanvas, actualPixels) keep working, or the tests are updated
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
