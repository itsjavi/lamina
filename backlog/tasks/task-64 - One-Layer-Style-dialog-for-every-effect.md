---
id: TASK-64
title: One Layer Style dialog for every effect
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:17'
labels: []
milestone: m-5
dependencies:
  - TASK-63
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: feature
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each layer effect opens its own floating panel today. Switchers expect one Layer Style dialog: the effects listed on the left with checkboxes, the selected effect's settings in the middle, and buttons and a preview swatch on the right.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Layer ▸ Layer Style and the Layers panel's fx menu open one Layer Style dialog
- [x] #2 Its list shows Lamina's effects in the order docs/DESIGN.md gives; checking one turns it on and selecting one shows its settings
- [x] #3 Settings use the familiar names (Size for today's Blur, Opacity, Angle, Distance) and preview live
- [x] #4 OK applies every change as one undo step and Cancel restores the layer exactly
- [x] #5 Copy, Paste and Clear Layer Style behave as today
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Model (app, Document/LayerStyle.swift): LayerStylePage (Blending Options, then Stroke, Inner Shadow, Inner Glow, Color Overlay, Outer Glow, Drop Shadow) and a LayerStyleEdit session state holding the layer, the page, the original and working style (effects, blend mode, opacity) and Preview. The working style is written straight into the document with no history step, so the canvas previews it; OK puts the original back and applies the final style in one 'Layer Style' step; Cancel puts the original back with no step.
2. Session API: openLayerStyle(_ page:) (an effect page turns that effect on with today's defaults, as Photoshop's menu does), selectLayerStylePage, setLayerStyleEffect(_:enabled:) for the checkboxes, changeLayerStyle for settings, finishLayerStyle(commit:). The dialog blocks other layer edits, Undo and file operations while open (like Levels); lamina reports it as busy.
3. UI/LayerStyleDialog.swift replaces EffectsSheet: list on the left with checkboxes, the page's settings in titled groups (Structure, Elements, Color, General Blending) with familiar names (Size for Blur, Position for inside/outside, an Angle dial), DialogLayout's column with OK, Cancel, Preview and a preview swatch of the effects on a sample shape. One floating panel in ContentView.
4. Entry points: Layer > Layer Style > Blending Options... and one item per effect (registered in KeyboardShortcuts), the Layers panel fx menu (same items), double-click on an effect row. Copy/Paste/Clear unchanged. Effect color picker edits the working style.
5. Remove the per-effect panel code (addEffect, finishEffectsEditing, changeEffects, effectsEditing).
6. Tests (LayerStyleTests): order, check/uncheck, one undo step, Cancel restores effects, blend mode and opacity, Preview off shows the original, entry from an effect row, busy for automation. Visual check with make dev; screenshots in backlog/assets/task-64.
7. DESIGN.md: Dialogs > Layer Style details and status, menus/fx menu names.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: Document/LayerStyle.swift (LayerStylePage, LayerStyleValues, LayerStyleEdit, EditorSession.openLayerStyle(_:), selectLayerStylePage, setLayerStyleEffect(_:enabled:), changeLayerStyle, setLayerStylePreview, finishLayerStyle(commit:)), UI/LayerStyleDialog.swift (dialog, AngleDial, LayerStyleSwatch) replacing UI/EffectsSheet.swift and the per-effect panel state (effectsEditing, addEffect, changeEffects, finishEffectsEditing). DialogLayout's Preview checkbox became DialogPreviewToggle so Layer Style can put its swatch under it.

Decisions:
- The working style is written into the document outside the history while the dialog is open (Preview off writes the original); OK writes the original back and applies the result inside one 'Layer Style' step, Cancel writes the original back with no step. No transaction is held open.
- Like Levels and the filter dialogs, the open dialog blocks other layer edits (canEditLayers), Undo (canUseHistory) and file operations (canStartProjectOperation, so a save never captures a preview); lamina reports busy 'The Layer Style dialog is open.' (replacing 'Layer effects are being edited.').
- Photoshop's behavior for turning effects on: the checkbox toggles without changing the page; clicking an effect's name, its menu item, the fx menu item or double-clicking its row turns it on (adding today's defaults if absent). On OK an effect added and turned off again in the dialog is dropped; one the layer already had stays hidden (enabled = false), as its eye would leave it.
- Familiar names: Size for Blur, Position (Outside/Inside) for the stroke, an Angle dial plus field (-180 to 180). Groups: Structure / Elements / Color / General Blending as in Photoshop. Blending Options has Blend Mode and Opacity only (no Fill Opacity or Advanced Blending: Lamina lacks them). The list's Blending Options row has no checkbox.
- Order lives in LayerEffectKind.layerStyleOrder (app); LaminaCore's enum order is unchanged, so the Layers panel's effect rows keep their order until TASK-61.
- The swatch draws the style on a gray square on white, scaling effect sizes down when they would overflow 12 pt, at 2x.
- fx menu help/AX label is now 'Add a layer style' (the DESIGN name). The menu items have no default keys; they are assignable (Keyboard Shortcuts > More Menu Commands).
- README/website: no change here; TASK-66 updates README, website and screenshots for the whole familiar workspace.

Visual check (make dev, Golden Hour demo, driven through the menu bar and Accessibility on the Dev app's pid): Layer > Layer Style lists Blending Options... | six effects | Copy/Paste/Clear; Drop Shadow... opened the dialog on its page; clicking Stroke and Inner Glow turned them on and the Layers panel and canvas showed them live; Cancel left the layer as it was with no undo step (lamina describe-document); OK added one 'Layer Style' step that lamina undo reverted. Screenshots: backlog/assets/task-64/drop-shadow-light.png, blending-options-light.png, drop-shadow-dark.png, stroke-dark.png, inner-glow-dark.png. Note: while the Dev app was briefly in front, two unrelated edits (Link Layer Mask, Show Layer) appeared in its history, probably clicks meant for another window; the demo project was never saved.

Tests: LayerStyleTests (12): order and assignable titles, page turns an effect on and checkbox off, OK as one undo step and undo, no step without change, Cancel restores effects/blend mode/opacity exactly, Preview off, invalid values refused, double-click on an effect row, color picker preview/cancel/OK, groups excluded, lamina busy reason, swatch scaling. Full swift test: 722 app tests, 47 and 22 in the other targets, all passing.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
One Layer Style dialog replaces the floating panel each effect opened. Layer > Layer Style > Blending Options... and one item per effect, the Layers panel's fx menu (same items) and a double-click on an effect row open it on that page (EditorSession.openLayerStyle(_ page: LayerStylePage)). The list shows Blending Options then Stroke, Inner Shadow, Inner Glow, Color Overlay, Outer Glow, Drop Shadow with checkboxes; pages use the familiar names in titled groups (Size for Blur, Position, an Angle dial); DialogLayout's column holds OK, Cancel, Preview and a swatch. Changes preview live; OK is one 'Layer Style' undo step; Cancel restores effects, blend mode and opacity exactly; Copy/Paste/Clear Layer Style are unchanged. Verified with LayerStyleTests (12 new), the existing layer-style and automation tests, the full swift test, and a visual check of the Dev app in light and dark (screenshots in backlog/assets/task-64). DESIGN.md documents the dialog, its menu and fx entries.
<!-- SECTION:FINAL_SUMMARY:END -->
