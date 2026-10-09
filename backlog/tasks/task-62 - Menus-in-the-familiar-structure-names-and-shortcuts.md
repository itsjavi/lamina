---
id: TASK-62
title: 'Menus in the familiar structure, names and shortcuts'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:37'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Menus (LaminaMain.swift): rebuild every menu to DESIGN.md's tree and menu-bar order (Lamina, File, Edit, Image, Layer, Type, Select, Filter, View, Window, Help), with its names, submenus, separators and placeholders; Remove Background moves to Layer; View built as a CommandMenu after Filter; Help keeps only Search.
2. Shortcuts (UI/KeyboardShortcuts.swift): apply the Shortcut changes table (⌃⌘F, ⇧⌘E, ⌥⌘A freed, ⌘H Extras, ⌃⌘H Hide, ⇧F5 Fill with ⇧⌫ as a second key, ⌘B, ⌥⇧⌘B, ⇧⌘A, ⇧⌘R, ⇧F6, ⌘, Hide Layers, ⌥⇧⌘K, ⌥⇧⌘W); function keys in ShortcutChord; ⌘, no longer reserved; renamed entries and every moved or renamed More Menu Commands title carried over through renamedIDs (resolved transitively, a key saved under the current id wins); ⌥⌫/⌘⌫ become window-wide keys without menu items.
3. Edit > Fill...: FillContents/FillOptions and EditorSession.fill (foreground, background, color, black, 50% gray, white, opacity; Content-Aware opens today's Content-Aware Fill); FillDialog in DialogLayout, a floating panel like the selection dialogs.
4. Select > Load Selection...: channels (each layer's Transparency, each mask as a document-sized channel), Invert, New/Add/Subtract; LoadSelectionDialog in DialogLayout; replaces Layer's Pixels and Mask's Black Areas.
5. View: one Snap (snapEnabled, saved as 'snap'; the session-only snappingEnabled folds into it); Extras (saved as 'extras') hides grid, guides, pixel grid and selection edges and turning one of them on shows Extras again.
6. Layer commands the new names need: Layer Mask submenu items, Hide Layers for the selected layers, Delete > Layer, New > Layer.../Group.../Group from Layers... and Duplicate Layer... open the new layer's name for editing.
7. Tests: shortcut changes and collisions, carried-over custom keys, Fill (each content kind, opacity, mask), Load Selection (transparency, mask, invert, operations), Extras, Snap.
8. DESIGN.md, README facts (Last Filter key), brand/README step names; Accessibility dump of the menu bar, screenshots of both dialogs.
<!-- SECTION:PLAN:END -->
