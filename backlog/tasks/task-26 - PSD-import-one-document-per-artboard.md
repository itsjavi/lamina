---
id: TASK-26
title: 'PSD import: one document per artboard'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
  - psd
milestone: m-1
dependencies:
  - TASK-2
references:
  - 'https://github.com/robbietilton/Compositor/issues/65'
  - 'https://github.com/robbietilton/Compositor/pull/48'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: feature
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Photoshop files with artboards import as one flat canvas today; the reader ignores artboards (upstream issue #65, which upstream wanted). Closed PR #48 imported one document per artboard. Build it into CompositorCore's PSD code (TASK-2).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A PSD with artboards opens as one document per artboard, each cropped to its artboard and holding its layers
- [ ] #2 PSDs without artboards import as before
- [ ] #3 Tests use a PSD fixture with several artboards
<!-- AC:END -->
