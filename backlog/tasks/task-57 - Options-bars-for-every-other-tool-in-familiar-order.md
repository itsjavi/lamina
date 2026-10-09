---
id: TASK-57
title: Options bars for every other tool in familiar order
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 06:56'
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
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each tool's bar orders and names its controls its own way: a Mode picker instead of selection icons, a Feather button that blurs the current selection, Size and Hardness as fields, a color swatch in the brush bar, This Layer / All Layers pickers, Apply and Cancel text buttons. docs/DESIGN.md lists each tool's bar in the order switchers expect.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every tool's bar shows the controls, order and names in docs/DESIGN.md, including its in-progress placeholders
- [ ] #2 Selection tools use the New, Add and Subtract icon buttons; Feather sets the feather for the next selection, while Select ▸ Modify ▸ Feather… still feathers an existing one; the Object Selection and Magic Wand bars include Select Subject
- [ ] #3 Painting tools share a brush picker pop-up holding Size and Hardness; Opacity, Flow, Smoothing and Strength are percent fields with a slider pop-up; the brush bar no longer shows a color swatch or the mask Black / White picker
- [ ] #4 Crop, Type and any edit in progress end with Cancel and Commit icon buttons; the Type bar splits font family and style and opens Properties ▸ Character for leading and tracking
- [ ] #5 The Hand and Zoom bars offer 100%, Fit Screen and Fill Screen, and the Zoom bar adds zoom in and out and Scrubby Zoom
- [ ] #6 Keyboard behavior (1–0 opacity, [ and ] size, Return and Escape) is unchanged and covered by tests
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shared bar pieces in UI/OptionsBar.swift (or a sibling file): OptionsBarToggleButton (24x22 icon toggle on activeTool), OptionsBarCommitButtons (Cancel ⊘ / Commit ✓ at the right end), PercentField (label: scrubbable, field + %, chevron opening a slider pop-up), OptionsBarNumberField (label:, field, unit), BrushPicker (tip preview with size under it; pop-up with Size and Hardness, plus the bristle presets as in-progress entries for the Brush).
2. Selection tools: New/Add/Subtract icon buttons; Feather: N px for the next marquee or lasso outline (new session value, default 0, applied in finishLasso; Select ▸ Modify ▸ Feather… unchanged); Anti-alias (dimmed for rectangles); Object Selection: Sample All Layers, Edge, Select Subject; Magic Wand: Sample Size, Tolerance, Anti-alias, Contiguous, Sample All Layers, Select Subject. Drop Expand/Contract/Feather buttons, Deselect and the empty readout.
3. Painting tools: one BrushControls built from the shared pieces in the spec's order per tool; no Color swatch, no mask Black/White picker. Mask painting uses the foreground color's gray value (maskPaintWhite goes; swatches show gray while a mask is targeted; D/X give black and white). Liquify's Cancel/Done become icon buttons.
4. Crop: Ratio pop-up with familiar names (built-ins + 9:20, 2.39:1, then remembered ratios), W ⇄ H fields with swap and Clear replacing Custom…, Cancel/Commit icons while a crop is pending.
5. Gradient: preset swatch pop-up, Linear/Radial icon buttons, Opacity, Reverse, Cancel/Commit icons while pending. Paint Bucket: Fill: Foreground, Opacity, Tolerance, Anti-alias, Contiguous, All Layers.
6. Type: font family and style pop-ups (split TypeFontPicker), size, alignment icons, color, Character panel button (DockLayout.show(.properties)), Cancel/Commit icons while editing. Leave Tracking/Leading lines for TASK-59.
7. Shapes: Fill: swatch, stroke placeholders, path operations, Radius: / Weight:. Colons on every label.
8. Navigation: Zoom In/Out icon buttons (session zoomsOut; Option flips), Scrubby Zoom checkbox (persisted; off = a drag zooms one step like a click), 100%/Fit/Fill. Eyedropper: Show Sampling Ring.
9. Tests: feather for next selection, mask gray painting, crop ratio names/sides/swap/clear, font family/style split, zoom direction, keyboard (digits, brackets) still drive the bar's values. DESIGN.md table and notes updated per slice; screenshots in backlog/assets/task-57/.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Selection tools: SelectionModeButtons (New/Add/Subtract icons, pressed while Shift/Option or an outline applies), Feather: px sets EditorSession.selectionToolFeather for the next marquee/lasso outline (applySelection(feather:)); adding to or subtracting from a softer selection keeps the softer edge, since a selection has one edge softness. Expand/Contract/Feather buttons, Deselect and the empty-selection readout left the bar (Select ▸ Modify and ⌘D cover them). Object Selection keeps Anti-alias (it changes the result) as a Lamina extra. Shared pieces: OptionsBarRow, OptionsBarCommitButtons, OptionsBarIconButton (now generic, with isPressed), OptionsBarField, PercentField, OptionsBarPicker (UI/OptionsBar.swift, UI/OptionsBarFields.swift).

Painting tools: BrushPicker (tip preview + size; pop-over with Size in square-root slider steps and Hardness, plus BristlePresetList for the Brush, replacing BristlePresetsMenu). PercentField for Opacity/Flow/Smoothing/Strength/Exposure. Pressure toggles only where pressure works (Brush, Eraser; size for Dodge/Burn), so the spec's pressure buttons on Spot Healing, Clone Stamp, Blur/Smudge were left out and the rows updated. Mask painting: maskPaintWhite removed; a targeted mask paints the foreground's gray (PaletteColor.gray, Rec. 601; exact for grays), the swatches show gray (paletteColor), D/X reset and swap the real colors; the toolbar swatch's Black/White pop-over stays as a quick pick. Dodge/Burn: strokes take Exposure only (Opacity, Flow, opacity pressure and Smoothing, which their bar doesn't show, no longer apply) and 1–0 set Exposure; Blur/Smudge/Liquify's Strength is the opacity the keys already set. Spot Healing keeps Opacity as a Lamina extra (healing honors it). Liquify's Cancel/Done became ⊘/✓.

Crop: Ratio pop-up shows CropRatio.title (Free → Ratio, Original → Original Ratio, 1:1 → 1:1 (Square)); 9:20 and 2.39:1 joined the built-ins. W ⇄ H fields (cropRatioSides, swapCropRatio, clearCropRatio) replace the Custom… pop-over: typing both sides + Return chooses and remembers the ratio. The crop's pixel size stays after Clear as a readout. Cancel/Commit icons only while cropRect exists; Return/Escape stay with the canvas. The Custom… window test went with the pop-over; CropRatioTests covers names, sides, swap and clear.

Gradient: preset swatch pop-over (GradientSwatch per GradientStyle), Linear/Radial as GradientShapeIcon icon buttons, Opacity PercentField, Reverse, ⊘/✓ while gradientEdit is pending (was Cancel/Apply text). Paint Bucket: Fill: Foreground pop-up (one item), Opacity, Tolerance, Anti-alias, Contiguous, All Layers checkbox.
<!-- SECTION:NOTES:END -->
