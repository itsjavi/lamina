---
id: TASK-55
title: 'Toolbar in familiar groups, with flyouts and new icons'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 09:17'
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
- [x] #1 A 44 pt single-column toolbar shows the groups, order and separators in docs/DESIGN.md, including the in-progress placeholders listed there
- [x] #2 A slot shows the last tool used from its group; holding the mouse on it or right-clicking opens a flyout with each tool's icon, name and key
- [x] #3 The Move tool uses the four-headed arrow, and every tool icon follows the icon rules in docs/DESIGN.md
- [x] #4 Foreground and background swatches sit at the bottom with the default-colors and swap controls (D, X)
- [x] #5 Help tags and accessibility labels read "Tool name (Key)", and the toolbar fits an 860 pt window without scrolling
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped ToolbarColumn (UI/Toolbar.swift) in place of ContentView's toolRail: 44 pt on chrome, 19 slots of 32 x 30 in ToolSlot order with 22 pt separator lines before Crop, Eyedropper, Spot Healing, Pen and Hand (ToolSlot.startsGroup), corner triangle (4 pt, secondaryText) on shared slots, ColorPaletteControls at the foot, IndicatorlessScrollView fallback (now sized to its content, not a fixed 56 pt).
Slots show EditorSession.shownItem(in:) (active tool in the slot, else last used, else first planned item). Interaction is an AppKit ToolSlotControl over the SwiftUI drawing: click -> choose(_:); hold 0.35 s (nextEvent loop), right-click or Control-click -> native NSMenu flyout beside the slot (icon, name, slot key as key equivalent, checkmark on the shown item, planned items with the in-progress tool tip; drag-release chooses). VoiceOver: button labeled 'Tool name (Key)', selected when active, Show Menu opens the flyout.
Decision: macOS 27 leaves NSMenuItem.image out of the menu (verified in the Dev app: no icons rendered), so the flyout draws each icon as a template NSTextAttachment at the start of the attributed title; it tints with the highlight. Accessibility labels stay 'Name (Key)'.
Icons: ToolIcon is now the one mapping (ToolIcon.symbol(for:), NavigationTool.symbol removed, planned tools' symbols moved out of PlannedFeature.symbol, which keeps only the shape-bar controls). Move = arrow.up.and.down.and.arrow.left.and.right, Hand = hand.raised, new DodgeToolIcon (solid paddle on a stick: an outlined one read as Zoom's magnifier), BurnToolIcon (hand cupped under a spot of light, from the mockup's pictogram), TypeToolIcon (serif T in the system serif face).
Verification: ToolbarTests (separators, shown item last-used/active/planned, controls in order with labels, tool tips, selected state and hit-testing, flyout titles/keys/icons/checkmarks/planned tool tips and choosing, every symbol exists and every item renders a menu image, content height <= 783 pt); full swift test passed (730 + 47 + 22 tests). Dev app at 1500 x 860 in light and dark: toolbar fits with about 90 pt to spare; right-click on Shapes and a 0.35 s hold on Dodge opened the flyouts (real CGEvents, frontmost and in-window checks, pointer restored, no key events). Screenshots: backlog/assets/task-55/toolbar-light-1500x860.png, toolbar-dark-1500x860.png, shapes-flyout-light.png, dodge-flyout-hold-light.png (menu window composited onto the window capture). Dev defaults (window frame, appearance) restored.
README/website: not updated here; TASK-66 owns the familiar-workspace screenshots and copy.

Follow-up fix (after m-5): flyouts are now a SwiftUI popover (ToolFlyout) instead of a native menu, so drawn icons (Gradient, Paint Bucket, Clone Stamp, Polygonal Lasso, Object Selection, Dodge, Burn, Type, Palette Knife) take the appearance's colors; in the menu they sat in the item title as template images AppKit doesn't tint, black in dark appearance. Clicks: the first chooses the slot's tool, a click on the active slot opens its flyout, the next closes it; press-and-hold is gone (right-click still opens it). The popover is sized before it shows (it had opened off its slot by half its default height). Verified: ToolbarTests (click sequence, rows, every icon draws, popover beside its slot in a window) and the Dev app in dark with the Gradient and Dodge flyouts opened through Accessibility.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The 56 pt rail is now ToolbarColumn: a 44 pt column of 19 grouped slots (separators per DESIGN.md, planned Pen and Path Selection slots included), each showing its active or last-used item with a corner triangle when shared, a native flyout (icon, name, key, current checked) on a 0.35 s hold, right-click or Control-click, the color swatches with D and X at the foot, and 'Tool name (Key)' help tags and VoiceOver labels. ToolIcon is the single tool -> icon mapping with the four-headed Move arrow and new Dodge, Burn and serif Type icons. Verified with ToolbarTests and the full swift test run, plus Dev-app captures at 1500 x 860 in light and dark and two real flyouts (right-click, hold). DESIGN.md's Workspace layout, Colors, Iconography and Toolbar sections describe what shipped.
<!-- SECTION:FINAL_SUMMARY:END -->
