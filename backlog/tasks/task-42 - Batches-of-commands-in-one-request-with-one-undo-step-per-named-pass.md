---
id: TASK-42
title: 'Batches of commands in one request, with one undo step per named pass'
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
updated_date: '2026-10-08 23:24'
labels:
  - agents
milestone: m-3
dependencies: []
references:
  - >-
    backlog/decisions/decision-8 -
    Agents-make-bulk-edits-through-JSON-batches-of-catalog-commands-one-undo-step-per-named-pass.md
  - backlog/docs/research/doc-3 - Agent-painting-research.md
  - >-
    https://github.com/storytold/photocraft/blob/e5e3e39/crates/engine/src/lib.rs
  - 'https://github.com/storytold/photocraft/tree/e5e3e39/crates/automation'
priority: high
type: feature
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Each `lamina` call is one Apple Event and each edit one undo step. An agent painting a picture makes thousands of edits in a few passes: one call each is slow, and the history fills with steps nobody can use. decision-8 settles the shape: JSON batches of catalog commands, read from a file or stdin for bulk so the payload never passes through the model, and a `coalesce` name that makes a pass one undo step (PhotoCraft's approach, doc-3). The same batches serve every command, the vector commands of TASK-36 included.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `batch` command runs a list of catalog commands in order in one request, each step its command name and parameters as JSON, and returns a compact result per step (ids, counts and changed bounds, not an echo of the input)
- [ ] #2 A request is all or nothing: if a step fails, the document returns to its state before the request, and the error names the step's index and the offending parameter
- [ ] #3 Every edit command and every batch accepts a `coalesce` name: consecutive edits with the same name form one undo step with that name in History (for example "Block-in"), until another name, an edit without one, or the person's own edit ends it
- [ ] #4 `lamina batch` takes steps inline, from a file or from stdin as JSON Lines, sends large inputs in chunks that fit an Apple Event and reports progress on stderr; the MCP tool takes inline steps or an `input_file` path the MCP server reads, so bulk payloads never pass through the model
- [ ] #5 A validate option checks a batch against the catalog's schemas without touching the document, in `lamina` and the MCP tool
- [ ] #6 The canvas redraws between chunks, not per step, so the person can watch; the person can stop a running batch, and what it applied so far stays as one undo step with nothing half-applied
- [ ] #7 Busy refusals and expect_revision work in batches as they do for single commands
- [ ] #8 AutomationTests and MCPServerTests cover steps, coalescing, rollback, chunking, validation and stopping
<!-- AC:END -->
