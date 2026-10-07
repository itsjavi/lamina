---
id: TASK-21
title: 'Brush flow and pen pressure, as in Photoshop'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
  - brush
milestone: m-1
dependencies:
  - TASK-20
references:
  - 'https://github.com/robbietilton/Compositor/issues/63'
  - 'https://github.com/robbietilton/Compositor/pull/106'
  - 'https://github.com/robbietilton/Compositor/pull/194'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decided in doc-1: add Flow and pen pressure the way Photoshop does, so they're familiar to people coming from it. Sources: closed PR #106 (flow), open PR #194 (pressure; only tested with simulated events), upstream issue #63.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Flow sits next to Opacity: each dab lays down that share of paint, building up within a stroke up to the stroke's opacity
- [ ] #2 Two options-bar toggles apply pen pressure to size and to opacity; mouse and trackpad strokes are unchanged
- [ ] #3 Checked by hand with a real pen tablet, and tests cover flow and simulated pressure
<!-- AC:END -->
