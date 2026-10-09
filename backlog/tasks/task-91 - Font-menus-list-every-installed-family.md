---
id: TASK-91
title: Font menus list every installed family
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/207'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Type bar's and Properties' family menus list NSFontManager.availableFontFamilies, which leaves out families macOS installs but hides from the font list (on macOS 27: Rockwell, Seravek, Iowan Old Style, Athelas and about a hundred more; checked: availableMembers still returns their faces). Text in such a face, from a Photoshop file for example, can't reach its other styles. Upstream's open PR #207 (commit 1) adds the family in use when it isn't listed; listing every family is better. Research: doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The family menus list families macOS hides from availableFontFamilies, so Rockwell, Seravek and the like can be chosen with all their styles
- [ ] #2 A test checks a hidden family is offered (skipped where it isn't installed)
<!-- AC:END -->
