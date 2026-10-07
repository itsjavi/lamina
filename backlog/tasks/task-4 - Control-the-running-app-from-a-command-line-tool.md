---
id: TASK-4
title: Control the running app from a command-line tool
status: To Do
assignee: []
created_date: '2026-10-07 18:01'
updated_date: '2026-10-07 18:31'
labels: []
dependencies: []
references:
  - docs/writing-comp-files.md
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents and scripts can already change a project by writing its `.comp` files, and the open app reloads them (docs/writing-comp-files.md). They can't drive the running app itself: ask what's open, select layers, apply adjustments or filters, export, or read results back.

A command-line tool comes first, not an MCP server. The agents that would use it run locally with a shell (Claude Code, Codex): a CLI is discoverable with --help, costs no context until it's used, composes with scripts and pipes, is usable by people too, and needs no server per client. MCP pays off for clients without a shell (Claude's desktop or web chat, other hosted assistants); TASK-5 adds it as a thin wrapper over these commands.

Both need the same two pieces in the app: a command layer that calls the same EditorSession methods the menus and panels call, and a local transport that returns results. The transport is an open decision because the app is sandboxed: Apple Events (macOS's native app automation; the sender gets a one-time Automation prompt), a Unix socket in an app group container (an app group entitlement, so Developer ID signing), or the URL scheme (one-way, no results). Record the choice as a decision. Define each command once (name, parameters, result shape) so TASK-5 can expose the same definitions as MCP tools.

Independent of TASK-2. Once TASK-2 lands, the same tool can also offer offline `.comp` commands (inspect, validate, create) through CompositorCore.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A command-line tool shipped with the app lists open projects and their layers, selects a layer, applies an adjustment or filter with parameters, and exports, against the running app
- [ ] #2 Each command runs through the same model methods the UI uses, is one undo step in the app, and reports its result or error as text or JSON
- [ ] #3 Only processes of the same user on this Mac can send commands; any entitlement added is documented with its reason
- [ ] #4 --help documents every command, the command layer has tests that don't need the transport, and AGENTS.md describes the tool
- [ ] #5 The transport choice is recorded as a decision
<!-- AC:END -->
