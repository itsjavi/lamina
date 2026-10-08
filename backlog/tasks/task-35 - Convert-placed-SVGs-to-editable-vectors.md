---
id: TASK-35
title: Convert placed SVGs to editable vectors
status: To Do
assignee: []
created_date: '2026-10-08 15:10'
updated_date: '2026-10-08 23:25'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-31
  - TASK-32
  - TASK-33
references:
  - >-
    backlog/decisions/decision-6 -
    Place-SVG-files-as-layers-the-systems-SVG-renderer-draws-editable-import-comes-later.md
  - >-
    backlog/decisions/decision-5 -
    Vector-layers-are-Illustrator-style-object-trees-saved-as-SVG-in-the-Lamina-project.md
  - >-
    backlog/docs/research/doc-2 -
    Vector-graphics-and-the-Paint-Bucket-research.md
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/svg/src/import.rs
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/svg/src/export.rs
priority: low
type: feature
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Placed SVG layers (TASK-31) draw sharply but their paths can't be edited. decision-6 leaves the editable import for later: turning arbitrary SVG into the subset decision-5 defines means resolving CSS, `<use>`, transforms, arcs and paint, as VectorCraft does with usvg and its own prepass (doc-2).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Layer › Convert to Editable Vectors turns a placed SVG layer into a vector layer as one undo step
- [ ] #2 Paths, basic shapes, arcs, transforms, groups, <use>, CSS styles, solid colors and gradients convert
- [ ] #3 Before converting, it lists what the subset can't hold (such as filters, masks, text or images) and the person can cancel
- [ ] #4 Tests convert a set of sample logo SVGs and compare the result with NSImage's drawing of the original within a tolerance
<!-- AC:END -->
