---
id: TASK-39
title: Landing page at itsjavi.com/lamina
status: Done
assignee:
  - '@claude'
created_date: '2026-10-08 18:44'
updated_date: '2026-10-08 22:00'
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
- [x] #1 web/index.html and web/styles.css: hero with icon, tagline and the dark screenshot, why, feature rows, a details grid and build steps; works at phone width and in light and dark
- [x] #2 .github/workflows/pages.yml deploys web/ to https://itsjavi.com/lamina/ on pushes to main that touch web/
- [x] #3 A social card (web/assets/og-image.jpg) generated from a script in scripts/, and page metadata (title, description, Open Graph, icon)
- [x] #4 brand/README.md lists the README, website, screenshots, social card and video, and what to update when a feature ships or the UI changes; AGENTS.md points to it
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- web/index.html + styles.css adapted from NoteMD's (the user's own, MIT): Lamina palette (light #fbf6f0 / dark #15100d; primary buttons rust #8a3b1c / #6e3119 with white text, ≥4.5:1 including hover), hero with the dark app screenshot, a Why card, feature rows (Camera Raw, adjustment layers, agents with a command block), a details grid, build steps, footer crediting Compositor. No video section until TASK-40.
- Checked with headless Chrome in light and dark at 1440 px and at 390 px (inside an iframe: headless Chrome's viewport won't go below 500 px).
- Social card scripts/og-image.html → web/assets/og-image.jpg (2400×1260); favicon.png and apple-touch-icon.png from the icon.
- GitHub Pages enabled on itsjavi/lamina (built from Actions, with the user's go-ahead). pages.yml run 37848722510 succeeded; https://itsjavi.com/lamina/ and its assets return 200. The README links the site.
- Left: AGENTS.md pointer to brand/README.md, after the LaminaCore branch (which edits AGENTS.md) is merged.

AGENTS.md now lists web/ and brand/ (pointing to brand/README.md), the screenshot and social-card scripts, pages.yml, and a convention that user-facing features and UI changes update the README, website and screenshots in the same task.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Landing page live at https://itsjavi.com/lamina/: NoteMD's layout in Lamina's palette (light, dark, phone), hero and feature screenshots shared with the README, a social card (scripts/og-image.html), favicons, and pages.yml deploying web/ on pushes to main (GitHub Pages enabled with the user's go-ahead). brand/README.md and AGENTS.md say what to keep in sync. Verified with headless renders and the live site.
<!-- SECTION:FINAL_SUMMARY:END -->
