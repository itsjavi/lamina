---
id: TASK-88
title: PSD import keeps layer effects
status: To Do
assignee: []
created_date: '2026-10-09 16:32'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/160'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: feature
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Opening a Photoshop file drops every layer effect with a note ('Layer effects were discarded', PSDDocumentBuilder), although Lamina has Stroke, Inner Shadow, Inner Glow, Color Overlay, Outer Glow and Drop Shadow. Reading the lfx2 descriptor would keep them editable (follow-up to upstream issue #160). Settings Lamina lacks (blend modes, spread, choke, contours, noise) map to the nearest value with a note until the Layer Style task brings them. Research: doc-1 §6, doc-4.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PSD import maps Stroke, Inner Shadow, Inner Glow, Color Overlay, Outer Glow and Drop Shadow from lfx2 to Lamina's effects, enabled or hidden as in the file
- [ ] #2 Settings Lamina can't show are listed in the import notes; tests read fixtures with each effect
<!-- AC:END -->
