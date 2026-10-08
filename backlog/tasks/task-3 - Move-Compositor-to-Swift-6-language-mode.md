---
id: TASK-3
title: Move Lamina to Swift 6 language mode
status: To Do
assignee: []
created_date: '2026-10-07 17:48'
updated_date: '2026-10-08 21:45'
labels: []
dependencies: []
references:
  - >-
    backlog/decisions/decision-1 -
    Build-Compositor-as-a-SwiftPM-package-with-its-own-identity-diverging-from-upstream.md
  - Package.swift
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
LaminaApp, LaminaCore and the app tests build in Swift 5 language mode with approachable concurrency, as the Xcode project did (decision-1); LaminaAutomation, LaminaCLI and lamina already use Swift 6 mode. The sibling apps use Swift 6 mode, which turns data-race diagnostics into errors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Package.swift uses Swift 6 language mode for every Swift target
- [ ] #2 swift build and swift test pass with no new concurrency warnings
- [ ] #3 No @unchecked Sendable or nonisolated(unsafe) is added without a comment that justifies it
<!-- AC:END -->
