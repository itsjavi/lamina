---
id: TASK-36
title: Vector commands for the command-line tool and MCP server
status: To Do
assignee: []
created_date: '2026-10-08 15:10'
updated_date: '2026-10-08 23:25'
labels:
  - vector
milestone: m-2
dependencies:
  - TASK-5
  - TASK-32
references:
  - >-
    backlog/decisions/decision-4 -
    Drive-the-running-app-over-Apple-Events-not-a-socket-or-a-local-HTTP-port.md
  - >-
    backlog/docs/research/doc-2 -
    Vector-graphics-and-the-Paint-Bucket-research.md
  - >-
    backlog/decisions/decision-8 -
    Agents-make-bulk-edits-through-JSON-batches-of-catalog-commands-one-undo-step-per-named-pass.md
  - >-
    https://github.com/storytold/vectorcraft/blob/99a5318/crates/mcp/src/tools.rs
  - 'https://github.com/storytold/vectorcraft/blob/99a5318/docs/mcp.md'
priority: low
type: feature
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents already drive the running app through `lamina` and its MCP server (TASK-4, TASK-5, decision-4). With vector layers they should draw and edit vector objects through commands, not only by writing SVG into a closed project. VectorCraft's MCP tools (doc-2) are a reference for the command shapes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Commands list a vector layer's objects and read one object's paths and paint
- [ ] #2 Commands draw a path (anchors with optional handles, or SVG path data), set fills, strokes and gradients, transform objects and run path operations, each as one undo step
- [ ] #3 Placing an SVG file is available as a command
- [ ] #4 The commands are documented with the others and covered by tests
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ship these as ordinary catalog commands so they work in batches and with `coalesce` (decision-8, TASK-42).
<!-- SECTION:NOTES:END -->
