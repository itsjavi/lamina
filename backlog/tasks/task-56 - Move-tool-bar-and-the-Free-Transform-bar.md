---
id: TASK-56
title: Move tool bar and the Free Transform bar
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:51'
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
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Move tool's bar holds X, Y, W, H, Scale, angle, Sampling and Flip, so the Move tool doubles as a transform panel and ⌘H toggles its controls. Familiar editors keep the Move bar to Auto-Select, transform controls and alignment, show the numbers in a Free Transform bar only while transforming (⌘T or dragging a handle), and otherwise keep them in the Properties panel.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Move bar shows Auto-Select, Show Transform Controls, the align and distribute buttons (dimmed until two or more layers are selected) and a menu with the rest of Align and Distribute
- [x] #2 Transforming a layer or a selection (Edit ▸ Free Transform, ⌘T, or dragging a handle) shows the Free Transform bar: reference point, X and Y, W and H in percent with a link, angle, Interpolation, and Cancel and Commit at the right end
- [x] #3 Interpolation offers Nearest Neighbor, Bilinear and Bicubic, mapped from today's Nearest, Smooth and High quality without changing saved projects
- [x] #4 Flip Horizontal and Flip Vertical move to Edit ▸ Transform, and ⌘H no longer toggles transform controls
- [x] #5 Each transform is still one undo step and the existing transform tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Split UI/TransformInspector.swift into the Move bar (MoveToolBar: Auto-Select, Show Transform Controls, align and distribute icon buttons dimmed below two layers, a ••• Align & Distribute menu) and the Free Transform bar (FreeTransformBar: 3x3 reference point, X/Y of the reference point, W/H % of the layer's pixels with the Maintain Aspect Ratio link, angle, Interpolation, Cancel and Commit icon buttons). ContentView picks the Free Transform bar while transformEdit is persistent.
2. Reference point: EditorSession.transformReference (unit point), LayerTransform helpers that move, resize and rotate about it (typed values and rotate drags pivot there); the overlay marks it while transforming.
3. Interpolation names (Nearest Neighbor, Bilinear, Bicubic) as a display-only mapping of LayerSampling; group transforms carry the chosen interpolation to their layers.
4. Handle drags (resize, rotate, distort) start a pending Free Transform that waits for Commit/Return or Cancel/Escape, one undo step; body drags and nudges still apply on release.
5. Menus: Edit > Free Transform (Cmd-T) and Edit > Transform > Distort, Flip Horizontal, Flip Vertical (flips the pending draft while transforming); remove Layer > Transform Layer/Selection and Flip Layer; drop Cmd-H from View > Show Transform Controls (assignable now). Shortcut registry renames with renamedIDs so saved keys carry over.
6. Tests for the reference-point math, interpolation names, handle-drag pending behavior, flip/distort commands and shortcut carry-over; swift build + swift test.
7. DESIGN.md: record what shipped and decisions; screenshots of both bars in backlog/assets/task-56/.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped: UI/MoveToolBar.swift (Move bar) and UI/FreeTransformBar.swift (FreeTransformBar, ReferencePointPicker, TransformValueField; was TransformInspector.swift). ContentView shows FreeTransformBar while transformEdit?.persistent == true. OptionsBarDivider and OptionsBarIconButton (UI/OptionsBar.swift) are shared for TASK-57.
Reuse for TASK-59 (Properties > Transform): EditorSession.changeTransformValue(_:) / finishTransformValues() (a field with nothing pending opens a fromFields edit committed when the field is done; during a Free Transform it joins it), EditorSession.transformReference, LayerTransform.moving(_:to:) / resized(to:keeping:) / rotated(to:about:) / referencePoints, LayerSampling.interpolationName, TransformValueField, EditorSession.flipTransform(horizontally:) / canFlipTransform.
Decision, handle drags: a press on a handle (resize, rotate, Cmd-distort) starts a persistent Free Transform, as in familiar editors; more drags, typed values, flips and nudges join it and Commit/Return applies one undo step, Cancel/Escape reverts. A press inside the box (or anywhere with controls hidden) still moves and applies on release, keeping the Move bar. This replaces 'each handle drag is its own undo step'; undo stays clean (one step per transform).
Decision, Distort: Edit > Transform > Distort enters corner distort without a drag (distortCommand: starts a Free Transform of the selection or layer if none, then beginDistort). Shipped here, not left to TASK-62.
Decision, align dimming: bar align buttons need two selected layers or a selection (align to selection); distribute buttons need three (Lamina's distribute needs three). Aligning one layer to the canvas stays in the ••• menu. Bar distribute buttons are vertical and horizontal spacing.
Decision, reference point: also the pivot for rotation drags (TransformDrag.pivot), marked on the canvas by a ringed cross during a Free Transform. Not persisted across launches.
W/H % are relative to the layer's pixels (as Scale % was), like a smart object's cumulative scale; a group's 100% is its box at the start.
Interpolation chosen during a group transform now reaches each member (TransformGroup.carried); untouched, each keeps its own sampling.
Shortcuts: 'Transform Layer / Selection' renamed 'Free Transform' (Cmd-T); Show Transform Controls loses Cmd-H and becomes assignable 'View > Show Transform Controls'; Flip moved to assignable 'Edit > Transform > Flip Horizontal/Vertical'; new 'Edit > Transform > Distort'. renamedIDs carry saved custom keys. Hide Lamina stays unbound; Cmd-H is free for TASK-62's View > Extras.
README still says 'Flip Layer' (feature list): left to TASK-66, which rewrites README and website for m-5.
Screenshots (Dev build, 1500 x 860, dark): backlog/assets/task-56/move-bar.png, backlog/assets/task-56/free-transform-bar.png (after Edit > Free Transform pressed via Accessibility; menu checked: Free Transform has Cmd-T, Show Transform Controls no key).
Validation: swift build; swift test: 710 tests in 104 suites passed (plus 22 and 47 in the core and CLI targets). New FreeTransformTests (7) and KeyboardShortcutTests.movedTransformCommandsKeepTheirCustomKeys; existing TransformTests, TransformPressTests, DistortTests, CursorTests, MaskTransformTests pass unchanged. make test-ui not run (orchestrator).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The Move bar now holds Auto-Select, Show Transform Controls, align and distribute icon buttons (dimmed below two layers, or three for distribute) and a ••• Align & Distribute menu. While a Free Transform is pending (Edit > Free Transform Cmd-T, Edit > Transform > Distort, or a press on a handle) the Free Transform bar replaces it: reference point, X/Y, W/H % with link, angle, Interpolation (Nearest Neighbor/Bilinear/Bicubic over the unchanged saved sampling), Cancel and Commit. Handle drags now wait for Commit as one undo step; body moves still apply on release. Flip moved to Edit > Transform (flips the pending box across the reference point), Cmd-H no longer toggles transform controls, saved custom keys carry over. Verified with swift test (710 app tests pass, new FreeTransformTests and a shortcut carry-over test) and screenshots of both bars in the Dev build. DESIGN.md updated.
<!-- SECTION:FINAL_SUMMARY:END -->
