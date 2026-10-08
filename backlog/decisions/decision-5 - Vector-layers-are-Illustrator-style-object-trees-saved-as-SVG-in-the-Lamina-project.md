---
id: decision-5
title: >-
  Vector layers are Illustrator-style object trees saved as SVG in the Lamina
  project
date: '2026-10-08 15:07'
status: accepted
---
## Context

Lamina is meant for people who need both pixel/photo work and vector work in one simple app, without being held back
where a vector tool would let them do more. Today the Shape tool draws fixed kinds (rectangle, ellipse, line) into an
ordinary raster with a small `shape` record, and there are no editable paths (TASK-28). Milestone m-2 adds vector
graphics, and three choices shape everything after it: what a vector layer holds, how it's saved, and what happens to
older builds. Prior art: doc-2 (PhotoCraft's Photoshop-style shape layers, VectorCraft's Illustrator-style object tree).

## Decision

- **Illustrator's model.** A vector layer holds a tree of objects: groups, paths and compound paths, each with its own
  fill, stroke and opacity. The Layers panel lists a vector layer's objects under it. Not Photoshop's shape layer of
  one path with one fill and one stroke.
- **Paths** are subpaths of anchors, each anchor a point with absolute incoming and outgoing handles and a corner or
  smooth kind; every segment is a cubic.
- **SVG is the source of truth.** Each vector layer is saved as `images/<layer UUID>.svg`: portable SVG that any
  viewer draws as Lamina does. What SVG can't express (an anchor's kind, gradient midpoints, stroke alignment) is kept
  in `data-lamina-*` attributes. Lamina writes and reads back a subset documented in the project format; a vector
  layer whose SVG falls outside it is rejected on open with the layer named, as other invalid project data is. No
  embedded copy of another format inside the SVG.
- **Document coordinates.** Points are document pixels and the SVG's `viewBox` is the canvas, so a person or an agent
  can write one without transform math. The layer's box is derived from its contents.
- **Transforms are applied to the points.** A committed move, scale, rotation or flip changes the points (and the
  gradients with them), so vector layers always draw sharp instead of being resampled.
- **A PNG render stays beside the SVG** as a cache for opening, thumbnails and export, with the digest of the SVG it
  was drawn from in the manifest. A missing or stale PNG is redrawn from the SVG, so editing only the SVG is enough.
- **A format version bump** on the Lamina format line (TASK-7). Builds that don't know it refuse to open the project
  instead of opening it, showing the PNG and dropping the vectors when they save.
- Layers the Shape tool made (`shape` records) become vector layers when opened.

Rejected:

- **One path per layer (Photoshop)**: a simpler Layers panel, but it restricts what people can draw. Release to
  Layers covers the cases that need per-object masks or effects.
- **Vector data as JSON in the manifest**, like `shape` and `text`: simpler to validate, but no other app or tool can
  read it, and it counts against the 4 MiB manifest limit.
- **An additive field older builds ignore**: they would open the project and silently drop its vectors on save.
- **A transform per object**: more state, and scaled or rotated objects would be resampled instead of redrawn.

## Consequences

- Lamina needs its own SVG writer and a reader for its subset: no public macOS API turns SVG into editable paths.
  `docs/project-format.md` specifies the subset, and the guide for writing projects teaches agents to write it.
- Tests can render the SVG Lamina saves with `NSImage` and compare it with Lamina's own drawing, which proves the saved
  file is portable.
- The Layers panel shows, selects and reorders objects inside a vector layer.
- Per-object masks, effects and multiple fills or strokes per object wait for later work; until then Release to Layers
  splits objects into their own layers.
- Projects saved by a build with vector support no longer open in builds before it.

