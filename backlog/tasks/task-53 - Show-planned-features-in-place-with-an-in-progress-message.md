---
id: TASK-53
title: Show planned features in place with an in-progress message
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:54'
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
- [x] #1 One registry lists each planned feature: its display name and the Backlog task that delivers it
- [x] #2 Clicking a placeholder, choosing its menu item or pressing its tool key shows a non-blocking message over the canvas, "<Name> is in progress", that goes away after a few seconds or on the next click, and VoiceOver announces it
- [x] #3 A placeholder never changes the document, the selection or the active tool
- [x] #4 Placeholders look like shipping controls, and their help tags end with "In progress"
- [x] #5 Tests check that every registry entry is reachable from the interface and only ever shows the message
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented (389f281, 2b60e02):
- Registry: PlannedFeature (Sources/LaminaApp/Document/PlannedFeature.swift), one case per name in DESIGN.md's placeholder table (23: seven tools, four bristle presets, Shape Stroke, Stroke Options, Path Operations, Save a Copy, Rasterize, Convert to Editable Vectors, the four Combine Shapes items, Release to Layers, Contextual Task Bar), each with name, task, home (.toolbar / .menu(path) / .optionsBar(tools)), label, helpTag ('<label> · In progress') and message.
- Message API: EditorSession.showInProgress(_:for:) sets inProgressNotice (InProgressNotice: feature + id; a new one replaces the old; its 3 s timer only clears its own) and posts an NSAccessibility announcementRequested (announceInProgress, swappable in tests); dismissInProgressNotice(). InProgressNoticeView (UI/InProgressNoticeView.swift) sits in ContentView's canvas ZStack: regularMaterial capsule, 12 pt text role, edge outline, no hit testing; a local mouse-down monitor while it shows dismisses it and lets the click through.
- Slot model for TASK-55: SlotItem (.tool / .planned) and ToolSlot.items in DESIGN.md flyout order; ToolSlot.tools still lists only working tools. New slots .pen (key p) and .pathSelection (key nil: A stays No Tool). ToolSlot.key and tool(in:) are now optional. EditorSession.choose(_:) is the one entry for rail/flyout/key: a tool → selectTool, a planned item → showInProgress (never selectTool, so tool, slotTools, transforms, crops, selection and history stay put). pressToolKey: Shift steps from a showing planned notice of the same slot, otherwise from the active tool, so Shift-U goes Rectangle, Ellipse, Polygon, Star, Line, Rectangle and Shift-B Brush, Mixer, Palette Knife, Brush.
- Rail lists ToolSlot items; ToolIcon now takes a SlotItem (init(tool:) kept): pencil.tip, cursorarrow, point.topleft.down.to.point.bottomright.curvepath, paintbrush, custom PaletteKnifeToolIcon, hexagon.fill, star.fill.
- Menus (UI/PlannedControls.swift PlannedMenuItem): File > Save a Copy… ⌥⌘S after Save As… (registered as 'Save a Copy' in ShortcutDefinition.all), Layer > Rasterize and Convert to Editable Vectors after Apply Layer Mask, Combine Shapes > 4 items and Release to Layers after Move Layer Down, Window > Contextual Task Bar (CommandGroup before .windowList, inside the existing Group since the commands builder is at 10). Their paths join ShortcutDefinition.assignableMenuCommands via PlannedFeature.assignableMenuCommands. Canvas list gained 'Pen tool' (P) and 'Next brush tool' (Shift-B).
- Bars: BristlePresetsMenu ('Presets' pop-up, first in the Brush bar, Brush only); ShapeStrokePlaceholders (Stroke 'none' swatch, '1 px', stroke options icon │ path operations │); ShapeControls reordered to Fill, stroke, │ path ops │, Radius/Width as DESIGN.md says. OptionsBarDivider added to OptionsBar.swift.
Decisions: Path Selection slot has no key until TASK-28 (A stays No Tool, per spec). Bar labels keep today's no-colon wording (TASK-57 adds colons). Placeholder menu items are enabled always; shape-bar placeholders follow the bar's existing disabled-without-document rule. macOS draws no help tags on menu items, so the menu placeholders' .help has no visible effect; tools and bar controls show '… · In progress' (checked over AX).

Verification:
- swift test: 706 tests in 104 suites passed (window tests skipped as usual). PlannedFeatureTests: registry vs DESIGN.md table (each name with its task), reachability (slot items in toolbar order, menu paths known to Keyboard Shortcuts, Save a Copy ⌥⌘S, bar features), placeholders only show the message (document, tool, slotTools, active layer, history position, modified flag unchanged; P, Shift-B cycling; VoiceOver announcement for each), message replaces/times out/dismisses. ToolSlotTests and ShapeToolTests updated (Shift-U passes Polygon and Star).
- Window test theNextClickTakesTheMessageAway (.showsWindows) ran once alone with LAMINA_UI_TESTS=1: passed (a posted mouse down dismisses through the monitor).
- Dev app at 1500 × 860, driven over the Accessibility API: Pen rail button shows 'Pen Tool is in progress' at the canvas top center with Move still active, gone after 3 s; Rectangle bar shows Fill, Stroke swatch, 1 px, stroke options │ path ops │ Radius; Stroke swatch press shows 'Shape Stroke is in progress'; every planned tool and bar control reports its '… · In progress' help; Presets pop-up in the Brush bar; all six placeholder menu items enabled and pressed (Save a Copy shows ⌥⌘S), the last showing 'Contextual Task Bar is in progress'; light appearance checked with Polygon (appearance default set and removed again). Screenshots: backlog/assets/task-53/pen-in-progress-dark.png, shape-bar-stroke-in-progress-dark.png, polygon-in-progress-light.png.
- Not covered by automation: pressing the SwiftUI bar controls from unit tests (SwiftUI builds no accessibility tree without an AX client), so the bars and menus were checked in the running app instead.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Planned features now show where they will live and say '<Name> is in progress' when used. PlannedFeature is the one registry (name, Backlog task, home) for every row of DESIGN.md's placeholder table; EditorSession.showInProgress is the one action, drawn by InProgressNoticeView over the top center of the canvas (system material, color roles), gone after 3 s or the next click, announced to VoiceOver, never touching the document, selection, tool or slots. Planned tools are SlotItem.planned entries of ToolSlot.items (new Pen slot on P, Path Selection slot without a key), reachable from the rail, their key and Shift-cycling; menus gain Save a Copy… (⌥⌘S), Rasterize, Convert to Editable Vectors, Combine Shapes ▸, Release to Layers and Window ▸ Contextual Task Bar; the Brush bar gets bristle presets and the shape bars stroke and path-operation placeholders. Verified with swift test (706 passed), the window click test run alone, and the Dev app driven over Accessibility in dark and light; DESIGN.md documents the API and placements.
<!-- SECTION:FINAL_SUMMARY:END -->
