---
id: TASK-34
title: 'Path operations, stroke options and Release to Layers'
status: To Do
assignee: []
created_date: '2026-10-08 15:10'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-32
references:
  - >-
    backlog/decisions/decision-5 -
    Vector-layers-are-Illustrator-style-object-trees-saved-as-SVG-in-the-Lamina-project.md
  - >-
    backlog/docs/research/doc-2 -
    Vector-graphics-and-the-Paint-Bucket-research.md
priority: medium
type: feature
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With vector objects in place (TASK-32), the everyday Illustrator operations: combining shapes, converting between paths and selections, aligned and dashed strokes, and splitting a layer's objects into layers for the cases decision-5 leaves to Release to Layers (per-object masks and effects). doc-2 has the algorithms worth porting and VectorCraft's failure mode to avoid.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Union, Subtract, Intersect and Exclude combine the selected objects as one undo step; an operation that fails leaves the objects unchanged and says why
- [ ] #2 Outline Stroke turns an object's stroke into a filled path
- [ ] #3 Selected objects can be turned into a selection (anti-aliased or not), and a selection into a vector path traced within a set tolerance
- [ ] #4 Strokes on closed paths align inside, centered or outside, and strokes can be dashed
- [ ] #5 Release to Layers moves each object of a vector layer to its own vector layer, keeping their order and appearance
- [ ] #6 Tests cover the areas boolean operations produce, Outline Stroke, a selection to path to selection round trip above 0.98 overlap, and stroke alignment
<!-- AC:END -->
