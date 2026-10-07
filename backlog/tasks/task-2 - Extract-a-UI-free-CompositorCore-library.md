---
id: TASK-2
title: Extract a UI-free CompositorCore library
status: To Do
assignee: []
created_date: '2026-10-07 17:48'
labels: []
dependencies: []
references:
  - >-
    backlog/decisions/decision-1 -
    Build-Compositor-as-a-SwiftPM-package-with-its-own-identity-diverging-from-upstream.md
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The sibling apps keep models, file formats and other logic that's testable without UI in a Core library. Compositor's code is all in the app target today (decision-1 chose structure first). About 6k lines import neither SwiftUI nor AppKit (the PSD reader and builder, project store and digest, canvas and image sizing, guides, history), but they lean on types such as EditorSession and the layer model that live in AppKit-importing files, so extraction means untangling those first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A CompositorCore target holds the .comp project format and the PSD reader and writer, with no SwiftUI or AppKit imports
- [ ] #2 Their tests depend on CompositorCore alone and pass with swift test
- [ ] #3 The app's behavior and the full test suite are unchanged
- [ ] #4 AGENTS.md describes the Core boundary
<!-- AC:END -->
