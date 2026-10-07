---
id: TASK-20
title: 'Brush: settings across documents, Dodge and Burn'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
  - brush
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/166'
  - 'https://github.com/robbietilton/Compositor/pull/193'
  - 'https://github.com/robbietilton/Compositor/issues/169'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Brush settings reset with every new document (upstream issue #2 is only partly done; PR #166 keeps them in ToolDefaults). Dodge and Burn are core retouching tools (issue #169; PR #193, as Brush modes with a new C kernel). Upstream keeps the brush simple on purpose; Lamina decided otherwise (doc-1).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Brush tip, size, hardness, opacity, smoothing, mode and colors carry over to new documents and later launches
- [ ] #2 Dodge and Burn modes with Range (shadows, midtones, highlights) and Exposure behave as Photoshop's, refuse masks and apply one undo step per stroke
- [ ] #3 Tests cover both
<!-- AC:END -->
