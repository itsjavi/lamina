---
id: TASK-73
title: Layers panel and Adjustments grid don't flash dimmed during strokes and moves
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/06313a9'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: bug
ordinal: 73000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
canEditLayers turns false while a brush stroke, warp stroke, pixel move or transform edit is under way, and the Layers footer, eyes, disclosure triangles, top row and the Adjustments grid bind their enabled state to it, so they dim and the list reloads every row at the start and end of every stroke or Move drag. That breaks Lamina's own showsBusy rule (quick edits never flash the interface). Upstream 06313a9 separates how the panel looks from what it allows. Actions must keep guarding on canEditLayers; Lamina's version also has to cover commandDialog and layerStyle, which upstream doesn't have. Adapt with Co-authored-by: Robbie <1269226+robbietilton@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A click, a brush stroke or a Move drag no longer dims the Layers panel or the Adjustments grid, nor reloads the layer rows
- [ ] #2 Long work (showsBusy) and open dialogs still dim them, and every action is still refused while layers can't be edited
- [ ] #3 A test covers the look staying enabled during a stroke while edits are refused
<!-- AC:END -->
