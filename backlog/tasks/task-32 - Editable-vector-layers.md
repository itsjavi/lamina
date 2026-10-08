---
id: TASK-32
title: Editable vector layers
status: To Do
assignee: []
created_date: '2026-10-08 15:09'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-31
references:
  - >-
    backlog/decisions/decision-5 -
    Vector-layers-are-Illustrator-style-object-trees-saved-as-SVG-in-the-Lamina-project.md
  - >-
    backlog/docs/research/doc-2 -
    Vector-graphics-and-the-Paint-Bucket-research.md
priority: medium
type: feature
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The core of m-2: layers that hold editable vector objects instead of pixels, as decision-5 sets out (Illustrator-style object trees, SVG as the source of truth, transforms applied to the points). Today the Shape tool rasterizes fixed kinds with a small `shape` record and nothing stays editable once transformed beyond a resize. The Pen tool (TASK-28), gradients and path operations build on this.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A vector layer holds groups, paths and compound paths, each with a solid fill, a stroke (width, cap, join) and an opacity, and draws sharp at every size and rotation
- [ ] #2 The Shape tool makes vector objects (rectangle with a live corner radius, ellipse, line, polygon, star), and Shape-tool layers in existing projects open as vector layers
- [ ] #3 The Layers panel lists a vector layer's objects; they can be selected, renamed, hidden, reordered and grouped, and selected objects move, scale, rotate and flip on the canvas with the change applied to their points
- [ ] #4 Image Size, Canvas Size, Crop and canvas rotation and flips keep vector layers editable
- [ ] #5 Painting, filters and other pixel edits ask to rasterize a vector layer first, and Layer › Rasterize does it explicitly, each as one undo step
- [ ] #6 Vector layers save as the SVG subset decision-5 describes, documented in docs/project-format.md and in the guide for writing projects, so an agent can write one by hand
- [ ] #7 Tests cover the SVG round trip, NSImage drawing of the saved SVG matching Lamina's own drawing, geometry checks (circle area, rotated rectangle), and rejection of SVG outside the subset
<!-- AC:END -->
