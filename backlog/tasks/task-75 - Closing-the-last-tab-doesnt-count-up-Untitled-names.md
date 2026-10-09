---
id: TASK-75
title: Closing the last tab doesn't count up Untitled names
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/231'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: bug
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Closing the only tab (its × or ⌘W) when it holds New Document's welcome replaces it with a new empty tab named Untitled 2, then Untitled 3 and so on, because ProjectWorkspace.removeTab adds a tab with addTab(reuseEmpty: false) and nextNumber never resets (upstream issue #231, still open there, reported against the same code). Photoshop dims Close when no document is open.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With no other tabs left, the empty tab is named Untitled and numbering starts again
- [ ] #2 A sole empty tab shows no close button and File › Close is dimmed for it; closing a document's last tab still leaves the welcome tab
- [ ] #3 A test covers closing tabs down to none and the names that follow, and DESIGN.md's tab rules say it
<!-- AC:END -->
