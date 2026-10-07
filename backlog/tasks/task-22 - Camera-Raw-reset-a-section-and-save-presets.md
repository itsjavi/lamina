---
id: TASK-22
title: 'Camera Raw: reset a section and save presets'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies:
  - TASK-10
references:
  - 'https://github.com/robbietilton/Compositor/pull/187'
  - 'https://github.com/robbietilton/Compositor/pull/198'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: enhancement
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Camera Raw can only be reset as a whole and its settings can't be saved. Upstream PR #187 adds a reset per section and PR #198 named presets (stored in Application Support, no project format change; it also makes the settings Codable, which helps TASK-2 and TASK-4).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each Camera Raw section has a reset button that restores its defaults
- [ ] #2 Settings can be saved and applied as named presets; an unreadable presets file is kept aside, not overwritten
- [ ] #3 Tests cover resets and presets
<!-- AC:END -->
