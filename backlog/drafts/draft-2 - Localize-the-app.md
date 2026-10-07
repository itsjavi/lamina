---
id: DRAFT-2
title: Localize the app
status: Draft
assignee: []
created_date: '2026-10-07 20:36'
labels:
  - postponed
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/126'
  - 'https://github.com/robbietilton/Compositor/pull/113'
  - 'https://github.com/robbietilton/Compositor/pull/213'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: low
type: spike
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Postponed (doc-1 decisions). Upstream's localization PRs (zh-Hans, zh-Hant, French) show the groundwork: a String Catalog with display names on enums, persisted raw values kept in English, blend modes matched by tag rather than title. Under SwiftPM the catalog compiles into Bundle.module while SwiftUI reads Bundle.main, so build-app.sh must copy the .lproj folders. Best references: closed PRs #126 and #113, open PR #213.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A decision records which languages and how translations are maintained
<!-- AC:END -->
