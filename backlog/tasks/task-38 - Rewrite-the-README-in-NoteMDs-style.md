---
id: TASK-38
title: Rewrite the README in NoteMD's style
status: To Do
assignee: []
created_date: '2026-10-08 18:44'
updated_date: '2026-10-08 18:44'
labels:
  - identity
milestone: m-0
dependencies:
  - TASK-6
  - TASK-37
references:
  - 'https://github.com/itsjavi/notemd'
  - >-
    backlog/decisions/decision-7 -
    Position-Lamina-as-a-lean-open-source-agent-ready-Photoshop-and-Affinity-alternative-under-50-MB.md
priority: high
type: docs
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The README still follows upstream Compositor's layout and a long feature dump. The user wants it like NoteMD's (github.com/itsjavi/notemd): centered icon, name and tagline, links to the website, light and dark screenshots, a short "Why Lamina", a scannable feature list, a screenshot table, requirements and building. It leads with decision-7's pitch. No intro video yet: the UI changes with vector support (TASK-40 tracks the video).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README.md opens with the icon, name, tagline (decision-7) and links to the website, features, building and the license
- [ ] #2 Light and dark screenshots of the main window, plus a table of feature screenshots, all shared with the website under web/assets/
- [ ] #3 Screenshots are taken from the Dev build with a demo project that a script recreates, so they can be retaken after UI changes
- [ ] #4 A short "Why Lamina", the feature list grouped as today, requirements, building, the command-line tool and MCP server, and credits to upstream Compositor (MIT)
<!-- AC:END -->
