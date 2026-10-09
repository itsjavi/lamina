---
id: TASK-79
title: Edit ▸ Search (⌘F)
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/200'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 79000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop's Edit ▸ Search (⌘F) finds commands, tools and panels by name and runs them; Lamina has nothing like it, and macOS's Help ▸ Search only finds menu items. Upstream merged a command palette (PR #200, then 384632d, 231b7d3, 07b8b1e, 94b57f7, bba92dc, 720c121, 6b81d4a) that ended up on ⌘F. Reusable almost as is: CommandPaletteSearch (ranking), CommandPaletteMenu (a live walk of the menus that finds items again by path and shows their keys), the panel controller and its three tests. Rebuild the tool entries from ToolSlot.items with Lamina's names and keys (planned tools show their message), keep Window's panel items, and draw rows with color roles. Research: doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ⌘F opens a search field over the window; typing lists menu commands, tools and panels by name, best matches first, with their keys
- [ ] #2 Return or a click runs the chosen row as its menu item, tool key or panel would; Escape closes it
- [ ] #3 Dimmed menu items show dimmed and don't run; a test covers ranking and running a menu item
- [ ] #4 Its in-progress placeholder (PlannedFeature) is replaced by the working control, and its DESIGN.md row goes
<!-- AC:END -->
