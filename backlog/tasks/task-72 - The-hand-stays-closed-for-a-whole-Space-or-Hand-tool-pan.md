---
id: TASK-72
title: The hand stays closed for a whole Space or Hand tool pan
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/c0a1cd0'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: bug
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A pan sets NSCursor.closedHand once (Rendering/EditorCanvas.swift), but each Space key repeat invalidates the cursor rects and toolCursor hands back the open hand, so the hand reopens partway through a Space pan. Lamina already has a drag-cursor lock (dragCursor, cursorLockWindow, releaseDragCursor). Upstream c0a1cd0 holds the closed hand until mouse up. Port with Co-authored-by: Robbie <1269226+robbietilton@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The pointer stays a closed hand from mouse down to mouse up for Space-drag and Hand tool pans, however long Space is held
- [ ] #2 The open hand (or the tool's pointer) comes back after mouse up
<!-- AC:END -->
