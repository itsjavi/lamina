---
id: TASK-71
title: Layers panel reveals the layer picked on the canvas
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/235'
  - 'https://github.com/robbietilton/Compositor/commit/d2b8aaf'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: enhancement
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When Auto-Select or any canvas action makes a layer active inside a collapsed group, or below the visible rows, the Layers panel leaves it hidden: selectLayer and selectLayers don't expand the layer's groups, and the list only scrolls to a row for renaming. Photoshop opens the groups and scrolls to the layer. Upstream PR #235 (d2b8aaf, by Lens-lzy) adds revealActiveLayer() (LayerGroups) and has the list scroll the active row into view; b4e147b then dropped its tests. Port with Co-authored-by: Lens-lzy <60784629+Lens-lzy@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A layer made active from the canvas (Auto-Select, a click on its pixels, a lamina command) inside collapsed groups expands those groups and its row scrolls into view
- [ ] #2 Selecting from the Layers panel itself doesn't scroll or expand anything it didn't before
- [ ] #3 LayersPanelTests cover the expand and the scroll, and DESIGN.md's Layers section says it
<!-- AC:END -->
