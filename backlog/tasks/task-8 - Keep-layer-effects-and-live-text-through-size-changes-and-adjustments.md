---
id: TASK-8
title: Keep layer effects and live text through size changes and adjustments
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/180'
  - 'https://github.com/robbietilton/Compositor/pull/181'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: high
type: bug
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Canvas Size, Image Size, Crop, Trim, Hue/Saturation, Levels, selection edits and floating selections rebuild the layer list from a snapshot and leave out layer effects (and in places shapes and live text): silent data loss, confirmed in IO/ImageResizer.swift and IO/CanvasResizer.swift (upstream issue #180). Upstream PR #181 fixes it with one snapshot-to-layers mapping, LayerEffects.scaled(by:) and tests that fail on main; port it and credit its author. Do this before exposing size commands to agents (TASK-4).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After Canvas Size, Image Size, Crop, Trim, Hue/Saturation, Levels and the selection and floating-selection edits, every layer keeps its effects, shape and live text, with effect sizes scaled when the image is resized
- [ ] #2 One shared mapping turns a project snapshot back into layers, so a new layer property can't be missed in one code path
- [ ] #3 Tests cover each operation and fail without the fix
<!-- AC:END -->
