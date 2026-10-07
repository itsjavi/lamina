---
id: TASK-25
title: History panel
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/146'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: enhancement
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Undo steps can only be walked one at a time. Closed upstream PR #146 included a History panel built on the existing undo stacks (its selection tools aren't worth taking).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A History panel lists the undo steps by name, and clicking one goes back or forward to it
- [ ] #2 A new edit after going back drops the later steps, as in Photoshop
- [ ] #3 Tests cover jumping and editing after a jump
<!-- AC:END -->
