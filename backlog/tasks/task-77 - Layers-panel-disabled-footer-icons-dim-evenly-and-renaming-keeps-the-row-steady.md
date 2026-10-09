---
id: TASK-77
title: >-
  Layers panel: disabled footer icons dim evenly, and renaming keeps the row
  steady
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/790195f'
  - 'https://github.com/robbietilton/Compositor/commit/8f7d344'
  - 'https://github.com/robbietilton/Compositor/pull/226'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: enhancement
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two Layers panel details from upstream PR #226 (Stv.X) and 790195f. The footer mixes plain buttons and borderless menus whose icons take an explicit ColorRole.icon foreground, which stops SwiftUI dimming them, so disabled footer icons dim unevenly or not at all (also PropertiesFooterButton). And the rename field gets a rounded bezel that changes the row's height and makes it jump (8f7d344 keeps the field's size and marks editing with a background instead). Upstream's colors (Color.white.opacity, quaternaryLabelColor) are literals; Lamina must use its color roles.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Disabled footer icons in Layers and Properties dim the same way, through a color role, in light and dark
- [ ] #2 Renaming a layer keeps the row and its name at the same size and position, marking the field with a color role background
- [ ] #3 DESIGN.md's Iconography gets the disabled-icon rule and its Layers section the rename look; screenshots in both appearances
<!-- AC:END -->
