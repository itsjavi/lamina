---
id: TASK-10
title: 'Camera Raw: fix the noise-reduction memory read and speed up the preview'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-07 21:30'
labels:
  - upstream
  - performance
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/178'
  - 'https://github.com/robbietilton/Compositor/pull/179'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: high
type: bug
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Color noise reduction in Sources/CPixels/AdjustPixels.c skips clear pixels without writing the malloc'ed chroma plane, then blurs it, reading uninitialized memory (upstream PR #178). Upstream PR #179 also makes the preview about 9x faster with identical pixels (work across cores, a lookup table for opaque pixels, scopes measured on a small copy). Its pixel hashes were recorded with upstream's build, so record the expected output against the fork's current single-threaded kernel before switching.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Clear pixels get a defined chroma value, so noise reduction never reads uninitialized memory
- [ ] #2 The preview renders the same pixels as before, pinned by tests recorded against the current kernel, and is measurably faster on a 24 MP image (timings before and after in the notes)
- [ ] #3 Timing-sensitive tests can't make CI flaky
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Port PR #178 (clear pixels write 0 into the chroma plane) with its regression test.
2. Before switching kernels, pin the output: hash tests (Light, both clipping views, Effects, Detail, tiny pictures) recorded on the current single-threaded kernel in this package's build (CPixels -O3), with the #178 fix in so Detail is deterministic.
3. Add an opt-in benchmark (CAMERA_RAW_BENCHMARK=1) of a 24 MP photo: preview step on the 2048 px preview copy (scopes included) and the full-size apply; measure in a release build before and after.
4. Port PR #179 (rows across cores with dispatch_apply, lookup table for opaque pixels, banded column blur, scopes counted on a <=512 px copy) and check the hashes still match.
5. Keep timing out of CI: the timing suite is disabled unless the env var is set.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Hashes recorded on the current kernel (after #178, before #179) with swift test --disable-keychain --filter CameraRawSpeedTests: all 8 equal the values upstream recorded in PR #179 (13877237661017904764, 1047115404880164632, 9026041150702649921, 2862192429195149811, 5617087740119641898; tiny 5558979605539197941, 15426182781399563245, 5994485904874808949), so -O3 doesn't change the pixels.
After porting #179: swift test --disable-keychain --filter 'CameraRawSpeedTests|CameraRawTests|CameraRawSliderTests|CameraRawTimingTests' -> 33 tests in 4 suites passed, timing suite skipped.
Timings, CAMERA_RAW_BENCHMARK=1 swift test -c release -Xswiftc -enable-testing --filter CameraRawTimingTests, Apple M1 Max (10 cores), best of 5, 6000x4000 photo, preview copy 2048x1365 (other agents were building on the same machine, so treat as approximate):
| Step | Before | After |
| Light and Color preview step (scopes included) | 491 ms | 43 ms (11x) |
| Effects (texture, clarity, dehaze, glow, vignette) preview step | 313 ms | 32 ms (10x) |
| Detail (sharpen, noise reduction) preview step | 378 ms | 218 ms (scopes only; the detail kernel stays single-threaded) |
| Light and Color on the full 24 MP image (commit) | 3447 ms | 275 ms (13x) |
Upstream's two always-on timing tests (thresholds of 200 and 100 ms, skipped only under code coverage) are replaced by the opt-in suite, so CI never times anything.
<!-- SECTION:NOTES:END -->
