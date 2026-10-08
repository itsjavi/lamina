---
id: TASK-41
title: Layer commands for the command-line tool and MCP server
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
labels:
  - agents
milestone: m-3
dependencies: []
references:
  - Sources/LaminaAutomation/CommandCatalog.swift
  - backlog/docs/research/doc-3 - Agent-painting-research.md
priority: medium
type: feature
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents can't make or arrange layers through `lamina` or the MCP server: the catalog only adds adjustment layers (`add-adjustment-layer`). Painting in passes, and most compositing an agent would do, needs layers it creates, names, stacks and blends. Today the only way is writing a project file (docs/writing-lamina-projects.md), which bypasses the history and the live canvas. Research: doc-3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Commands add an empty pixel layer (full canvas unless a size is given) and a folder, at a given place in the stack or inside a given folder, and return the new layer's id
- [ ] #2 Commands set a layer's name, visibility, opacity, blend mode and place in the stack (above or below another layer, or into a folder)
- [ ] #3 Commands duplicate and delete a layer
- [ ] #4 Each is one undo step, accepts expect_revision and is refused while the person is mid-edit, like the existing edits
- [ ] #5 Each command has its handler in AutomationDispatcher and a test in AutomationTests, and its result matches the catalog's schema
<!-- AC:END -->
