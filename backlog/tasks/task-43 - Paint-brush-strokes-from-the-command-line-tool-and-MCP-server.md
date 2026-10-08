---
id: TASK-43
title: Paint brush strokes from the command-line tool and MCP server
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
updated_date: '2026-10-08 23:24'
labels:
  - agents
  - painting
milestone: m-3
dependencies:
  - TASK-41
  - TASK-42
references:
  - Sources/LaminaApp/Document/BrushStroke.swift
  - scripts/oil-painting-project.swift
  - >-
    backlog/decisions/decision-8 -
    Agents-make-bulk-edits-through-JSON-batches-of-catalog-commands-one-undo-step-per-named-pass.md
  - backlog/docs/research/doc-3 - Agent-painting-research.md
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/engine/src/brush_cmds.rs
priority: high
type: feature
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The only way an agent can paint today is writing PNG layers into a project file, as `scripts/oil-painting-project.swift` does for the website's oil-painting hero: nothing goes through the brush engine, the history or the live canvas. A paint command lays strokes through the Brush tool's own engine (`BrushStroke`), so the person can watch an agent paint and undo its passes. Cost and payload shape: doc-3 and decision-8 (positional points, settings given once, generated files for bulk).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `paint-strokes` paints a list of strokes on a pixel layer or its mask through the Brush tool's engine; points are positional arrays (`[x, y]` or `[x, y, pressure]`) in document pixels
- [ ] #2 Brush settings (color, size, hardness, opacity, flow, preset, erase) are given once per call and can be overridden per stroke
- [ ] #3 Painting is deterministic: the same input paints the same pixels, chunked or not (a seed per stroke, or one derived from its points)
- [ ] #4 Strokes respect the selection as the Brush tool does, and the result includes the bounds they changed
- [ ] #5 As a batch step with a `coalesce` name, a pass of thousands of strokes is one undo step
- [ ] #6 The oil-painting generator, changed to emit strokes into layers it creates, paints its ~54,000 strokes through `lamina batch`; the time is recorded in the docs' performance notes and the app stays responsive while it runs
- [ ] #7 AutomationTests compare painted pixels with the Brush tool's result for the same strokes
<!-- AC:END -->
