---
id: TASK-37
title: 'App icon: stacked layers and a pencil on a warm gradient'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-08 18:44'
updated_date: '2026-10-08 20:26'
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
- [x] #1 Resources/AppIcon.icon (Icon Composer) has the new design with light and dark appearances, compiled by scripts/build-app.sh for both builds
- [x] #2 The background is a peach-to-golden gradient; the foreground is stacked layers with a pencil, drawn as simple vector shapes with no blue, purple or green
- [x] #3 It reads clearly at Dock and Finder sizes down to 16 pt, checked in the built app next to system icons
- [x] #4 A PNG export for the README and website lives in web/assets/icon.png
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
First version (pencil writing on the sheets) read as a writing app; the user asked for a brush and a doodle on the top layer in the pencil's red.

Final design, drawn by scripts/app-icon.swift into Resources/AppIcon.icon: three stacked rounded diamond sheets with a red (#F2512E) S-wave painted on the top one, ending in a round wood-handled brush with a silver ferrule and red-tipped bristles, at 50°; peach (#FFA576) to golden amber (#F49E12) gradient, dark #E8875A → #C77A12; glass settings as NoteMD and ProjectHub. web/assets/icon.png: 1024 px light render, 8-bit sRGB. The old 1.2 MB gradient image is gone.

Validation: xcrun actool compiles it with build-app.sh's flags (no errors or warnings); make dev bundles Assets.car and AppIcon.icns; renders of the built Dev app next to NoteMD, ProjectHub and Finder at 256–16 pt, light and dark, read at 32 pt (16 pt: a red mark on a cream stack). The user approved it from the renders.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New app icon: a brush painting a red wave on three stacked layers, over a peach-to-golden gradient with a dark variant, drawn procedurally (scripts/app-icon.swift) into the Icon Composer icon, plus a 1024 px PNG for the README and website. Verified with actool, the Dev build and Dock-size renders next to the user's other apps; approved by the user.
<!-- SECTION:FINAL_SUMMARY:END -->
