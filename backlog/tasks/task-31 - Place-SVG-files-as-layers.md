---
id: TASK-31
title: Place SVG files as layers
status: To Do
assignee: []
created_date: '2026-10-08 15:09'
updated_date: '2026-10-08 23:25'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-7
  - TASK-2
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
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/engine/src/cmd/place/mod.rs
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/render/src/lib.rs
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/compose/src/lib.rs
priority: medium
type: feature
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Logos and icons usually arrive as SVG files, and today Lamina can only take them as pixels, if at all (ImageIO can't read SVG). decision-6 places them as layers the system's SVG renderer draws, so they stay sharp at any size without Lamina parsing SVG. This is also the first time a project stores an SVG file, so it carries the format version bump decision-5 asks for, on the Lamina format line from TASK-7.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 File › Place, drag and drop and paste of an .svg file add a placed SVG layer above the active one, as one undo step
- [ ] #2 Scaling redraws it from the SVG at the new size, and rotated or flipped it still draws sharp: never a resampled blur
- [ ] #3 Masks, clipping, blend modes, opacity and layer effects work on it as on any layer; painting or filtering it asks to rasterize it first
- [ ] #4 Projects keep the SVG bytes unchanged with a PNG render and the digest it was drawn from; a missing or stale PNG is redrawn on open
- [ ] #5 The project format version is bumped and documented in docs/project-format.md; builds before it refuse such projects instead of dropping data
- [ ] #6 Tests cover save and reopen, stale-PNG redraw, rejection of unsafe or oversized SVG files, and correct drawing of the SVG features doc-2 lists
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The format code lives in LaminaCore after TASK-2: the SVG file handling and the format version bump go there.
<!-- SECTION:NOTES:END -->
