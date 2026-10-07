---
id: TASK-16
title: Align and Distribute layers
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/191'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Aligning and distributing layers is a compositing staple Lamina lacks. Upstream PR #191 adds it but measures each layer's transform box; Photoshop measures visible pixels, so layers with transparent padding would misalign. Adapt that.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Selected layers align by edges or centers to the selection, the canvas or each other, and distribute by centers or spacing
- [ ] #2 Alignment uses each layer's visible pixels, folders move as one, and moves are whole pixels in one undo step
- [ ] #3 Tests cover alignment with transparent padding
<!-- AC:END -->
