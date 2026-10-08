---
id: TASK-5
title: Expose the command-line tool's commands as an MCP server (protocol 2026-07-28)
status: Done
assignee:
  - '@claude'
created_date: '2026-10-07 18:31'
updated_date: '2026-10-07 22:04'
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
- [x] #1 A stdio MCP server shipped with the app exposes every TASK-4 command as a tool, generated from the same command definitions, so adding a command adds its tool
- [x] #2 It implements MCP 2026-07-28: server/discover, per-request protocol version and capabilities, resultType on every result, ttlMs and cacheScope on tools/list, logging only to stderr
- [x] #3 Hosts still on an earlier protocol version that are in use (checked when this is built) can connect, or the unsupported ones are documented
- [x] #4 Tools have JSON Schema input and output schemas, return structuredContent, report command failures as tool errors, and are listed in a deterministic order
- [x] #5 Tool annotations mark read-only commands (listing, inspecting) and commands that write files (export)
- [x] #6 Commands that take long (exports, heavy filters) report progress, or use the Tasks extension if the hosts in use support it
- [x] #7 README and AGENTS.md show how to register it with an MCP host, and a test drives the server over stdio against a stub of the command layer
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. LaminaMCP library: a stdio JSON-RPC server whose tools are generated from CommandCatalog (name, title, description, JSON Schema 2020-12 input/output schemas, annotations from each command's effect), calling the same CommandClient as the CLI.
2. MCP 2026-07-28: server/discover, per-request protocolVersion and clientCapabilities in _meta (UnsupportedProtocolVersionError otherwise), serverInfo in each result's _meta, resultType on every result, ttlMs and cacheScope on tools/list and discover, deterministic tool order, structuredContent, command failures as isError results, logging only to stderr.
3. Dual-era: answer initialize/notifications/initialized/ping for hosts still on 2025-11-25 (and earlier legacy versions), without the modern-only fields.
4. Progress notifications while a call waits on the app when the request has a progressToken; notifications/cancelled drops the reply.
5. lamina mcp subcommand (same target options); tests drive the server over pipes and its message handler against a stub transport.
6. Check which protocol Claude Code and Codex use and connect both; README and AGENTS.md: registering with Claude Code and Codex.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation: lamina mcp (Sources/LaminaCLI/MCPServer.swift, MCPTools.swift), no SDK — the official Swift MCP SDK (0.12.1) stops at 2025-11-25. Tools come from CommandCatalog: name (apply-filter → apply_filter), title, description (summary, details, kinds and settings), inputSchema (JSON Schema 2020-12, additionalProperties false), outputSchema (the command's result schema), annotations from the command's effect (reads → readOnlyHint; adds → destructiveHint false; edits → destructiveHint true; export/preview write a file → readOnlyHint false, destructiveHint true, idempotentHint true; openWorldHint false). Calls go through the CLI's CommandClient, so validation and file writing are shared; output paths must be absolute over MCP.

Protocol: modern requests (with _meta protocolVersion) are served statelessly for 2026-07-28 (others get -32022 with supported/requested); server/discover returns supportedVersions, capabilities, instructions, ttlMs 3600000 and cacheScope public; every modern result has resultType and serverInfo in _meta; tools/list adds ttlMs/cacheScope. initialize opens a legacy session (2025-11-25, 2025-06-18, 2025-03-26, 2024-11-05) whose results omit the 2026 fields. ping answered; notifications/cancelled drops the reply (the app can't stop a command midway). Progress: with a progressToken, notifications at the start, every 2 s while waiting and at the end (seconds waited; the app answers in one piece over Apple Events). Tasks extension not implemented: neither host uses it. Logging only to stderr; stdout carries only MCP lines.

Hosts checked (end to end against the Dev build, lamina from its bundle):
- Claude Code 2.1.288: opens with initialize (2025-11-25) by default; with MCP_PROTOCOL_NEGOTIATION=auto it probes server/discover and uses 2026-07-28. Both runs called the tools; in the 2026 run Claude read the render_preview image and described it correctly.
- Codex 0.160.0: initialize by default; with --enable mcp_2026_07_28 and CODEX_MCP_PROTOCOL_VERSION=2026-07-28 in the server's env it uses server/discover and 2026-07-28. Both runs called list_documents.

Tests: swift test --filter 'LaminaTests|AutomationTests' — 22 + 18 pass; MCPServerTests (8) cover discover, tools/list order/schemas/annotations, structuredContent and image blocks, tool errors, unsupported version, the legacy handshake, progress and cancellation, and a full exchange over pipes.

![Claude Code added this Hue/Saturation layer through lamina mcp](../assets/task-5/mcp-claude-code-after.png)
![render_preview's image block (256 px) after apply_filter vignette, from a scripted 2026-07-28 session](../assets/task-5/mcp-render-preview.png)
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added lamina mcp, a stdio MCP server shipped in the app's lamina that exposes every command-catalog command as a tool generated from its definition (schemas, annotations), serving MCP 2026-07-28 statelessly (server/discover, per-request _meta, resultType, ttlMs/cacheScope) and the initialize handshake for 2025-11-25 and earlier hosts, with structuredContent, isError tool errors, preview images and progress notifications. Verified with 8 MCPServerTests (including a full stdio exchange against a stub) and end to end with Claude Code 2.1.288 and Codex 0.160.0 against the Dev build, in both protocol eras.
<!-- SECTION:FINAL_SUMMARY:END -->
