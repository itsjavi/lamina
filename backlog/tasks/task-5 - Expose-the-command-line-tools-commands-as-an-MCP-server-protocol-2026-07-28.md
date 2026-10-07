---
id: TASK-5
title: Expose the command-line tool's commands as an MCP server (protocol 2026-07-28)
status: To Do
assignee: []
created_date: '2026-10-07 18:31'
labels: []
dependencies:
  - TASK-4
references:
  - 'https://modelcontextprotocol.io/specification/2026-07-28'
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-4 gives local agents with a shell a command-line tool to drive the running app. Clients without a shell (Claude's desktop or web chat, other hosted assistants) need MCP instead. This adds an MCP server that is a thin wrapper over the same commands: no second implementation of what a command does, and no drift between the CLI and the tools.

Target the newest MCP specification, 2026-07-28 (https://modelcontextprotocol.io/specification/2026-07-28). It is stateless: no initialize handshake; every request carries its protocol version and client capabilities in `_meta`, and servers identify themselves in each result's `_meta`; servers must implement `server/discover`; every result carries `resultType`; list results carry `ttlMs` and `cacheScope`; logging goes to stderr; Tasks is an opt-in extension. Many hosts may still speak 2025-11-25 (with `initialize`) when this is built, so check which versions the hosts in use support and answer those too.

Shape: a local stdio server shipped with the app (for example a `mcp` subcommand of the TASK-4 tool), with one tool per command, generated from the same command definitions. Prefer the official Swift MCP SDK if it supports 2026-07-28 at that point; otherwise implement the small stdio JSON-RPC surface directly against the spec's schema. No HTTP transport: it stays local, so no authorization layer.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A stdio MCP server shipped with the app exposes every TASK-4 command as a tool, generated from the same command definitions, so adding a command adds its tool
- [ ] #2 It implements MCP 2026-07-28: server/discover, per-request protocol version and capabilities, resultType on every result, ttlMs and cacheScope on tools/list, logging only to stderr
- [ ] #3 Hosts still on an earlier protocol version that are in use (checked when this is built) can connect, or the unsupported ones are documented
- [ ] #4 Tools have JSON Schema input and output schemas, return structuredContent, report command failures as tool errors, and are listed in a deterministic order
- [ ] #5 Tool annotations mark read-only commands (listing, inspecting) and commands that write files (export)
- [ ] #6 Commands that take long (exports, heavy filters) report progress, or use the Tasks extension if the hosts in use support it
- [ ] #7 README and AGENTS.md show how to register it with an MCP host, and a test drives the server over stdio against a stub of the command layer
<!-- AC:END -->
