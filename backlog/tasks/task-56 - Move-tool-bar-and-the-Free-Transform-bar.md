---
id: TASK-56
title: Move tool bar and the Free Transform bar
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:38'
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
- [ ] #1 The Move bar shows Auto-Select, Show Transform Controls, the align and distribute buttons (dimmed until two or more layers are selected) and a menu with the rest of Align and Distribute
- [ ] #2 Transforming a layer or a selection (Edit ▸ Free Transform, ⌘T, or dragging a handle) shows the Free Transform bar: reference point, X and Y, W and H in percent with a link, angle, Interpolation, and Cancel and Commit at the right end
- [ ] #3 Interpolation offers Nearest Neighbor, Bilinear and Bicubic, mapped from today's Nearest, Smooth and High quality without changing saved projects
- [ ] #4 Flip Horizontal and Flip Vertical move to Edit ▸ Transform, and ⌘H no longer toggles transform controls
- [ ] #5 Each transform is still one undo step and the existing transform tests pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
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
