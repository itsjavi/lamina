---
id: TASK-58
title: 'Right dock: Properties and Adjustments over Layers, History as a panel icon'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:33'
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
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today one 252 pt side panel switches between Layers and History. Familiar editors dock tab groups at the right (Properties and Adjustments above Layers) with less-used panels such as History collapsed to icons beside them. The dock is the frame the Properties, Adjustments and Layers panel tasks build in.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The right side holds a column of panel icons (History) and a dock of two tab groups, Properties | Adjustments above Layers, sized as in docs/DESIGN.md
- [ ] #2 The dock can be resized within its range and the split between groups dragged, and both are remembered
- [ ] #3 Clicking the History icon opens the History panel beside the dock and clicking it again closes it; History keeps today's behavior
- [ ] #4 Window lists Adjustments, History, Layers and Properties to show or hide them, and Window ▸ Workspace ▸ Reset Essentials restores the layout
- [ ] #5 In a 1500 × 860 pt window the canvas keeps at least 1100 × 740 pt
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. DockLayout (UI/DockLayout.swift): an @Observable model shared by the window and the Window menu, persisted in UserDefaults: dock width (292, 240...360), top group height (340, clamped so Layers keeps room), closed panels, the top group's front tab, History open (not persisted). show/close/toggle with Photoshop's Window-menu semantics (checked = visible on screen), Reset Essentials.
2. Dock views (UI/Dock.swift): DockGroup (26 pt tab row on panelHeader, underline on the active tab, ≡ menu with Close and Close Tab Group) taking tabs and a content builder; Dock composing Properties | Adjustments over Layers with a draggable split; PanelIconColumn (34 pt, History icon); DockResizeEdge for the dock's left edge and the split; History opens as a floating panel at the canvas column's top right, beside the icon column; clicking the icon again closes it.
3. Empty Properties and Adjustments panels (UI/PropertiesPanel.swift, UI/AdjustmentsPanel.swift) as slots for TASK-59/60; Layers moves in unchanged; HistoryPanel loses the shared SidePanels switcher and its own header.
4. ContentView: replace PanelResizeEdge + SidePanels with the icon column and dock; Layers comes back when renaming or editing an adjustment.
5. Window menu (DockCommands): Workspace ▸ Essentials (Default) │ Reset Essentials │ Adjustments · History · Layers · Properties, assignable shortcuts registered in KeyboardShortcuts.
6. DockLayoutTests (defaults, clamping, visibility semantics, reset, persistence, 1500 × 860 canvas budget); swift build, swift test; make dev and capture 1500 × 860 screenshots (dock, History open); update DESIGN.md.
<!-- SECTION:PLAN:END -->
