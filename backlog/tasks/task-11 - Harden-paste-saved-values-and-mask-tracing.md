---
id: TASK-11
title: 'Harden paste, saved values and mask tracing'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/12'
  - 'https://github.com/robbietilton/Compositor/pull/10'
  - 'https://github.com/robbietilton/Compositor/pull/17'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: bug
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three robustness gaps from upstream's closed hardening PRs that still exist in the fork (doc-1 §1): pasting skips the DocumentLimits checks that saving enforces, so a very large paste leaves a document that can't be saved (PR #12); project loading only checks that rotation and hue values are finite, and the inspector traps formatting huge ones, which agent-written projects make more likely (PR #10); turning a mask into a selection builds an unbounded edge graph on the main actor, while Magic Wand already has a capped native tracer (PR #17).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pasting and duplicating pixels check the same DocumentLimits as import and save; a paste that is too large is refused with a message
- [ ] #2 Loading a project rejects or clamps out-of-range rotation and hue values, and the inspectors format any value without trapping
- [ ] #3 Making a selection from a mask or layer (⌘-click its thumbnail) uses the capped native tracer, so a noisy mask on a large layer can't hang the app
- [ ] #4 Tests cover each case
<!-- AC:END -->
