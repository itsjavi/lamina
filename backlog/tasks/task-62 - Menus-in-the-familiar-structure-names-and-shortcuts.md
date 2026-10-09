---
id: TASK-62
title: 'Menus in the familiar structure, names and shortcuts'
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-54
  - TASK-56
  - TASK-53
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina's menus hold the right commands in unfamiliar places: adjustments directly in Image, Free Transform and Flip in Layer, Expand, Contract and Feather loose in Select, two Snap toggles in View, and some shortcuts that familiar editors use differently (⌘F, ⇧⌘E, ⌥⌘A, ⌘H, ⇧⌫). docs/DESIGN.md has the menu tree and the shortcut changes. Custom shortcuts for menu commands without a default are saved by menu title (KeyboardShortcuts.swift), so renamed items need their saved keys carried over.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The menu bar matches docs/DESIGN.md: menus, items, order, separators, submenus and names, including its in-progress placeholders
- [ ] #2 The shortcut changes in docs/DESIGN.md apply, the Keyboard Shortcuts window shows them, and no two commands share a key
- [ ] #3 Shortcuts people customized for renamed or moved items carry over after the update
- [ ] #4 Edit ▸ Fill… (⇧F5, and ⇧⌫) opens a Fill dialog over the existing fills, while ⌥⌫ and ⌘⌫ still fill directly
- [ ] #5 Select ▸ Load Selection… opens a dialog that replaces Layer's Pixels and Mask's Black Areas
- [ ] #6 View has one Snap toggle and an Extras toggle (⌘H) for grid, guides and selection edges, and Window lists the panels and Workspace
- [ ] #7 Tests cover the shortcut changes, the carried-over custom shortcuts and the two new dialogs
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
