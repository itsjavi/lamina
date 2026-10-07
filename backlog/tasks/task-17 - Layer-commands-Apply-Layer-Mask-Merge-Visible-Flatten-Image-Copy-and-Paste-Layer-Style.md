---
id: TASK-17
title: >-
  Layer commands: Apply Layer Mask, Merge Visible, Flatten Image, Copy and Paste
  Layer Style
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/163'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Upstream took the masks, Auto Select, tabs and Ungroup parts of PR #163 but left out its layer commands to keep menus short. They are core compositing commands, and natural commands for TASK-4. Port them from commit aea6e20f (ApplyLayerMask, LayerStyleClipboard, LayerMerge).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Layer menu commands Apply Layer Mask, Merge Visible, Flatten Image, Copy Layer Style, Paste Layer Style and Show/Hide All Other Layers, each one undo step, also in the Layers panel's right-click menu where Photoshop has them
- [ ] #2 Selections can be intersected, as well as added to and subtracted from
- [ ] #3 Tests cover each command
<!-- AC:END -->
