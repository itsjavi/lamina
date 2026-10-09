---
id: TASK-55
title: 'Toolbar in familiar groups, with flyouts and new icons'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:04'
labels: []
milestone: m-5
dependencies:
  - TASK-54
  - TASK-52
  - TASK-53
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 56 pt tool rail lists 16 tools in Lamina's own order, and the Move tool's resize-arrow icon reads as Scale. Switchers expect a single column grouped as in docs/DESIGN.md, flyouts for tools that share a slot, and the four-headed move arrow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A 44 pt single-column toolbar shows the groups, order and separators in docs/DESIGN.md, including the in-progress placeholders listed there
- [ ] #2 A slot shows the last tool used from its group; holding the mouse on it or right-clicking opens a flyout with each tool's icon, name and key
- [ ] #3 The Move tool uses the four-headed arrow, and every tool icon follows the icon rules in docs/DESIGN.md
- [ ] #4 Foreground and background swatches sit at the bottom with the default-colors and swap controls (D, X)
- [ ] #5 Help tags and accessibility labels read "Tool name (Key)", and the toolbar fits an 860 pt window without scrolling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. UI/Toolbar.swift: ToolbarColumn (44 pt, chrome) with one ToolbarSlot per ToolSlot in order, separators before Crop, Eyedropper, Spot Healing, Pen and Hand (ToolSlot.startsGroup), 32 x 30 slots with activeTool/hover backgrounds, corner triangle when a slot has more than one item, ColorPaletteControls at the bottom; IndicatorlessScrollView fallback for short windows.
2. Slot interaction in AppKit (ToolSlotControl over the SwiftUI drawing): click chooses the shown item through choose(_:), holding 0.35 s, right-click or control-click pops a native NSMenu flyout (icon, name, key as key equivalent, current item checked, planned items with their in-progress help tag); hover tracking; accessibility button with label 'Tool name (Key)', selected when active, press and show-menu actions; tool tip = help tag.
3. EditorSession.shownItem(in:) for what a slot shows (active tool in the slot, else last used, else first item).
4. ToolIcon: the one tool -> icon mapping (move NavigationTool.symbol into it); Move four-headed arrow, Hand hand.raised, new DodgeToolIcon (paddle), BurnToolIcon (cupped hand), serif T for Horizontal Type; ToolIcon.menuImage for the flyout.
5. ContentView: replace toolRail with ToolbarColumn.
6. Tests: ToolbarTests (slot display last-used/active, separators, flyout contents and choosing, labels and selected state, height fits 860 pt); update CanvasEntryTests symbol check.
7. DESIGN.md: Toolbar status shipping, iconography notes, workspace layout; screenshots light/dark and a flyout in backlog/assets/task-55/.
<!-- SECTION:PLAN:END -->
