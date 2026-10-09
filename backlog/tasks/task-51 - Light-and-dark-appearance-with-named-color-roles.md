---
id: TASK-51
title: Light and dark appearance with named color roles
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina forces dark mode (`.preferredColorScheme(.dark)` in ContentView) and paints its chrome with literal grays such as `Color(white: 0.14)`. People who run macOS in light mode get a dark island, and every view picks its own shade, so nothing lines up once the redesign adds panels. docs/DESIGN.md defines the color roles (window, chrome, panel, field, control, separator, selection, pasteboard and text levels) with light and dark values (decision-9).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The app follows the macOS appearance and switches live when it changes
- [ ] #2 Lamina ▸ Settings… (⌘K) opens a Settings window whose Appearance setting (System, Light, Dark) overrides it, remembered across launches
- [ ] #3 Every interface color comes from the roles in docs/DESIGN.md, defined once with light and dark values; no literal grays remain in interface code (document content and canvas overlays excepted)
- [ ] #4 Floating panels, sheets, alerts and the Camera Raw panel follow the same appearance
- [ ] #5 The pasteboard around the canvas uses its role, and canvas overlays (transform box, handles, selection outline, guides, grid) stay legible in both appearances
- [ ] #6 Screenshots of the editor in both appearances are attached to the task
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
