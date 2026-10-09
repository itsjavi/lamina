---
id: TASK-53
title: Show planned features in place with an in-progress message
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:35'
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
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-9: a feature with an open Backlog task shows its control where it will live, so the layout doesn't shift as features ship and people can see what is coming, and using it says the feature is in progress instead of doing nothing. docs/DESIGN.md (In-progress placeholders) lists the placeholders and the tasks that deliver them. This task builds the shared message and registry; the toolbar, options bar and menu tasks add their placeholders through it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One registry lists each planned feature: its display name and the Backlog task that delivers it
- [ ] #2 Clicking a placeholder, choosing its menu item or pressing its tool key shows a non-blocking message over the canvas, "<Name> is in progress", that goes away after a few seconds or on the next click, and VoiceOver announces it
- [ ] #3 A placeholder never changes the document, the selection or the active tool
- [ ] #4 Placeholders look like shipping controls, and their help tags end with "In progress"
- [ ] #5 Tests check that every registry entry is reachable from the interface and only ever shows the message
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Registry: PlannedFeature (Document/PlannedFeature.swift), CaseIterable, one case per placeholder in DESIGN.md's table (tools, bristle presets, shape stroke/stroke options/path operations, menu items), each with name, Backlog task and home (toolbar slot, menu path, options-bar tools); help tags '<label> · In progress'.
2. Message: EditorSession.inProgressNotice + showInProgress(_:) / dismissInProgressNotice(); one at a time (a new one replaces the old), gone after 3 s; VoiceOver announcement (NSAccessibility announcementRequested). InProgressNoticeView over the top center of the canvas (system material, color roles), with a local mouse-down monitor that dismisses it on the next click. Never goes through selectTool, so the document, selection, tool and slotTools stay as they were.
3. Slot model: SlotItem (.tool / .planned) and ToolSlot.items in flyout order; new slots .pen (P) and .pathSelection (no key until TASK-28; A stays No Tool); ToolSlot.key optional, tool(in:) optional. pressToolKey: a planned item shows its message; Shift-cycling continues from a showing planned notice of the same slot, so Shift-U reaches Line past Polygon and Star.
4. Rail lists ToolSlot items (planned ones show the message); ToolIcon draws planned tools (SF Symbols, custom Palette Knife).
5. Menus: File > Save a Copy... (opt-cmd-S, registered in ShortcutDefinition.all), Layer > Rasterize, Convert to Editable Vectors, Combine Shapes > (4 items), Release to Layers, Window > Contextual Task Bar; assignable titles from the registry.
6. Options bars: Brush bar Presets pop-up (4 bristle presets); Rectangle/Ellipse/Line: Fill, Stroke swatch, width, stroke options | path operations | Radius/Width.
7. Tests (PlannedFeatureTests, ToolSlotTests updated), DESIGN.md placeholder section, screenshot in backlog/assets/task-53/.
<!-- SECTION:PLAN:END -->
