---
id: decision-6
title: >-
  Place SVG files as layers the system's SVG renderer draws; editable import
  comes later
date: '2026-10-08 15:07'
status: accepted
---
## Context

Logos and icons usually arrive as SVG files made in other apps. Turning any SVG into editable paths means handling
CSS, `<use>`, transforms, arcs, clip paths, masks, filters and text: VectorCraft needs usvg plus its own prepass for
that and still drops most filters (doc-2). macOS has no public API that parses SVG into paths and ImageIO can't read
SVG, but `NSImage` loads and draws it: on macOS 27 it drew gradients, CSS styles, transforms, arcs, clip paths, masks,
blur, `<use>` and text correctly and sharply at 10× size (doc-2).

## Decision

- File › Place, drag and drop and paste of an `.svg` add a **placed SVG layer**. The file's bytes are kept unchanged
  in the project (`images/<layer UUID>.svg`, marked as placed in the manifest) and drawn by `NSImage`.
- It's embedded, not linked: projects stay self-contained, as they already do with imported photos.
- Scaling redraws it from the SVG at the new size, never by resampling old pixels, and rotation draws through the
  transform, so it stays sharp. It moves, flips, masks, clips, blends and takes effects like any layer.
- Its paths can't be edited. Convert to Editable Vectors comes later: it turns what decision-5's subset can hold into
  vector objects and reports what it had to leave out.

Rejected:

- **Rasterize once on import**, as a PNG: blurs as soon as it's scaled up.
- **Lamina's own full SVG renderer now**: the importer's size without its payoff; the editable import comes later.
- **resvg or another library**: a Rust or C dependency for something the system already draws.
- **WebKit snapshots**: asynchronous, a web process per render, and slow for live scaling.

## Consequences

- Lamina relies on an undocumented renderer behind a public API. Tests cover the SVG features it depends on; if a
  macOS release regresses one, the saved PNG keeps the project displaying as it was.
- External references (`href` to files or URLs) don't load inside the sandbox.
- An SVG is untrusted input: placed files are size-limited like other assets and drawn by the system renderer only.

