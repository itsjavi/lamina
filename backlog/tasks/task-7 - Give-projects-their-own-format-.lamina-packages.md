---
id: TASK-7
title: 'Give projects their own format: .lamina packages'
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
labels:
  - identity
  - format
milestone: m-0
dependencies: []
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
Lamina and upstream Compositor both write .comp packages with the same type, format id and version numbers, so any fork-only format change would collide with upstream's (decision-2, doc-1). Projects get their own extension, type and format id; the package layout and today's content stay the same, and upstream projects open as an import.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New projects save as .lamina packages of the exported type com.itsjavi.lamina.project, with "format": "com.itsjavi.lamina.project" and version 11 in manifest.json
- [ ] #2 Upstream .comp projects up to version 11 open as imports (File › Open, Open With, drag and drop) and save as .lamina; the app no longer writes or exports the .comp type
- [ ] #3 Finder shows .lamina projects as packages owned by the app, and external-change reloading works for them
- [ ] #4 docs/project-format.md and docs/writing-comp-files.md describe the Lamina format, and tests cover saving, reopening and importing a .comp project
<!-- AC:END -->
