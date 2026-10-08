---
id: TASK-2
title: Extract the project format and PSD parsing into a UI-free LaminaCore
status: To Do
assignee: []
created_date: '2026-10-07 17:48'
updated_date: '2026-10-08 18:44'
labels: []
dependencies:
  - TASK-6
  - TASK-7
references:
  - >-
    backlog/decisions/decision-1 -
    Build-Compositor-as-a-SwiftPM-package-with-its-own-identity-diverging-from-upstream.md
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
All of Lamina's app code is in one app target (decision-1 chose structure first). The project format is the part worth separating first: it is a contract other tools write to (docs/project-format.md and the guide for writing projects: agents build projects and the open app reloads them live), yet today its only implementation lives inside the app, next to AppKit.

Benefits:
- Faster, simpler tests: format and PSD parsing tests run against a plain library, without AppKit, the window server or LaminaTestHost, and off the main actor, so they're quick and can't be disturbed by UI state.
- One implementation for other tools: `lamina` (TASK-4) and its MCP server (TASK-5) can inspect, validate and create projects through the library. Today agents write manifests by hand from the docs, and a mistake only shows when the app refuses the project.
- Validation in one place: the same checks the app runs when loading (format id, version, layer files, masks) can tell an agent or script exactly what is wrong.
- A boundary the compiler enforces: the format can't pick up UI dependencies again, and the library builds nonisolated, so loading and saving don't depend on main-actor state.

Scope: the manifest and its layer records, reading, writing and validating `.lam` packages (and importing `.comp`), and PSD parsing. The manifest's value types come along: CanvasGuide, LayerTransform and LayerBlendMode are already AppKit-free, but LayerAdjustment, LayerShapeStyle, LayerEffects and LayerTextStyle live in files that mix their Codable data with AppKit behavior, so their data moves to the library and the behavior stays in the app as extensions. Project snapshots carry images as CGImage rather than the app's ImportedImage.

Out of scope: the editor model (EditorSession, layers as edited), rendering, filters and PSD-to-document conversion (PSDDocumentBuilder, PSDText), which stay in the app. Live control of the running app is TASK-4.

Test time: on 2026-10-08 `swift test` ran 709 tests in 100 suites in 118 s wall clock. The user wants the suite faster; measure where the time goes before starting. If the window-hosted editor tests dominate, extracting the format alone won't help much: propose widening the scope to the editor model instead of doing it silently.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A LaminaCore target holds the project manifest and layer records, their value types, project reading, writing and validation, and PSD parsing, with no SwiftUI or AppKit imports
- [ ] #2 The app loads, saves and watches projects and imports PSDs through LaminaCore, with no change in behavior; the full test suite passes
- [ ] #3 Format and PSD tests live in a LaminaCoreTests target that depends only on LaminaCore and runs without LaminaTestHost
- [ ] #4 docs/project-format.md and AGENTS.md name LaminaCore as the format's implementation and describe the boundary
- [ ] #5 The suite's wall-clock time before and after is recorded in the task notes
<!-- AC:END -->
