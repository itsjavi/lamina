---
id: TASK-39
title: Landing page at itsjavi.com/lamina
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
  - TASK-38
references:
  - 'https://github.com/itsjavi/notemd'
  - >-
    backlog/decisions/decision-7 -
    Position-Lamina-as-a-lean-open-source-agent-ready-Photoshop-and-Affinity-alternative-under-50-MB.md
priority: medium
type: feature
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Like NoteMD's (github.com/itsjavi/notemd: web/index.html and styles.css, deployed by .github/workflows/pages.yml to itsjavi.com/notemd/ on every push to main that touches web/, plus a social card and a brand/README.md that says what to update when the UI changes). Lamina gets the same, leading with decision-7's pitch and sharing the README's screenshots (TASK-38). The video section waits for TASK-40.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 web/index.html and web/styles.css: hero with icon, tagline and the dark screenshot, why, feature rows, a details grid and build steps; works at phone width and in light and dark
- [ ] #2 .github/workflows/pages.yml deploys web/ to https://itsjavi.com/lamina/ on pushes to main that touch web/
- [ ] #3 A social card (web/assets/og-image.jpg) generated from a script in scripts/, and page metadata (title, description, Open Graph, icon)
- [ ] #4 brand/README.md lists the README, website, screenshots, social card and video, and what to update when a feature ships or the UI changes; AGENTS.md points to it
<!-- AC:END -->
