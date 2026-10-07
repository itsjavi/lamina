---
id: TASK-12
title: 'New Canvas: focus Width, units and resolution'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-07 21:47'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Move Image Size's unit conversions into SizeUnit (pixels, percent, inches, centimeters, millimeters at a resolution in ppi) and use it in Image Size, unchanged apart from gaining Millimeters.
2. New Canvas: NewCanvasSize holds width, height, unit (px, in, cm, mm) and resolution as typed, turns them into pixels with SizeUnit and converts the fields when the unit changes; a Units menu and a Resolution field join the dialog, and the summary shows the pixel size for print units.
3. createNewProject/createDocument take the resolution, so the new document keeps it.
4. Focus: re-ask for Width's focus once the window has set up its first responder (the onAppear request was being lost at launch).
5. Tests for the conversions, limits, unit changes and the resolution reaching the document; before/after capture of New Canvas at launch.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Focus at launch (issue #184): in the app the Width request made in onAppear was lost as the window set up its first responder; a test window hosting the view alone focused fine, so this is checked in the app. With the onAppear request only (retry disabled by a temporary switch) the field had no selection, as on main; with the retry after a Task.yield, Width holds the focus with 1920 selected (inactive-window highlight in the background launch).
![New Canvas at launch on main: Width not focused, pixels only](../assets/task-12/new-canvas-before.png)
![New Canvas at launch on this branch: Width focused with 1920 selected, Units and Resolution](../assets/task-12/new-canvas-after.png)
Captures: open -g -n of the baseline app and of make dev's build, no document, window captured with screencapture -l.
swift test --disable-keychain --filter 'NewCanvasTests|ImageSizeTests|CanvasEntryTests|ProjectWorkspaceTests' -> 23 tests in 4 suites passed.
Image Size gains Millimeters as a side effect of sharing the units. Choosing a preset switches New Canvas back to pixels.
<!-- SECTION:NOTES:END -->
