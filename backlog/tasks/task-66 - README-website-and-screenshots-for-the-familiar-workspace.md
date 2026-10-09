---
id: TASK-66
title: 'README, website and screenshots for the familiar workspace'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 07:38'
labels: []
milestone: m-5
dependencies:
  - TASK-51
  - TASK-52
  - TASK-53
  - TASK-54
  - TASK-55
  - TASK-56
  - TASK-57
  - TASK-58
  - TASK-59
  - TASK-60
  - TASK-61
  - TASK-62
  - TASK-63
  - TASK-64
  - TASK-65
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: medium
type: docs
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
brand/README.md: a substantial UI change means recapturing screenshots and updating copy that names the interface. Doing it once, after the rest of m-5, avoids recapturing after every task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every screenshot in web/assets shows the new workspace, and the social card is regenerated
- [ ] #2 README and website copy name tools, menus and panels as the app now does
- [ ] #3 Nothing published shows interface that no longer exists
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Capture from this worktree's Dev build (make dev) with the demo projects: screenshot.webp (Golden Hour as it opens, title selected, Properties showing the Type Layer; dark), curves.webp (Warm grade selected with lamina select-layer, so Properties shows Curves; light appearance, to show both), camera-raw.webp (Sky selected, Filter > Camera Raw Filter... opened with AXPress; dark), oil-painting.webp (seascape as it opens; dark). One asset per placement, no light/dark pairs, to keep the budget.
2. Update scripts if needed (window-screenshot, demo project) and brand/README.md's screenshot table and gotchas (the app now has light and dark; Properties replaces the floating Curves panel).
3. README.md: pitch mentions the familiar layout; features use the app's names (groups, Eraser/Dodge/Burn tools, Filter > Liquify..., Properties and Adjustments panels, Layer Style dialog, Export > Quick Export as PNG and Export As..., light and dark, Settings); alt text and captions.
4. web/index.html: same copy fixes, familiar layout and light/dark as features, alt texts and image sizes.
5. Regenerate the social card from scripts/og-image.html.
6. Grep docs/ and scripts/ for stale interface names (folder, Smear, Magic (W), Export PNG..., Export JPEG..., Import Images..., Transform Layer, Fit Canvas, Actual Pixels, Edit Adjustment...) and fix the ones describing the current app.
7. Check each image against the current app, check the site in headless Chrome (light and dark), commit each slice.
<!-- SECTION:PLAN:END -->
