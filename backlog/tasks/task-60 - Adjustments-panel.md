---
id: TASK-60
title: Adjustments panel
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:32'
labels: []
milestone: m-5
dependencies:
  - TASK-58
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adding an adjustment layer takes the Layers panel's menu today. Familiar editors offer an Adjustments panel: a grid of labeled icons that add one in a click.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Adjustments shows Lamina's adjustment kinds as a grid of labeled icons in the order docs/DESIGN.md gives, with Lamina's filter layers (Gaussian Blur, Motion Blur, Add Noise) in their own section
- [x] #2 Clicking one adds that adjustment layer above the active layer as Layer ▸ New Adjustment Layer does, as one undo step, and shows it in Properties
- [x] #3 Help tags name each adjustment, and the grid reflows with the dock's width
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. AdjustmentsPanel.swift: AdjustmentsPanel.items (Single adjustments order) and filterLayers, with one kind→SF Symbol map (AdjustmentKind.panelSymbol). 2. Grid: LazyVGrid with adaptive columns (min ~62 pt: four per row at 292 pt, three at 240), cells of a 18 pt icon over a 10 pt label, hover on ColorRole.hover, icon in ColorRole.icon, help tag and accessibility label naming the adjustment. 3. Filter layers section heading with a small Lamina tag. 4. Clicking calls session.addAdjustment(kind) (the menu's path, one undo step, selects the layer) and DockLayout.show(.properties); disabled like the menu (no document or !canEditLayers). Dock passes its layout in. 5. Tests (AdjustmentsPanelTests): order and kinds, every symbol exists, click adds above the active layer as one undo step, Properties forward, disabled rule. 6. DESIGN.md: symbols and grid details; screenshots light/dark in backlog/assets/task-60/.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Panel: UI/AdjustmentsPanel.swift. Order and sections in AdjustmentsPanel.adjustments / filterLayers; one kind→SF Symbol map in AdjustmentKind.panelSymbol (all symbols checked to exist and be distinct in tests). Invert uses circle.lefthalf.filled.inverse so it reads as the mirror of Black & White (circle.lefthalf.filled).
- Grid: LazyVGrid with adaptive 62 pt columns (four per row at 292 pt, three at 240), 18 pt icon over a 10 pt label, ColorRole.icon, ColorRole.hover under the pointer; help tag and accessibility label per cell. Icon size follows the mockup (18 pt), so DESIGN.md's Iconography sizes now list the Adjustments grid at 18 pt.
- Filter layers heading carries a small 'Lamina' tag drawn in secondaryText on control (the mockup's tag color is a review aid, not an app color).
- Click: AdjustmentsPanel.add calls session.addAdjustment(kind) (the same command as Layer ▸ New Adjustment Layer: one undo step, inserted above the active layer, selected) then DockLayout.show(.properties). Dock now passes its layout to AdjustmentsPanel. Until TASK-59 lands, the adjustment's settings still open through the Layers panel (addAdjustment sets adjustmentEditingID, which DockArea answers by showing Layers); Properties is in front of the top group either way.
- Enable rule copied from the menu: document != nil && canEditLayers; the whole grid is disabled (dimmed) otherwise.
- Screenshots (Dev app, demo project, Adjustments tab via dockTopTab default, restored afterwards): backlog/assets/task-60/adjustments-light.png, adjustments-dark.png.
- Checks: swift build; swift test --filter AdjustmentsPanelTests (4 tests); full swift test 740 tests passed. make test-ui not run (orchestrator runs it).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The Adjustments tab now shows Lamina's adjustment kinds as a grid of labeled SF Symbol icons (Grain, Levels, Curves, Exposure, Hue/Saturation, Color Balance, Black & White, Invert, Gradient Map) and a 'Filter layers' section tagged Lamina (Gaussian Blur, Motion Blur, Add Noise). Columns adapt to the dock's width. A click runs the same command as Layer ▸ New Adjustment Layer (one undo step, above the active layer, selected) and brings Properties forward; the grid is disabled under the menu's rule. Help tags and accessibility labels name each item. AdjustmentsPanelTests cover order, symbols, the click and the enable rule; DESIGN.md records the symbols, sizes and behavior. Follow-up: TASK-59 makes Properties show the new layer's controls.
<!-- SECTION:FINAL_SUMMARY:END -->
