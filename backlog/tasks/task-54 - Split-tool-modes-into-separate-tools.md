---
id: TASK-54
title: Split tool modes into separate tools
status: To Do
assignee: []
created_date: '2026-10-09 02:14'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Several Lamina tools hide what familiar editors show as separate tools: Brush has Paint, Erase, Dodge and Burn modes; Smear has Liquify, Blur and Smudge; Marquee, Lasso, Magic and Shape switch their kind with a picker or Tab. People scan the toolbar for Eraser, Dodge or Polygonal Lasso and don't find them. The engines can stay shared; what changes is how tools are chosen, keyed and remembered. Liquify isn't a toolbar tool elsewhere, so it moves to Filter ▸ Liquify….
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 These are tools of their own: Rectangular and Elliptical Marquee; Lasso and Polygonal Lasso; Object Selection and Magic Wand; Brush and Eraser; Dodge and Burn; Blur and Smudge; Rectangle, Ellipse and Line
- [ ] #2 Tool keys follow docs/DESIGN.md, and Shift plus a tool's key cycles the tools that share its slot
- [ ] #3 Filter ▸ Liquify… (⇧⌘X) picks the Liquify brush with its own options bar and Done and Cancel; Liquify no longer appears in the toolbar
- [ ] #4 Each tool remembers its own settings as today, and brush defaults saved by earlier versions carry over
- [ ] #5 Status hints, help tags and tests cover the new tools and keys
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->
