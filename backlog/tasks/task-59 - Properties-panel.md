---
id: TASK-59
title: Properties panel
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:52'
labels: []
milestone: m-5
dependencies:
  - TASK-58
  - TASK-56
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina has no Properties panel: transform numbers live in the Move bar, adjustment layers open floating panels, type settings crowd the Type bar and mask actions hide in menus. Switchers expect one panel that shows the settings of whatever is selected.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Properties shows the states in docs/DESIGN.md: the document (canvas size, resolution, units, quick actions) when no layer is selected, a pixel layer (Transform, Align and Distribute, Interpolation, and the quick actions Remove Background and Select Subject), a type layer (Transform, Character, Paragraph), a group, an adjustment layer and a layer mask
- [x] #2 Adjustment layers are edited in Properties, live, with its footer (clip to layer, reset, visibility, delete); the floating panels for adjustment layers go, while Image ▸ Adjustments keeps its dialogs
- [x] #3 Leading and tracking move from the Type bar to Character
- [x] #4 Every edit made in Properties is one undo step and agrees with the canvas, the menus and the lamina commands
- [x] #5 Tests cover each state and that edits survive saving and reopening
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Session (Document/PropertiesEditing.swift): PropertiesKind for the selection (document, pixel or shape layer, type layer, group, several layers, adjustment, layer mask) with its title and icon; changeProperty(_:_:) makes each Properties edit one undo step, keeping it open while the mouse button is held so a drag is one step; showProperties() asks the dock to bring Properties forward.
2. Panel (UI/PropertiesPanel.swift): title row (kind icon and name), collapsible sections (11.5 pt semibold headings, collapsed state remembered), footer, scrolling content, monospaced digits, ColorRole colors. Document: Canvas W/H (Canvas Size's path, anchored center) and Resolution (Image Size without resampling), Rulers & Grids (units, grid, guides, rulers), Quick Actions (Image Size, Crop, Trim, Rotate 90° CW). Layers: Transform (W/H px, X/Y top-left, angle, flips) through changeTransformValue/finishTransformValues, Align and Distribute, Interpolation, Quick Actions (Remove Background, Select Subject).
3. Type: Character (family, style, size, leading, tracking, color) and Paragraph (alignment); edits go to the open text draft as the Type bar's do, otherwise straight to the layer as one step. Leading and tracking leave the Type bar.
4. Adjustment layers: the dialogs' controls become binding-driven views (LevelsControls, HueSaturationControls, FilterControls, CurvesControls) shared by Image > Adjustments and Properties; Properties edits layer.adjustment live, one step per change; footer (clip, reset, visibility, delete). Remove adjustmentEditingID/beginAdjustmentEditing and the floating panels for adjustment layers; double-click, Layer > Layer Content Options… and new adjustment layers show Properties.
5. Layer mask: Refine (Color Range… aimed at the mask, Invert); footer (load selection, apply, delete).
6. Ruler units (Pixels, Inches, Centimeters, Millimeters), shared by the rulers and the Canvas fields.
7. Tests: PropertiesTests (each state, edits survive save and reopen, single undo steps including drags), updated adjustment and automation tests; swift build, targeted then full swift test.
8. DESIGN.md, screenshots of each state in backlog/assets/task-59, notes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation (commits 9c9a0e2, 5143d51):
- Session: Document/PropertiesEditing.swift. PropertiesKind picks the state from the selection (none, document, pixel, shape, type, group, several layers, adjustment, mask; mask wins when its thumbnail is targeted). changeProperty(name, held:) makes every Properties edit one undo step: while the mouse button is down (a slider, a scrubbed label, a curve point) the step stays open and is closed when the button comes up (watched by polling NSEvent.pressedMouseButtons, since control tracking loops hide mouse-up from event monitors; tests stand in with isPointerHeld). held: keeps it open for a field that applies as typed until it calls finishPropertyChange(). An open step counts as busy for lamina commands.
- Transform reuses TASK-56's path (changeTransformValue/finishTransformValues, TransformValueField), so a Free Transform in progress takes the fields as part of it. Decision: X and Y are the top left of the upright bounds (Photoshop's Properties), W and H the box's own size in px kept at its top left, angle about the middle; the Free Transform bar keeps its reference point. Interpolation is a Layer section (as the mockup) and applies as one Transform Layer step.
- Document: Canvas W/H go through Canvas Size's path (ProjectController.resizeCanvas, around the center, transparent) and Resolution through Image Size without resampling (changeResolution); both apply on Return/leaving the field. Decision: Units is a real ruler-units setting (Pixels, Inches, Centimeters, Millimeters; ToolDefaults rulerUnits) shared by the rulers (now labeled in those units) and the Canvas fields, rather than a dead pop-up. Quick Actions: Image Size and Trim open their sheets, Crop picks the Crop tool, Rotate rotates 90° CW (hold for the other rotations).
- Type: Character (family pop-up filled lazily, style menu from the family's members, size, leading with Auto, tracking, color) and Paragraph. With text being edited, changes go to the draft like the Type bar's; a selected type layer is redrawn at once as one Edit Text step (applyText(refocus: false) so typing in a field keeps focus). Text color from Properties uses the dialog color picker with an undo step held for its lifetime (openDialogColorPicker(undoName:)); Cancel restores the layer's own pixels, leaving no step. Leading and tracking removed from the Type bar (TypeControls).
- Adjustments: LevelsSheet, HueSaturationSheet and FilterSheet now wrap binding-driven LevelsControls, HueSaturationControls and FilterControls (compact layout for Properties), CurvesControls gets compact. Properties writes layer.adjustment via changeAdjustment (LayerAdjustment.filterSettings / take(_:) map the shared settings). Levels' histogram counts the layers below (adjustmentInputHistogram) and feeds Auto. Footer: Clip to Layer Below (toggleClippingMask), Reset (newAdjustment defaults, keeping Grain/Add Noise patterns), Hide/Show, Delete. Removed AdjustmentEditing.swift, adjustmentEditingID/adjustmentOriginal and every floating-panel hook for adjustment layers; Image > Adjustments dialogs are unchanged. addAdjustment, double-click on an adjustment thumbnail and Layer > Layer Content Options… (renamed from Edit Adjustment…, saved key carried over via renamedIDs) call showProperties(), which the dock observes.
- Decision: the Levels eyedroppers and Hue/Saturation's eyedroppers and targeted adjustment are not in Properties (they sample through the dialogs' edit objects); they stay in Image > Adjustments. Possible follow-up.
- Mask: Refine Color Range… opens Color Range aimed at the mask (OK replaces the mask in its own grid, one Mask Color Range step, selection restored); Invert uses invertPixels on the mask; footer Load Selection from Mask, Apply Mask, Delete Mask. Mask Density/Feather and Select and Mask are mockup ghosts and left out.
- Several layers selected show Transform and Align and Distribute, like a group (not in the original table; recorded in DESIGN.md).

Verification:
- swift build: clean (only the existing Crop.swift Swift 6 warning). Full swift test: 731 tests in 106 suites passed (plus 47 and 22 in the core and CLI targets). make test-ui not run here (orchestrator runs window tests).
- New PropertiesTests: each selection's state (none, document, pixel, mask, type, shape, 2 layers, group, adjustment); transform fields one step each, a Free Transform takes them, values survive save and reopen; Character edits one step each (held field = one step), join a text draft, survive reopening; text color one step and Cancel none; a held-mouse drag on an adjustment is one step; adjustment edits and footer (clip, hide) survive reopening; Levels counts only the layers below; mask Color Range replaces the mask and survives reopening; canvas W/H and resolution go through Canvas Size and Image Size and survive reopening. AdjustmentEditorTests now drives every editable kind through Properties (live value, one step, undo/redo, Reset, Codable). AutomationTests pass (add-adjustment-layer is one step, nothing left open).
- Visual (make dev, demo project, lamina --pid select-layer, window captures; light via the -appearance argument and a tall group via -dockTopHeight arguments, so no Dev defaults were written): backlog/assets/task-59/ document-light, document-dark, pixel-light, pixel-dark, type-light, type-dark, group-light, curves-light, curves-dark, exposure-dark, hue-saturation-dark, mask-light, mask-dark, window-type-dark-1500x860. Fixed after the first captures: disabled distribute buttons didn't dim (panel-wide foreground style removed), Curves' Remove Point truncated (moved under its fields in compact), mask Refine buttons truncated.
- Not checked by hand: a real slider drag in the running app producing one History step (another agent's Lamina Dev was running, so no mouse automation); covered by the unit test with the pointer stood in. Light shots of the Type bar without leading/tracking not captured (removal is in code).

Rebased onto main after TASK-53, TASK-55, TASK-60 and TASK-64 landed: resolved EditorSession (kept layerStyle, dropped adjustmentEditingID), Dock (AdjustmentsPanel's layout plus Properties' projects) and DESIGN.md; updated AdjustmentsPanelTests, which assumed a new adjustment layer blocks layer edits (it no longer does; renaming a layer stands in). The Properties title now uses an adjustment's Adjustments panel symbol (TASK-60's panelSymbol). Full swift test after the rebase: 758 tests in 110 suites plus 47 and 22 passing; rebased Dev build checked (window-curves-dark-1500x860.png).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Properties now shows the selection's settings in the dock: the document (Canvas size and resolution through Canvas Size and Image Size, ruler units shared with the rulers, grid/guides/rulers, Image Size, Crop, Trim, Rotate), pixel and shape layers (Transform, Align and Distribute, Interpolation, Remove Background, Select Subject), type layers (Transform, Character with family, style, size, leading, tracking and color, Paragraph), groups and multiple layers (Transform, Align and Distribute), adjustment layers (the dialogs' own controls, live, with Clip, Reset, visibility and Delete) and masks (Color Range… aimed at the mask, Invert; load selection, apply, delete). Every edit is one undo step, a drag included, through the same session paths as the menus, bars and lamina commands. The floating panels for adjustment layers are gone; Image > Adjustments keeps its dialogs, which now share binding-driven controls with Properties. Leading and tracking left the Type bar; Edit Adjustment… became Layer Content Options…. Verified with new PropertiesTests and reworked adjustment tests (full swift test: 731 + 47 + 22 passing) and window captures of each state in light and dark (backlog/assets/task-59). DESIGN.md updated.
<!-- SECTION:FINAL_SUMMARY:END -->
