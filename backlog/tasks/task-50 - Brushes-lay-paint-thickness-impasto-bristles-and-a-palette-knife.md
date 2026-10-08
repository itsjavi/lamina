---
id: TASK-50
title: 'Brushes lay paint thickness: impasto bristles and a palette knife'
status: To Do
assignee: []
created_date: '2026-10-08 23:22'
labels:
  - painting
milestone: m-4
dependencies:
  - TASK-49
  - TASK-46
  - TASK-43
references:
  - backlog/docs/research/doc-3 - Agent-painting-research.md
priority: low
type: feature
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Once layers keep thickness, brushes have to lay it the way paint does: thick where the brush is loaded, ridged along strands and at the stroke's end, thin when it runs dry, and a knife that spreads and flattens. The experiment's rules (doc-3: thickness follows the light, little relief on small accents, no round blobs at stroke ends) are the starting point.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Bristle and mixer brushes lay thickness with their paint, set by an impasto amount: ridges along strands and where the brush lifts, less as the load runs out
- [ ] #2 A palette knife spreads and flattens paint and its thickness
- [ ] #3 `paint-strokes` takes the impasto amount and the knife, so agents paint with relief
- [ ] #4 Tests cover thickness laid by strokes and flattened by the knife
<!-- AC:END -->
