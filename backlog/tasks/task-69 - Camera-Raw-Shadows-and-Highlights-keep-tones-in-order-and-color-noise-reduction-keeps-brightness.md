---
id: TASK-69
title: >-
  Camera Raw: Shadows and Highlights keep tones in order, and color noise
  reduction keeps brightness
status: To Do
assignee: []
created_date: '2026-10-09 15:51'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/commit/0b4c56c'
  - 'https://github.com/robbietilton/Compositor/commit/42a559b'
  - 'https://github.com/robbietilton/Compositor/issues/236'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: medium
type: bug
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two Camera Raw kernel fixes from upstream, both in Sources/CPixels/AdjustPixels.c. At high values the Shadows slider lifts the darkest tones above the ones just brighter (tone_shadows is not monotonic: with Shadows at +100 black maps to 0.5 and 0.1 to about 0.36), so dark areas break into blocks of color (upstream issue #236); Highlights pulled down has the mirror problem. Upstream 0b4c56c lifts them on a curve that keeps every tone in order with black staying black. Separately, Color noise reduction blurs an HSL saturation plane, which also shifts brightness; upstream 42a559b smooths color and keeps brightness. Lamina's code matches upstream's before both commits (TASK-10 made the main pass multicore but left these blocks as they were). Port with Co-authored-by: Robbie <1269226+robbietilton@users.noreply.github.com>.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shadows and Highlights at any value keep tone order (a monotonic mapping), black stays black and white stays white, as upstream's shadowsAndHighlightsKeepTonesInOrder test shows
- [ ] #2 Color noise reduction removes color grain without changing brightness, as upstream's colorNoiseReductionRemovesColorGrainNotBrightness test shows, and clear pixels still don't leak color (colorNoiseReductionIgnoresWhatClearPixelsHeld)
- [ ] #3 CameraRawSpeedTests' pixel hashes are re-recorded only for the settings these fixes change (light, the two clipping cases, detail), and the rest still match
<!-- AC:END -->
