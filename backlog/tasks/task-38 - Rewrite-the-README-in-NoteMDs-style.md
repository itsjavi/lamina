---
id: TASK-38
title: Rewrite the README in NoteMD's style
status: Done
assignee:
  - '@claude'
created_date: '2026-10-08 18:44'
updated_date: '2026-10-08 21:19'
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
- [x] #1 README.md opens with the icon, name, tagline (decision-7) and links to features, AI agents, building and the license (the website link comes with TASK-39)
- [x] #2 A screenshot of the main window, plus a table of feature screenshots, all shared with the website under web/assets/ (the app is always dark, so there is no light/dark pair)
- [x] #3 Screenshots are taken from the Dev build with a demo project that a script recreates, so they can be retaken after UI changes
- [x] #4 A short "Why Lamina", the feature list grouped as today, requirements, building, the command-line tool and MCP server, and credits to upstream Compositor (MIT)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Layout follows NoteMD's: centered icon, name and tagline; hero screenshot; Why Lamina; the grouped feature list (Paint Bucket included); a two-shot table (Camera Raw, Curves); the lamina CLI and MCP sections; requirements; building from a clone; license with the Compositor credit.
- Maintainer release steps moved to docs/releasing.md (still R2 until TASK-29). The website link is left out until TASK-39 publishes it.
- AC #1 and #2 reworded: the app forces the dark appearance (ContentView .preferredColorScheme(.dark), darkAqua), so one hero shot instead of light and dark.
- scripts/demo-project.swift writes "Golden Hour.lam" by hand from docs/writing-lamina-projects.md (sky, sun with Outer Glow, hills, a masked lake, a live text title with a drop shadow in a folder, a Curves layer): it loaded in the Dev build unchanged, which also checks the guide.
- scripts/window-screenshot.swift (adapted from NoteMD's) captures without activating the app; --panels draws floating panels over the document window. The window size comes from the Dev build's saved frame ("NSWindow Frame editor"). brand/README.md records the procedure, the current shots and the gotchas.
- Nothing took the user's focus: the Dev build ran with open -g and was driven with background clicks and menu commands.

![Hero: the demo project in the Dev build](../../web/assets/screenshot.webp)
![Camera Raw on the Sky layer](../../web/assets/camera-raw.webp)
![Curves panel for the Warm grade layer](../../web/assets/curves.webp)
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
README rewritten in NoteMD's style with decision-7's pitch, a hero screenshot and a feature table taken from the Dev build with a scripted demo project (scripts/demo-project.swift, scripts/window-screenshot.swift, procedure in brand/README.md); release steps moved to docs/releasing.md. Links and images checked.
<!-- SECTION:FINAL_SUMMARY:END -->
