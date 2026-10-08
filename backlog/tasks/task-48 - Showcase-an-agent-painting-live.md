---
id: TASK-48
title: Showcase an agent painting live
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
labels:
  - agents
  - painting
milestone: m-3
dependencies:
  - TASK-43
  - TASK-45
  - TASK-46
references:
  - brand/README.md
  - scripts/oil-painting-project.swift
priority: low
type: docs
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The website's hero (`web/assets/oil-painting.webp`) shows a painting an agent made by writing PNG layers with `scripts/oil-painting-project.swift`, outside Lamina's brushes and history, while the copy presents agents painting in the app. Once m-3's commands and bristle brushes exist, the showcase should be real.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The generator paints the seascape through `lamina batch` with the oil presets, into layers it creates, one undo step per pass
- [ ] #2 A screen recording of the canvas filling in, for the README and website (alongside TASK-40's intro video)
- [ ] #3 `oil-painting.webp` is recaptured from the agent-painted result, and brand/README.md says how
- [ ] #4 The README and website copy claim only what the app does
<!-- AC:END -->
