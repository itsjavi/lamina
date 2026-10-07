---
id: TASK-28
title: Vector shapes and the Pen tool
status: To Do
assignee: []
created_date: '2026-10-07 20:36'
labels:
  - postponed
dependencies:
  - TASK-7
references:
  - 'https://github.com/robbietilton/Compositor/pull/115'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: feature
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A must-have, postponed (doc-1 decisions). Lamina's shapes are fixed kinds (rectangles, ellipses, lines); there's no Pen tool or editable paths. Upstream PR #115 (8.4k lines, conflicting, binds Direct Selection to A, which is the Select tool's key) is reference only: reimplement. Vector data changes the project format, so it needs the .lamina format first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Pen tool draws and edits Bézier paths, which can be filled or stroked as editable vector layers and turned into selections
- [ ] #2 Vector layers save in the Lamina format (a version bump) and render crisp at any zoom and size
- [ ] #3 Tool keys stay consistent with the existing tools
<!-- AC:END -->
