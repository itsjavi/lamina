---
id: TASK-24
title: 'Import WebP; export AVIF, WebP, HEIC, TIFF and PDF'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
  - formats
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/168'
  - 'https://github.com/robbietilton/Compositor/pull/149'
  - 'https://github.com/robbietilton/Compositor/pull/208'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decided in doc-1: more export formats, at least WebP and AVIF, and PDF if simple. ImageIO decodes WebP but the importer leaves it out (upstream issue #168). ImageIO encodes AVIF, HEIC, TIFF and PDF (checked on macOS 27; AVIF still to check on macOS 26), but not WebP, which needs libwebp (BSD-3-Clause) as a vendored C target. References: closed PR #149 (export sheet), PR #208 (PDF).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 WebP images open, drop and place like other images
- [ ] #2 Export offers AVIF, HEIC, TIFF and PDF through ImageIO, listing only formats the running macOS can encode, with quality settings where the format has them
- [ ] #3 WebP export works through a vendored libwebp with its license in Credits.html, or the task notes record why it was left out
- [ ] #4 Tests round-trip each format
<!-- AC:END -->
