---
id: TASK-28
title: Pen tool and path editing
status: To Do
assignee: []
created_date: '2026-10-07 20:36'
updated_date: '2026-10-08 15:09'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-32
references:
  - 'https://github.com/robbietilton/Compositor/pull/115'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
  - >-
    backlog/decisions/decision-5 -
    Vector-layers-are-Illustrator-style-object-trees-saved-as-SVG-in-the-Lamina-project.md
  - >-
    backlog/docs/research/doc-2 -
    Vector-graphics-and-the-Paint-Bucket-research.md
priority: medium
type: feature
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A must-have, postponed in doc-1 until the project format could hold vectors; m-2 now plans it. Lamina has no Pen tool or editable paths. Vector layers come first (TASK-32); this task draws and edits their paths. Upstream PR #115 (8.4k lines, conflicting, binds Direct Selection to A, which is the no-tool key) is reference only: reimplement. Pen and Direct Selection behavior to follow (VectorCraft) is in doc-2.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Pen tool draws Bézier paths into the active vector layer, or a new one: click for a corner, drag for a smooth anchor, click the first anchor to close, click an open end to continue, Return or Escape to finish
- [ ] #2 Direct Selection selects and drags anchors, handles and segments (marquee and Shift to add), arrow keys nudge, and dragging a curved segment reshapes it
- [ ] #3 Anchors can be added, deleted (the curve refits) and converted between corner and smooth, with the Option behaviors doc-2 lists
- [ ] #4 Anchors, handles and paths draw as canvas overlays whose hit areas are the same size on screen at any zoom
- [ ] #5 Tool keys stay consistent with the existing tools
- [ ] #6 Each gesture is one undo step, and tests cover drawing, closing, continuing and editing paths
<!-- AC:END -->
