---
id: TASK-33
title: Gradients with stops for vectors and the Gradient tool
status: To Do
assignee: []
created_date: '2026-10-08 15:10'
updated_date: '2026-10-08 23:25'
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
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/color/src/gradient.rs
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/tools/src/xform/gradient.rs
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/compose/src/gradient_fill.rs
priority: medium
type: feature
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Vector fills and strokes need real gradients, and the pixel Gradient tool only offers foreground to background or to transparent. One gradient model and one way of drawing it should serve both: PhotoCraft has three gradient samplers that disagree (doc-2), and Lamina already draws the pending gradient twice, on the Metal canvas and in the committed pixels.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A gradient has two or more stops (color, opacity, location and a midpoint between stops), is linear or radial and can be reversed; vector objects and the Gradient tool use the same gradients
- [ ] #2 Vector fills and strokes take gradients, edited on the canvas: start and end handles, stops along the bar (click adds one, dragging one off removes it, never below two), midpoints, and the selected stop editable in the panel
- [ ] #3 Gradients move, scale and rotate with their objects
- [ ] #4 The Gradient tool edits stops the same way, keeps today's two styles as presets, and the canvas preview matches the committed pixels
- [ ] #5 Gradients save in the vector layer's SVG as linear and radial gradients, midpoints in data-lamina attributes, and tests cover sampling, midpoints, transforms and the round trip
<!-- AC:END -->
