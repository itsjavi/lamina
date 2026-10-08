---
id: doc-2
title: 'Vector graphics and the Paint Bucket: research'
type: other
created_date: '2026-10-08 15:07'
updated_date: '2026-10-08 15:07'
tags:
  - research
  - vector
---
# Vector graphics and the Paint Bucket: research

Prior art for milestone m-2 (vector graphics) and the Paint Bucket task. Sources, read 2026-10-08:

- [storytold/photocraft](https://github.com/storytold/photocraft) at `e5e3e39`: a clean-room Photoshop in Rust.
- [storytold/vectorcraft](https://github.com/storytold/vectorcraft) at `99a5318`: a clean-room Illustrator in Rust.

Both are MIT OR Apache-2.0, so algorithms may be ported to Swift or C with their notice in Credits.html
(`scripts/acknowledgements.swift` only covers SwiftPM packages, so a ported file needs a manual entry). The Rust code
itself can't be linked: Lamina takes no dependency the system frameworks can cover. Paths below are relative to each
repository's root.

## Paint Bucket (PhotoCraft)

- One region finder serves the bucket, the Magic Wand and the magic eraser (`crates/algo/src/paint.rs` `bucket_fill`,
  `crates/algo/src/selection.rs` `wand_region`). Lamina already has this in `wand_mask` (`WandPixels.c`).
- Contiguous: scanline span fill (4-connected), a visited byte map, a tracked bounding box. Global: parallel row scan.
  Tolerance is the largest per-channel difference from the seed (0–255, default 32).
- Anti-aliasing is a post-pass on the hard mask: each edge pixel takes its 3×3 average (0.5 + 0.5·avg inside,
  0.5·avg outside), a 1 px fringe either side; the bounding box grows by 1.
- Compositing is coverage × opacity × selection, tile-parallel over the region's bounding box only. The flood ignores
  the selection; the selection only masks the output.
- Avoid: comparing straight RGBA, which makes fully transparent pixels with different hidden RGB "different" (compare
  premultiplied, or treat alpha 0 as equal); ignoring lock transparency and blend mode; rendering a pattern over the
  whole canvas before sampling it (memory grows with canvas size); no "sample all layers" for the bucket.

## Vector model (VectorCraft)

- `crates/geom/src/path.rs`: an `Anchor` holds `p`, `h_in`, `h_out` as absolute points plus `kind` (corner or smooth);
  a handle equal to `p` means none. Every segment is a cubic, a line when both facing handles are retracted.
  `SubPath { anchors, closed }`, `PathData { subpaths }`. Moving a smooth anchor's handle keeps the opposite handle
  collinear at its own length unless the move is independent.
- `crates/doc/src/node.rs`: an object tree (layer, group with optional clip, path, compound path, image, text). Hit
  testing skips layers and finds the topmost object (`crates/doc/src/hit.rs`).
- Paths and groups have no transform of their own: transforms are applied to the points. For Lamina this means a
  vector layer bakes a committed move, scale or rotation into its points and keeps an unrotated layer box, so it
  renders crisp instead of being resampled.
- `crates/doc/src/appearance.rs`: an appearance is an ordered list of fills and strokes, each with its own opacity,
  blend mode and visibility. Lamina starts with one fill and one stroke per object.

## Storing vectors as SVG

- Export (`crates/svg/src/export.rs`): gradients in `<defs>` as `userSpaceOnUse`, identical ones shared.
- Import (`crates/svg/src/import.rs`): a prepass (CSS, hidden objects, images), then usvg normalization with transforms
  baked into geometry. `<use>`/`<symbol>`, `clipPath`, `<mask>` and patterns survive; of the filters only blur, drop
  shadow, glow and feather; others are dropped with a warning. Anchor kind is inferred (collinear handles → smooth),
  and a closing `Z` whose last point repeats the first merges into the first anchor.
- SVG can't say whether an anchor is a corner or smooth, so a deliberate corner with collinear handles comes back
  smooth. Lamina writes such facts as `data-lamina-*` attributes on otherwise portable SVG.
- VectorCraft's lossless round trip embeds its whole native document as base64 in `<metadata>` with a hash of the rest
  of the markup. Avoid: the SVG must stay the readable source of truth.
- Place (`crates/engine/src/cmd/place/mod.rs`): one undo step, never touches the clipboard. SVG is embedded as an
  editable group; rasters are linked by default.

## Placing an SVG without parsing it (macOS probe)

On macOS 27, `NSImage(contentsOf:)` loads SVG (representation class `_NSSVGImageRep`, the system's SVG renderer;
ImageIO returns nil). Drawn into a bitmap at 10× its size it stays sharp, and it rendered correctly: linear and radial
gradients, CSS class styles, `transform`, arcs, `clipPath`, `<mask>`, `feGaussianBlur`, `<symbol>`/`<use>` and
`<text>`. The renderer is private and undocumented, so features Lamina relies on need tests; external `href`s don't load
in the sandbox. PhotoCraft's smart objects resample their cached raster when scaled, which blurs an enlarged SVG:
redraw from the source at the new size instead.

## Rendering and caching

- PhotoCraft re-renders a shape layer's raster on every edit and composites it as ordinary pixels; zoom never
  re-rasterizes, and paths, handles and drag previews are screen overlays (`crates/ui-egui/src/vector_ui.rs`).
- Its saved shape cache is trusted without a check. Its fill-layer cache stores the parameters it was rendered from and
  is used only while they match. Lamina's PNG beside the SVG does the same with a digest of the SVG.
- Layer effects on a shape follow its vector outline, not its pixels (`effect_outline`, `crates/compose/src/lib.rs`).
- Strokes: inside alignment is a centered stroke at twice the width clipped to the fill; outside is twice the width
  with the interior punched out; open paths fall back to center (`crates/render/src/lib.rs` `draw_stroke`). One stroke
  module turns strokes into filled outlines for drawing, export and Outline Stroke (`crates/effects/src/stroke.rs`).

## Tools (VectorCraft)

Tools never change the document directly: they emit begin (snapshot), preview (reapplied on the snapshot) and commit
(one undo step) (`crates/tools/src/lib.rs`). Hit tolerances are screen pixels divided by zoom: selection 3, snapping 4,
anchors 5, handles 4.

Pen (`crates/tools/src/pen.rs`):

- Click places a corner; drag places a smooth anchor with mirrored handles; Shift snaps to 45°; Space moves the anchor
  being placed.
- Option during a drag freezes the incoming handle so only the outgoing one follows.
- Clicking the first anchor closes the path (drag there to shape the closing curve, Option to break it).
- Clicking the last anchor retracts its outgoing handle, so the next segment leaves a corner.
- Clicking an end of a selected open path continues it (reversing it from the first anchor).
- Return or Escape ends the path; Option over an anchor or handle converts it; auto add/delete on selected paths,
  Shift disables it. The cursor shows each state (close, convert, continue, add, delete).

Direct Selection (`crates/tools/src/direct.rs`): pressing an unselected path's stroke selects that segment's two
anchors, pressing its fill (or Option) selects the whole path; dragging a curved segment reshapes it; Option drags one
handle alone.

## Gradients

- Stops carry color, opacity, offset and a midpoint (VectorCraft `crates/color/src/gradient.rs`, midpoint 0.13–0.87;
  PhotoCraft remaps midpoints piecewise-linearly, clamped to 0.05–0.95, `crates/compose/src/gradient_fill.rs`).
  Core Graphics gradients have no midpoints, so a midpoint becomes an extra stop; VectorCraft exports it the same way.
- Gradient geometry is start, end, radial aspect and focal point in document space; with no geometry the gradient fits
  the object's bounds. `transform()` maps it through any affine exactly.
- PhotoCraft has three gradient samplers that disagree (the tool ignores midpoints). Use one: the Metal canvas and the
  Core Graphics raster must draw the same gradient.
- PhotoCraft dithers gradients by one 8-bit level of monochrome noise to hide banding.
- On-canvas editor (VectorCraft `crates/tools/src/xform/gradient.rs`): a bar with start and end handles, stops under it,
  midpoints above; click the bar to add a stop, Option-drag to duplicate, drag 24 px off to delete (never below two),
  double-click to edit; the selected stop is shared with the panel.

## Path operations

- VectorCraft's booleans (`crates/pathops/src/boolean.rs`) sweep cubics directly, rebuild pieces from their source
  curves, refit smooth joints, keep the inputs' anchors and drop slivers. Core Graphics has union, subtract, intersect
  and exclude on `CGPath`; try those first.
- Avoid: VectorCraft returns an empty path when an operation fails, which silently deletes art. Keep the original and
  report the failure.
- Deleting an anchor refits the merged curve (`crates/pathops/src/edit.rs` `remove_anchor`): worth porting.
- Selection to path (PhotoCraft `crates/vector/src/trace.rs`): marching squares at the 0.5 level, corners where the
  direction turns more than 60°, Schneider least-squares cubic fit (2 px tolerance), nested contours as excluded
  subpaths. Worth porting. Path to selection: fill coverage, thresholded at 0.5 without anti-aliasing.

## Tests worth copying

- PhotoCraft `crates/vector/src/tests.rs`: a circle's area against πr², a rotated rectangle keeps its area, a partial
  render equals a crop of the full render, even-odd against nonzero, boolean areas, caps, joins and dashes, and
  selection → path → selection with an overlap ratio above 0.98 and a cap on anchors.
- A fast flood fill checked against a simple reference (`selection.rs` `wand_region_matches_reference_magic_wand`).
- A gradient made by a drag matches the same gradient drawn by the tool.
- For Lamina: render the SVG it writes with `NSImage` and compare against its own Core Graphics render, which checks
  that the saved SVG is portable.

## Agent access (VectorCraft)

An MCP server (`docs/mcp.md`, `crates/mcp/src/tools.rs`) with a generic `list_commands` / `run_command` over the same
commands the tools emit, plus conveniences: `draw_path` (points with optional handles, or an SVG `d`), `set_paint`,
`pathfinder`, `transform`, `inspect_document`, `screenshot`.
