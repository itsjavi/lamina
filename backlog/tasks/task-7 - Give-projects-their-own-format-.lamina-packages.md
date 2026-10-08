---
id: TASK-7
title: 'Give projects their own format: .lam packages'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
updated_date: '2026-10-08 18:43'
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
- [ ] #1 New projects save as .lam packages of the exported type com.itsjavi.lamina.project, with "format": "com.itsjavi.lamina.project" and version 11 in manifest.json
- [ ] #2 Upstream .comp projects up to version 11 open as imports (File › Open, Open With, drag and drop) and save as .lam; the app no longer writes or exports the .comp type
- [ ] #3 Finder shows .lam projects as packages owned by the app, and external-change reloading works for them
- [ ] #4 docs/project-format.md and the guide for writing projects (renamed from docs/writing-comp-files.md) describe the Lamina format, and tests cover saving, reopening and importing a .comp project
<!-- AC:END -->
