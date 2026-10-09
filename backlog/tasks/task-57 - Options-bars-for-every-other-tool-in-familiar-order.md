---
id: TASK-57
title: Options bars for every other tool in familiar order
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 07:23'
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
- [x] #1 Every tool's bar shows the controls, order and names in docs/DESIGN.md, including its in-progress placeholders
- [x] #2 Selection tools use the New, Add and Subtract icon buttons; Feather sets the feather for the next selection, while Select ▸ Modify ▸ Feather… still feathers an existing one; the Object Selection and Magic Wand bars include Select Subject
- [x] #3 Painting tools share a brush picker pop-up holding Size and Hardness; Opacity, Flow, Smoothing and Strength are percent fields with a slider pop-up; the brush bar no longer shows a color swatch or the mask Black / White picker
- [x] #4 Crop, Type and any edit in progress end with Cancel and Commit icon buttons; the Type bar splits font family and style and opens Properties ▸ Character for leading and tracking
- [x] #5 The Hand and Zoom bars offer 100%, Fit Screen and Fill Screen, and the Zoom bar adds zoom in and out and Scrubby Zoom
- [x] #6 Keyboard behavior (1–0 opacity, [ and ] size, Return and Escape) is unchanged and covered by tests
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
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

Rebased onto main after TASK-59 landed (Properties ▸ Character, with its own FontFaces and FontFamilyPopUp): the Type bar uses that FontFaces (family(of:), styles(of:), face(in:like:)) instead of a second copy. Type: FontMenuPicker (generalized from TypeFontPicker: family list loaded once, styles rebuilt per open, names drawn in their faces via StyledName, hover previews kept), size with a textformat.size label, alignment icon buttons, color, Character panel button (DockLayout.shared.show(.properties)), ⊘/✓ while textDraft exists. Edit Text button dropped (clicking text, double-click in Layers edit it). EditorSession.textFontName / textFace(inFamily:) / setTextFont back both pop-ups.

Shapes: Fill: swatch, Stroke: placeholders (colon added), path operations, then Radius: or Weight: (was Width) as OptionsBarField; the sliders went, like every other bar's px fields. ShapeStrokePlaceholders no longer ends with a divider, so the Ellipse bar doesn't end on one.

Navigation: Zoom In/Out icon buttons set zoomToolZoomsOut (a click's direction, Option flips; cursor follows via zoomClickFactor), Scrubby Zoom checkbox (ToolDefaults scrubbyZoom, on by default). Decision: with Scrubby Zoom off a drag zooms one step where it began, like a click; no zoom-rectangle drag (Lamina has no overlay for it; possible follow-up). Hand: 100%/Fit/Fill unchanged. Eyedropper: Show Sampling Ring checkbox. Full swift test: 762 tests passed (after updating SelectionEditTests' mask fill to press D first, since masks now paint the foreground's gray).

Visual check: make dev, launched on scripts/demo-project.swift's project at 1500 × 860, tools chosen through Accessibility (toolbar buttons and their flyouts), each window captured with screencapture -l and cropped to the bar, dark and light (light via the -appearance launch argument, so no Dev defaults changed). Found and fixed a crash: the Type bar's font pop-ups asked an empty menu for item 0 (NSRangeException) — now guarded, with typeBarLaysOutWithItsFontPopUps covering it; the brush picker's px unit was truncated (fixed with fixedSize). Screenshots in backlog/assets/task-57/: <tool>-bar-dark.png and -light.png for the marquee, lasso, Object Selection, Magic Wand, Crop, Eyedropper, Spot Healing, Brush, Clone Stamp, Eraser, Gradient, Paint Bucket, Dodge, Type, Rectangle, Hand and Zoom, blur-bar-dark.png, and the brush picker, gradient presets and Opacity slider pop-overs (light). The Elliptical Marquee, Smudge and Line flyout choices didn't take through Accessibility in this run; their bars differ from the captured ones only by Anti-alias enabled, no Radius, and Weight: instead of Radius:. Not done here: README/website/screenshots (TASK-66 depends on this task for that). Follow-ups worth considering: a zoom-rectangle drag when Scrubby Zoom is off; CharacterProperties (TASK-59) could use EditorSession.textFontName instead of its own faceName.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rebuilt every tool's options bar (except Move/Free Transform) in the order and names of docs/DESIGN.md, from shared pieces: OptionsBarRow, OptionsBarCommitButtons (⊘/✓ at the right end while an edit is pending), OptionsBarIconButton (now with a pressed state), OptionsBarField, PercentField (field + slider pop-over) and OptionsBarPicker. Selection tools: New/Add/Subtract icons, Feather for the next marquee/lasso outline (Select ▸ Modify ▸ Feather… unchanged), Select Subject on Object Selection and Magic Wand. Painting tools: a shared BrushPicker (Size, Hardness, bristle presets in progress for the Brush), percent fields, no swatch or mask Black/White picker; masks paint the foreground's gray and the swatches show gray. Dodge/Burn use Exposure alone (1–0 set it). Crop: familiar ratio names, W ⇄ H, Clear, ⊘/✓. Gradient: preset pop-over, Linear/Radial icons. Paint Bucket: Fill:, All Layers checkbox. Type: family and style pop-ups (TASK-59's FontFaces), alignment icons, Character panel button, ⊘/✓. Shapes: Fill:/Stroke:/Radius:/Weight:. Zoom: Zoom In/Out, Scrubby Zoom; Eyedropper: Show Sampling Ring. DESIGN.md's Options bars section rewritten to match (table, shared pieces, per-bar notes). Verified with swift test (764 tests, new ones for feather, mask gray, crop ratios/swap/clear and Return/Escape, font family/style split and the Type bar's layout, zoom direction, Dodge's number keys) and window captures of each bar in dark and light (backlog/assets/task-57).
<!-- SECTION:FINAL_SUMMARY:END -->
