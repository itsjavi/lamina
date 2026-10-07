---
id: TASK-15
title: Filter › Unsharp Mask and High Pass
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/196'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina has no sharpening filter; Unsharp Mask and High Pass are Photoshop's standard ones. Upstream PR #196 adds both with live preview and C kernels in AdjustPixels.c.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Filter › Unsharp Mask (amount, radius, threshold) and Filter › High Pass (radius) preview live and apply as one undo step
- [ ] #2 Both are limited to the selection when there is one and keep the layer's size
- [ ] #3 Tests cover both filters
<!-- AC:END -->
