---
id: TASK-64
title: One Layer Style dialog for every effect
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:57'
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
- [ ] #1 Layer ▸ Layer Style and the Layers panel's fx menu open one Layer Style dialog
- [ ] #2 Its list shows Lamina's effects in the order docs/DESIGN.md gives; checking one turns it on and selecting one shows its settings
- [ ] #3 Settings use the familiar names (Size for today's Blur, Opacity, Angle, Distance) and preview live
- [ ] #4 OK applies every change as one undo step and Cancel restores the layer exactly
- [ ] #5 Copy, Paste and Clear Layer Style behave as today
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
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
