---
id: TASK-11
title: 'Harden paste, saved values and mask tracing'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-07 21:36'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/pull/12'
  - 'https://github.com/robbietilton/Compositor/pull/10'
  - 'https://github.com/robbietilton/Compositor/pull/17'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: bug
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three robustness gaps from upstream's closed hardening PRs that still exist in the fork (doc-1 §1): pasting skips the DocumentLimits checks that saving enforces, so a very large paste leaves a document that can't be saved (PR #12); project loading only checks that rotation and hue values are finite, and the inspector traps formatting huge ones, which agent-written projects make more likely (PR #10); turning a mask into a selection builds an unbounded edge graph on the main actor, while Magic Wand already has a capped native tracer (PR #17).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pasting and duplicating pixels check the same DocumentLimits as import and save; a paste that is too large is refused with a message
- [ ] #2 Loading a project rejects or clamps out-of-range rotation and hue values, and the inspectors format any value without trapping
- [ ] #3 Making a selection from a mask or layer (⌘-click its thumbnail) uses the capped native tracer, so a noisy mask on a large layer can't hang the app
- [ ] #4 Tests cover each case
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. One admission check: DocumentLimits.Footprint counts layers, image pixels and mask pixels as saving does (each layer's own, shared or not), and DocumentLimits.admit refuses a side past maxSide, more than maxLayers layers, or either budget exceeded, with DocumentLimitError messages.
2. EditorSession.admitLayers runs it for addPixelLayer (Paste, Layer via Copy, new shapes and text) and for duplicateLayers (Duplicate, Option-drag, Paste of copied layers), before anything changes. External paste reads the bitmap's size from its header and admits it before decoding (ImageIO, turned upright); PDF/vector data still goes through NSImage, admitted at its point size before it is drawn.
3. On load, ProjectStore brings layer and mask rotations past one turn, and Hue/Saturation band handles outside 0-360, within one turn (same angle); the Transform inspector and Hue/Saturation spectrum label numbers through NumberLabel, which never traps.
4. MaskTracing (mask, layer and Select Subject outlines) thresholds into a byte mask and traces it with MagicWand.outline (wand_trace, 8M-edge cap), throwing a 'too detailed' error shown as a message instead of building an unbounded edge graph.
5. Tests for each case.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reimplemented from upstream's closed PRs #12, #10 and #17 (esquarenews), not ported: one admission helper over DocumentLimits instead of PR #12's literals (100 MP, 10,000), masks counted like saving counts them, the NSImage fallback kept for PDF/vector paste (PR #12 dropped it); angles bounded at load instead of only wrapped for display (PR #10); the native capped tracer instead of an edge cap on the Swift graph (PR #17).
Refusals use brushError, the alert Magic Wand and the other edits already use for their errors.
swift test --disable-keychain --filter 'DocumentAdmissionTests|AngleLoadTests|MaskSelectionTracingTests|SelectionTests|LayerMaskTests|SelectionClipboardTests|ProjectTests|ShapeToolTests|TypeToolTests|MagicWandTests|HueSaturationTests|TransformTests' -> 129 tests in 14 suites passed (the existing SelectionTests pin the traced outlines' exact edges, holes and transforms on the new tracer).
The 2048x2048 checkerboard layer and mask (about 8.4M edges) are refused with the message and leave selection and history untouched.
<!-- SECTION:NOTES:END -->
