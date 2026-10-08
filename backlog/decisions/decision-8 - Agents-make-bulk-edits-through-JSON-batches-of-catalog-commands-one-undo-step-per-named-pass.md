---
id: decision-8
title: >-
  Agents make bulk edits through JSON batches of catalog commands, one undo step
  per named pass
date: '2026-10-08 23:19'
status: accepted
---
## Context

Agents drive the running app through `lamina` and its MCP server (decision-4): one Apple Event per call, one undo
step per edit. That suits a handful of edits, not an agent painting a picture, which makes tens of thousands of strokes
in a few passes (the oil-painting experiment in doc-3: about 54,000). What an agent spends is what the model types, so
the route matters more than the transport (doc-3):

- Every stroke typed by the model as inline JSON: about 3–5M output tokens for a painting.
- Computer use, dragging each stroke: 100M+ tokens; a few hundred strokes at most.
- A generator script the model writes once: about 10–15k tokens, whatever the stroke count.
- Writing PNG layers into a project file (docs/writing-lamina-projects.md): as cheap, but it bypasses the brushes,
  the history and the live canvas.

PhotoCraft batches commands (up to 256 steps per call) and groups edits into one undo step with a `coalesce` key, but
its bulk input still passes through the model, and a failed batch keeps what it applied. VectorCraft has neither.

## Decision

Agents make bulk edits through JSON batches of the catalog's own commands, and a named pass is one undo step.

- **One protocol, two producers.** A batch is a list of steps (a command name and its parameters as JSON), the same
  shape whether the model writes it inline (small edits: layer setup, filters, tens of correction strokes) or a script
  the model wrote generates it (bulk: thousands of strokes). Bulk batches come from a file or stdin (JSON Lines), read
  by `lamina` or by the MCP server from an `input_file` path, so they never pass through the model.
- **JSON, compact by shape.** Not YAML: it saves nothing for numeric arrays, and MCP arguments are JSON anyway. Tokens
  are saved by the payload's shape: positional points (`[x, y, pressure?]`), settings given once per call and
  overridden per stroke, hex colors, and results that return ids, counts and changed bounds instead of echoing input.
- **Undo per named pass.** Any edit or batch takes a `coalesce` name; consecutive edits with the same name are one undo
  step with that name in History, until another name, an unnamed edit or the person's own edit ends it.
- **All or nothing per request.** A failing step rolls the request back and names the step. A chunked pass that fails
  partway keeps its earlier chunks as its one undo step.
- **Watchable and stoppable.** The canvas redraws between chunks, and the person can stop a batch.
- **Strokes go through the app's brush engine**, not into layer PNGs, so painting has history, a live canvas and the
  same brushes people use.
- **Agents are told what's cheap.** `lamina --help`, command help and the MCP server's instructions say when to batch,
  when to use a file, and how to look cheaply (region previews, color samples).

Rejected for now: an app-side painting language that expands compact instructions into strokes (Corel Painter's
Auto-Painting). It would be cheaper still, but it limits agents to the styles it supports; scripts can do anything.

## Consequences

- Implementation is pending: milestone m-3, TASK-42 (batches and `coalesce`) and TASK-43 (`paint-strokes`), with
  TASK-41 (layer commands), TASK-44 (region previews and color samples) and TASK-45 (guidance in help and MCP).
- Every future command, the vector commands of TASK-36 included, works in batches with no extra code.
- Apple Event size limits mean `lamina` and the MCP server split large inputs into chunks; the app must keep a
  coalesced pass open across requests.
- Strokes must be deterministic (a seed per stroke, or one derived from its points), so chunking doesn't change pixels
  and tests can compare them.
