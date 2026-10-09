---
id: TASK-76
title: Options bars scroll in a narrow window instead of squeezing
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/68396ff'
  - 'https://github.com/robbietilton/Compositor/pull/226'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: enhancement
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
OptionsBarRow (UI/OptionsBar.swift) and MoveToolBar lay their controls out in a fixed row, so in a window narrower than the bar (the window can be 800 pt wide) controls squeeze or clip. FreeTransformBar already scrolls horizontally with hidden indicators and keeps Cancel and Commit pinned outside the scroll. Upstream 68396ff (Stv.X, from PR #226) did this per tool header; in Lamina one change in OptionsBarRow covers every bar.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every options bar keeps its controls at full size and scrolls horizontally, without a scroller, when the window is too narrow for it
- [ ] #2 Cancel and Commit stay visible at the bar's right end while an edit is pending
- [ ] #3 At 1500 × 860 pt nothing scrolls, and DESIGN.md's Options bars section says the rule
<!-- AC:END -->
