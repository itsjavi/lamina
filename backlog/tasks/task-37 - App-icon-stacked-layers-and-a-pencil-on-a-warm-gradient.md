---
id: TASK-37
title: 'App icon: stacked layers and a pencil on a warm gradient'
status: To Do
assignee: []
created_date: '2026-10-08 18:44'
labels:
  - identity
milestone: m-0
dependencies: []
priority: high
type: feature
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Lamina still ships upstream Compositor's icon. It needs its own, sitting well in the Dock next to the user's other two apps (NoteMD: teal with documents and a hash; a blue app with a play button and a grid), so it takes neither of their hues. The user's brief: a gradient background in peach and golden tones, stacked layers with a pencil in the foreground, simple vector shapes; no blue, purple or lime/green.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resources/AppIcon.icon (Icon Composer) has the new design with light and dark appearances, compiled by scripts/build-app.sh for both builds
- [ ] #2 The background is a peach-to-golden gradient; the foreground is stacked layers with a pencil, drawn as simple vector shapes with no blue, purple or green
- [ ] #3 It reads clearly at Dock and Finder sizes down to 16 pt, checked in the built app next to system icons
- [ ] #4 A PNG export for the README and website lives in web/assets/icon.png
<!-- AC:END -->
