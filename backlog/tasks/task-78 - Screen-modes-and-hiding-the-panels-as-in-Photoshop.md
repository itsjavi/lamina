---
id: TASK-78
title: 'Screen modes and hiding the panels, as in Photoshop'
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/188'
  - 'https://github.com/robbietilton/Compositor/commit/ad4bddf'
  - 'https://github.com/robbietilton/Compositor/commit/720c121'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's View ▸ Screen Mode (Standard Screen Mode, Full Screen Mode With Menu Bar, Full Screen Mode; F cycles, Shift-F backwards, Esc leaves) and Tab to hide every panel (Shift-Tab all but the toolbar and options bar) let people work on the image alone. Lamina has only macOS's Enter Full Screen. Upstream did its own Canvas Only mode on F (ad4bddf, 088a5c1, 720c121), which isn't Photoshop's; closed PR #188 tried Photoshop's modes. Reusable: #188's ScreenModeController (a testable window protocol, following the green button) and ad4bddf's window handling (menu bar and Dock hidden, frame restored). State belongs to the window, not the document, and hiding panels must not touch the saved dockClosedPanels. Research: doc-4 (Photoshop features).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 View ▸ Screen Mode has Photoshop's three modes, F cycles them, Shift-F backwards, and Esc leaves a full screen mode after the canvas's own Escape uses
- [ ] #2 Tab hides or shows the toolbar, options bar, dock and panel icon column; Shift-Tab only the dock and icon column; the dock's saved layout is unchanged
- [ ] #3 F, Shift-F, Tab and Shift-Tab are listed in Keyboard Shortcuts, and DESIGN.md's View menu and Shortcut changes say how they work
- [ ] #4 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
