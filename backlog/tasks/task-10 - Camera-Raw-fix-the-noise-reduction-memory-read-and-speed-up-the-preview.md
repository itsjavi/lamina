---
id: TASK-10
title: 'Camera Raw: fix the noise-reduction memory read and speed up the preview'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
  - performance
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/178'
  - 'https://github.com/robbietilton/Compositor/pull/179'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: high
type: bug
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Color noise reduction in Sources/CPixels/AdjustPixels.c skips clear pixels without writing the malloc'ed chroma plane, then blurs it, reading uninitialized memory (upstream PR #178). Upstream PR #179 also makes the preview about 9x faster with identical pixels (work across cores, a lookup table for opaque pixels, scopes measured on a small copy). Its pixel hashes were recorded with upstream's build, so record the expected output against the fork's current single-threaded kernel before switching.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Clear pixels get a defined chroma value, so noise reduction never reads uninitialized memory
- [ ] #2 The preview renders the same pixels as before, pinned by tests recorded against the current kernel, and is measurably faster on a 24 MP image (timings before and after in the notes)
- [ ] #3 Timing-sensitive tests can't make CI flaky
<!-- AC:END -->
