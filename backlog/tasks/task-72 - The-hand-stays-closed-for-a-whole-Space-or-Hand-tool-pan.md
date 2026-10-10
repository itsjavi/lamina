---
id: TASK-72
title: The hand stays closed for a whole Space or Hand tool pan
status: Done
assignee: []
created_date: '2026-10-09 15:51'
updated_date: '2026-10-10 03:47'
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
- [x] #1 The pointer stays a closed hand from mouse down to mouse up for Space-drag and Hand tool pans, however long Space is held
- [x] #2 The open hand (or the tool's pointer) comes back after mouse up
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Port upstream c0a1cd0: a Space or Hand tool pan takes the drag-cursor lock (`dragCursor = .closedHand`, the window's cursor rects off) at mouse down.
2. Release it when the pan ends (`lastDragPoint` back to nil), and put the open hand back there while Space is still held or on the Hand tool.
3. A CursorTests case: Space-drag with the Brush (Space held through, and let go midway) and a Hand tool drag.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ported from upstream c0a1cd0, fitted to Lamina's lock: mouse down on a pan sets `dragCursor = .closedHand` and turns the window's cursor rects off, as crop, transform and guide drags already do, so a Space key repeat's `invalidateCursorRects` can no longer hand back the open hand mid-drag. The pan's end releases it: `lastDragPoint` (the pan's state) releases on going back to nil, at mouse up or when the canvas resigns first responder, and `releaseDragCursor` now also waits for the pan, so ending a crop or transform can't free the pan's lock early. On release, with Space still held or on the Hand tool, the open hand is set right away; otherwise the re-enabled cursor rects bring the tool's pointer back, as before; a release outside the canvas still shows the arrow.

Tests: `CursorTests.panningHoldsTheClosedHandUntilMouseUp` drives the canvas with real mouse and Space key events (Space-drag with the Brush, holding Space throughout with key repeats and letting go midway, then a Hand tool drag): from mouse down to mouse up the cursor is the closed hand and the window's cursor rects stay off at every step; after mouse up they're on again and the cursor is the open hand while Space is held and with the Hand tool. It failed before the change (cursor rects on during the pan, no open hand after) and passes now; CursorTests, CropTests and FreeTransformTests pass.

No screenshot: a pointer can't be captured meaningfully in a window screenshot. What the test can't show is AppKit itself rebuilding cursor rects in a running event loop with the pointer over the canvas, so the pointer through a long Space hold, and the tool's pointer returning after Space was let go mid-pan, were not watched on screen. DESIGN.md doesn't describe the pan's pointer, so it needs no change.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Space and Hand tool pans hold the closed hand from mouse down to mouse up through the canvas's drag-cursor lock (ported from upstream c0a1cd0), and the open hand comes back at mouse up while Space is held or on the Hand tool. Verified by CursorTests.panningHoldsTheClosedHandUntilMouseUp, which failed before the change; no screenshot, since a pointer can't be captured meaningfully.
<!-- SECTION:FINAL_SUMMARY:END -->
