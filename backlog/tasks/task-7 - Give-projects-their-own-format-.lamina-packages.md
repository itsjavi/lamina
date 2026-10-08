---
id: TASK-7
title: 'Give projects their own format: .lam packages'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-08 18:58'
labels:
  - identity
  - format
milestone: m-0
dependencies:
  - TASK-6
references:
  - >-
    backlog/decisions/decision-2 -
    Rename-the-fork-to-Lamina-with-its-own-project-format-.lamina.md
  - docs/project-format.md
  - docs/writing-comp-files.md
priority: high
type: feature
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina and upstream Compositor both write .comp packages with the same type, format id and version numbers, so any fork-only format change would collide with upstream's (decision-2, doc-1). Projects get their own extension (.lam, per decision-2's amendment), type and format id; the package layout and today's content stay the same, and upstream projects open as an import. The vector work (m-2) bumps this format next.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 New projects save as .lam packages of the exported type com.itsjavi.lamina.project, with "format": "com.itsjavi.lamina.project" and version 11 in manifest.json
- [x] #2 Upstream .comp projects up to version 11 open as imports (File › Open, Open With, drag and drop) and save as .lam; the app no longer writes or exports the .comp type
- [x] #3 Finder shows .lam projects as packages owned by the app, and external-change reloading works for them
- [x] #4 docs/project-format.md and the guide for writing projects (renamed from docs/writing-comp-files.md) describe the Lamina format, and tests cover saving, reopening and importing a .comp project
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ProjectStore: exported UTType com.itsjavi.lamina.project, imported com.compositor.project; the manifest writes the Lamina id; load accepts Lamina 1–11 and Compositor 1–11 (supportedVersions(for:)).
2. Opening a Compositor project installs it untitled (projectURL nil, importedFrom set), so Save asks for a .lam; `documentName` names the window and panels.
3. Open panels take both types, the Save panel only .lam; drops and Open With go through `isProjectPackage`.
4. Info.plist: Lamina Project owned (Editor), Compositor Project as an Alternate viewer; .lam exported, .comp imported.
5. Docs: project-format.md, writing-comp-files.md → writing-lamina-projects.md; tests.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Imports aren't added to Recent Projects and aren't watched for external changes (they have no file of their own until saved).
- A .comp declaring version 12 or later is refused: upstream's 12 means something else until ported.

Validation:
- ProjectTests (13, three new: Lamina format on save, .comp opens as an untitled import that saves as .lam and leaves the .comp alone, Compositor 12+ and unknown formats refused) and ExternalChangeTests (6, now on .lam packages) pass; the 111 tests of the other suites that save and load projects pass.
- After lsregister, NSWorkspace treats a .lam folder as a package that opens with Lamina.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Projects are now .lam packages of type com.itsjavi.lamina.project with that format id in the manifest (version 11); upstream .comp projects up to version 11 open as untitled imports that save as .lam. Docs (project-format.md, writing-lamina-projects.md) describe the Lamina format. Verified by new and existing project tests and Launch Services.
<!-- SECTION:FINAL_SUMMARY:END -->
