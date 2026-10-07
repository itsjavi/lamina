---
id: TASK-13
title: File › New from Clipboard
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/159'
  - 'https://github.com/robbietilton/Compositor/pull/201'
  - 'https://github.com/robbietilton/Compositor/pull/176'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Starting a document from a screenshot or a copied image takes New Canvas, Return and then Paste today. Decided in doc-1: add File › New from Clipboard (upstream issue #159, the most wanted feature request; PR #201, plus PR #176's handling of files copied in Finder).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 File › New from Clipboard opens a new document the size of the copied image, with it as the only layer, in one step; copied images and image files copied in Finder both work
- [ ] #2 The command is disabled when the clipboard holds no image, and its shortcut doesn't take Photoshop's Paste in Place (⇧⌘V)
- [ ] #3 Tests use a private pasteboard, never the user's clipboard
<!-- AC:END -->
