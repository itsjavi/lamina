---
id: TASK-12
title: 'New Canvas: focus Width, units and resolution'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/184'
  - 'https://github.com/robbietilton/Compositor/issues/185'
  - 'https://github.com/robbietilton/Compositor/issues/151'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: enhancement
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
New Canvas doesn't focus or select the Width field when it opens (upstream issue #184), and it only takes pixels at 72 ppi, while Image Size already converts units and resolution (issues #185, #151).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Opening New Canvas focuses the Width field with its text selected
- [ ] #2 Width and height can be entered in px, in, cm or mm with a resolution in ppi, reusing Image Size's conversions, and the new document keeps that resolution
- [ ] #3 Tests cover the conversions
<!-- AC:END -->
