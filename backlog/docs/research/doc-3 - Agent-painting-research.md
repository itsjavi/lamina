---
id: doc-3
title: 'Agent painting: research'
type: other
created_date: '2026-10-08 23:19'
updated_date: '2026-10-08 23:19'
tags:
  - research
---
# Agent painting: research

Prior art and measurements for milestones m-3 (agent painting) and m-4 (impasto), and the reasoning behind decision-8.
Read 2026-10-09:

- An experiment in this repository: `scripts/oil-painting-project.swift`, which paints the website's oil-painting hero
  (`web/assets/oil-painting.webp`) as a `.lam` project.
- [storytold/photocraft](https://github.com/storytold/photocraft) at `e5e3e39` and
  [storytold/vectorcraft](https://github.com/storytold/vectorcraft) at `99a5318`, as in doc-2. Both are MIT OR
  Apache-2.0: algorithms may be ported to Swift or C with their notice in Credits.html (a ported file needs a manual
  entry; `scripts/acknowledgements.swift` only covers SwiftPM packages). Paths below are relative to each repository.

## The experiment

An agent was asked to make an oil painting with Lamina. Lamina has no paint command and no oil brush, so the agent wrote
a generator (about 500 lines of Swift) that paints PNG layers into a project, opened it in the Dev build and used
`lamina` for a filter and previews:

- A procedural reference scene (sky, clouds, sun, sea, headland, rocks), blurred once per pass.
- Four passes of strokes (radius 30, 15, 7 and 3 px; about 54,000 strokes), after Hertzmann's painterly rendering:
  strokes start on a jittered grid (finer passes only where the finer blur differs from the coarser one), follow the
  contours of the light (perpendicular to the luminance gradient, blended with a per-region flow: swirling sky, flat
  water, hatched land), and stop when the reference's color drifts too far from the stroke's.
- What made it read as oil: bristle strands across each stroke with slightly varied color, ragged strand ends, a few
  strokes off the local hue ("broken color", less in the darks), a toned ground showing through gaps, canvas weave in
  Overlay, and paint thickness lit as relief (a height map from the strokes, lit from the upper left, in Overlay) with
  a faint specular sheen.
- Pitfalls: relief at full strength on every stroke looks like an emboss filter; thickness has to follow the light (thick
  in the lights, thin in the darks), and small accent strokes need little relief. Round dabs at stroke ends read as
  bubbles.

It took about 10–15k output tokens to write and a few tuning rounds; the painting renders in about 15 s. Each layer
is ordinary pixels: nothing went through Lamina's brushes or history.

## What an agent painting costs

Cost is what the model has to type: anything code produces costs nothing. One stroke as JSON (10–20 points) is about
60–120 tokens.

| Route | Tokens for ~54k strokes | Notes |
| ----- | ----------------------- | ----- |
| Generator script writing layers or a strokes file | ~10–15k, whatever the stroke count | Today's route; with a paint command, the same script feeds the app |
| The model sends each stroke inline (MCP or CLI) | ~3–5M, hours of output | Fine for tens of correction strokes (a few thousand tokens) |
| Computer use, dragging each stroke | ~2–3k per screenshot and action; 100M+ | A few hundred strokes at most; takes over the Mac; settings changed through the UI |

So bulk payloads must reach the app without passing through the model: the model writes code that writes the payload
(a file or stdin), and `lamina` or the MCP server reads it. Inline JSON is for small edits. Neither PhotoCraft nor
VectorCraft offers this: their agents send every step through the model.

Format: JSON. YAML saves nothing here (flow-style YAML is JSON; block-style YAML spends a line and indentation per
point), MCP tool arguments are JSON anyway, and models write JSON reliably. What saves tokens is the payload's shape:
positional points (`[x, y]` or `[x, y, pressure]`, not `{"x":…,"y":…}`), whole or one-decimal coordinates, hex
colors, brush settings given once per batch and overridden per stroke, and results that report counts, ids and bounds
instead of echoing the input. Readable key names cost little: in a generated file they're free, and inline batches
are small.

## Lamina today

- The brush is a round tip: `BrushSettings` (`Sources/LaminaApp/Document/BrushStroke.swift`) has diameter, hardness,
  color, opacity, flow, smoothing, pressure for size and opacity, erase, healing, blur and dodge/burn. No bristles,
  texture, paint load or color pickup; Smudge and Liquify are separate (`SmudgeLiquify.swift`).
- A stroke is a `BrushStroke`: created for a layer and settings, fed points with `append(_:pressure:)`, `flush()`ed,
  then `commitPaintSnapshot` installs its tiles inside `beginEdit`/`endEdit`, one undo step named "Brush Stroke".
  Dabs are stamped with Core Graphics (a cached tip; GPU when available); C helpers are in `CPixels/BrushPixels.h`.
- `lamina` and the MCP server have no command to create layers or paint: `list-documents`, `describe-document`,
  `select-layer`, `apply-filter`, `add-adjustment-layer`, `export-document`, `render-preview`, `undo`, `redo`. Each
  call is one Apple Event (decision-4) and each edit one undo step. `select-layer` and other edits switch the canvas to
  the layer and its tool's handles, which matters for screenshots.
- The MCP server's guidance is `MCPTools.instructions` (`Sources/LaminaCLI/MCPTools.swift`), sent at `initialize`;
  tool descriptions come from the catalog.

## Brushes (PhotoCraft `crates/paint`, all CPU)

- Tips (`src/brush.rs`): computed round (hardness, roundness, angle) or sampled (a mipmapped gray tile). No simulated
  bristles: "Oil Bristle" (`src/presets.rs`) is a procedural sampled tip (`procedural.rs` `bristle_tip`, hashed
  streaks) turned by the stroke direction, with canvas texture and a little color jitter. Tips and patterns are
  generated from seeds; no brush files are bundled.
- Dynamics (`src/dynamics.rs`): spacing as a fraction of the diameter (or timed by speed when off). Photoshop's sections
  (shape, scattering, color, transfer, pose, dual brush, noise, build-up, smoothing), each a jitter plus a control
  (pressure, tilt, wheel, rotation, fade, initial or current direction) and a minimum. Generation is incremental and
  deterministic: the random source is a hash of the seed and the dab index, so any chunking of a stroke lays the same
  dabs.
- Texture: a pattern (procedural noise, canvas, paper, dots, or a tile) sampled in document space, so the grain stays
  on the canvas; per stroke or per tip, including Photoshop's Height modes where paint catches on the peaks
  (`render.rs` `mask_combine`).
- Mixer brush (`src/mixer.rs`): a reservoir (color and amount), a pickup well pulled toward the canvas color by `wet`,
  a `mix` blend, and depletion (`amount *= 1 − 0.08·(1 − load)`); the state persists between strokes. Smudge is in
  `retouch.rs`. Mixer and smudge sample the canvas per dab, sequentially: their slow path.
- Rasterizing (`render.rs`): a sparse 64² tile coverage map built up as `c += v·(ceil − c)`, composited from the
  pre-stroke pixels at the stroke's opacity; only dirty tiles redraw.
- Presets: `BrushSettings` as camelCase JSON, partial patches deep-merged; user presets in `.pcbrushes` JSON; ABR
  import, written clean-room (`crates/psd/src/abr.rs`, `crates/io/src/abr_map.rs`), warning about what it can't map.
- VectorCraft's vector bristle brush (`crates/brush/src/calli.rs` `bristle`): 3–16 translucent strands with wobble and
  ragged ends. Closer to the experiment's strands than PhotoCraft's stamped tip, and better along long strokes, where a
  stamped streak pattern repeats.

## Strokes as data

- PhotoCraft: `StrokePoint {x, y, pressure, tiltX, tiltY, rotation, wheel, time}`, `Stroke {brush, points}`
  (`crates/paint/src/lib.rs`). Commands take points as `[x, y, p?, tiltX?, tiltY?, rot?, timeMs?, wheel?]` or objects
  (`crates/engine/src/brush_cmds.rs` `parse_points`), coordinates capped at ±1e6. The seed is a parameter, or a hash of
  the points, so a stroke replays pixel for pixel.
- Each command is journaled as `(id, params)`; actions record and replay journal steps.

## Agent access

- PhotoCraft (`crates/automation`, `docs/control-protocol.md`): `command_run`, `command_batch` (up to 256 steps),
  `doc_render_preview` (up to 2048 px, PNG up to 5 MiB), `ui_screenshot`, `ui_pointer` (a simulated pen) and
  `control_call`. No multi-stroke command: a batch is many `paint.stroke` / `paint.mixerBrush` / `paint.smudge` steps
  (`{"points", "brush"?, "preset"?, "size", "opacity", "flow", "color", "mode", "seed", "layer", "target"}`). Limits:
  1 MiB request line, 8 MiB reply budget, 30 s socket timeout. In bridge mode a batch costs one round trip per step.
  Long jobs run with `wait: false` and report progress through `jobs.list`.
- VectorCraft (`crates/mcp/src/tools.rs`, `docs/mcp.md`): generic `list_commands`/`run_command` plus `draw_path`
  (points or SVG `d`), `path.freehand`, `screenshot`. `draw_path` is several undo steps (create, then fill, stroke and
  width). One request, one reply: no progress or cancel during a call.
- Avoid: PhotoCraft's batch stops when the reply budget runs out and keeps what it applied (no rollback); neither
  reports progress during a call; bulk input always passes through the model.

## History

- Both snapshot the whole document per step with copy-on-write tiles, so a step is cheap (PhotoCraft
  `crates/ops/src/lib.rs`: 50 states plus a byte budget; VectorCraft: 500 entries).
- PhotoCraft: any command takes `"coalesce": "<key>"`, and consecutive edits with the same key share one step
  (`Session::edit`, `crates/engine/src/lib.rs`). Without it, 50 states evict quickly under scripted edits.
- VectorCraft has `begin_undo_group`/`end_undo_group`, used only by scrubbed number fields and not exposed to agents.

## Watching an agent paint

- PhotoCraft draws a live stroke onto a copy of the document and uploads per-step damage rectangles; its control queue
  drains every frame; screenshots wait for animations and at least three frames.
- Pitfall: its damage reuse needs the revision to advance by exactly one; several commands in one frame force a full
  redraw. Batches should redraw once per chunk, not per stroke.

## Impasto

Neither app has paint thickness: PhotoCraft's only height maps are layer-style bevels. The experiment's approach (a
height map built from the strokes, lit as relief, thickness following the light, strand ridges and a ridge where the
brush lifts) is the starting point for m-4.
