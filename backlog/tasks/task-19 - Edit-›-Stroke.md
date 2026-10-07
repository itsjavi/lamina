---
id: TASK-19
title: Edit › Stroke
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/177'
  - 'https://github.com/robbietilton/Compositor/pull/190'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: feature
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Stroking a selection's outline is a standard Photoshop command (upstream issue #177). Upstream PR #190 implements it; on masks it uses the red channel where it should use luminance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Edit › Stroke draws along the selection's outline with width, color, opacity and Inside, Center or Outside, as one undo step
- [ ] #2 It works on pixels and on masks (by luminance)
- [ ] #3 Tests cover the three positions
<!-- AC:END -->
