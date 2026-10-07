---
id: TASK-14
title: 'Image › Image Rotation: 90° either way and 180°'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies:
  - TASK-8
references:
  - 'https://github.com/robbietilton/Compositor/issues/212'
  - 'https://github.com/robbietilton/Compositor/pull/195'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina can flip the canvas but not rotate it (upstream issue #212). Upstream PR #195 turns the whole document losslessly with vImage, keeping text and shapes editable. Port it after the effects fix, so rotation doesn't drop effects.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Image › Image Rotation turns the document 90° clockwise, 90° counter-clockwise or 180°, losslessly, as one undo step
- [ ] #2 Layers, masks, the selection and guides turn with it; live text and shapes stay editable and effects are kept
- [ ] #3 Tests cover each rotation
<!-- AC:END -->
