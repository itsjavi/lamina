---
id: TASK-61
title: Layers panel in the familiar anatomy
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies:
  - TASK-58
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Layers panel uses two-line rows, a labeled Blend row with a slider, "Folder" for groups and its own footer order. Switchers look for a blend menu and an Opacity field on top, one-line rows with layer and mask thumbnails, an Effects row under styled layers, and the footer in the usual order.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The top row holds the blend mode menu and the Opacity field
- [ ] #2 Rows are one line: eye, thumbnail, link, mask thumbnail, name and an fx badge; clicking the layer or the mask thumbnail chooses which one edits target
- [ ] #3 Styled layers list an Effects row and one row per effect, each with its own eye
- [ ] #4 Groups are called groups everywhere in the interface (was "folder")
- [ ] #5 The footer reads, left to right: Add a layer style (a menu with Blending Options… and each effect in docs/DESIGN.md's order), Add layer mask, New fill or adjustment layer, New group, New layer, Delete
- [ ] #6 Drag and drop, renaming, clipping and multi-selection tests still pass
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
