---
id: TASK-18
title: 'Shortcuts for every menu command, and Filter › Last Filter (⌘F)'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/186'
  - 'https://github.com/robbietilton/Compositor/pull/192'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: enhancement
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Only some commands can be given a key, a saved key can't be cleared, and one unreadable saved entry resets all of them (upstream PR #186, which also fixes how Delete is stored). Its 'Menu › Item' names also suit TASK-4's command names. Upstream PR #192 adds Last Filter on ⌘F on top of it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Any menu command can get a shortcut in Edit › Keyboard Shortcuts, and any shortcut can be cleared
- [ ] #2 An unreadable saved shortcut is skipped without resetting the others, and Delete is stored correctly
- [ ] #3 Filter › Last Filter (⌘F) re-runs the last filter with the same settings as one undo step
- [ ] #4 Tests cover both
<!-- AC:END -->
