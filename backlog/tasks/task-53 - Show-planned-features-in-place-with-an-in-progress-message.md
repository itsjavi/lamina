---
id: TASK-53
title: Show planned features in place with an in-progress message
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-52
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-9: a feature with an open Backlog task shows its control where it will live, so the layout doesn't shift as features ship and people can see what is coming, and using it says the feature is in progress instead of doing nothing. docs/DESIGN.md (In-progress placeholders) lists the placeholders and the tasks that deliver them. This task builds the shared message and registry; the toolbar, options bar and menu tasks add their placeholders through it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One registry lists each planned feature: its display name and the Backlog task that delivers it
- [ ] #2 Clicking a placeholder, choosing its menu item or pressing its tool key shows a non-blocking message over the canvas, "<Name> is in progress", that goes away after a few seconds or on the next click, and VoiceOver announces it
- [ ] #3 A placeholder never changes the document, the selection or the active tool
- [ ] #4 Placeholders look like shipping controls, and their help tags end with "In progress"
- [ ] #5 Tests check that every registry entry is reachable from the interface and only ever shows the message
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
