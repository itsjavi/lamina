---
id: TASK-45
title: 'Tell agents the cheapest way to work, in the help and the MCP server'
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
labels:
  - agents
milestone: m-3
dependencies:
  - TASK-42
  - TASK-43
  - TASK-44
references:
  - Sources/LaminaCLI/MCPTools.swift
  - backlog/docs/research/doc-3 - Agent-painting-research.md
priority: medium
type: docs
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents learn Lamina from `lamina --help`, `lamina help <command>` and the MCP server's instructions and tool descriptions (`MCPTools.instructions` and the catalog). None of them says what's cheap, so an agent may send thousands of strokes inline, preview at full size every round, or make one call per edit, spending tokens and time that a batch file, a region preview or a color sample would save (doc-3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `lamina --help` and the MCP server's instructions start with a short guide to working efficiently: batch steps instead of separate calls; inline JSON for small edits and a generated file (`input_file` or stdin) for bulk; one coalesce name per pass; validate before a long batch; preview small, then inspect regions; sample colors instead of reading them off images; pass expect_revision
- [ ] #2 Commands where cost matters say so in their help and tool descriptions (for example `paint-strokes`: inline for tens of strokes, a generated file beyond that), written once in the catalog so `lamina` and the MCP server agree
- [ ] #3 docs/painting-with-agents.md, linked from AGENTS.md and docs/writing-lamina-projects.md, walks through a painting end to end: a layer per pass, a small generator that emits strokes, a coalesced batch, a region preview and a round of inline corrections
- [ ] #4 LaminaTests check that the guidance is in the help output and the MCP instructions
<!-- AC:END -->
