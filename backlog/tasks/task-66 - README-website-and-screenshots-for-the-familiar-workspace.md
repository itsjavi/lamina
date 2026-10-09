---
id: TASK-66
title: 'README, website and screenshots for the familiar workspace'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 07:51'
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
- [x] #1 Every screenshot in web/assets shows the new workspace, and the social card is regenerated
- [x] #2 README and website copy name tools, menus and panels as the app now does
- [x] #3 Nothing published shows interface that no longer exists
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Captures (Dev build of this worktree, 1500 x 860 pt window per DESIGN.md, rulers on, grid off, launched with open -g -n -a, captured by pid with scripts/window-screenshot.swift --pid): screenshot.webp (dark, Golden Hour as it opens, Properties showing the Type Layer), camera-raw.webp (dark, Sky selected with lamina select-layer, Filter > Camera Raw Filter... chosen with Accessibility's press action, --panels), curves.webp (light, Warm grade selected, Curves in Properties), oil-painting.webp (dark, seascape as it opens). Each image checked by eye against the running app: toolbar with flyout corners, options bar, status bar, Properties | Adjustments over Layers, groups, fx rows.
Decisions: one light shot (curves) and the rest dark instead of light/dark pairs, so the pages show both appearances without doubling the assets (total webp ~426 KB, was ~429 KB). Curves is captured in Properties (adjustment layers are edited there) rather than the Image > Adjustments dialog. The website gets a new first feature row, 'A layout you already know', using screenshot.webp (until now only the README and social card used it), so the familiar layout is presented as a feature in decision-7's tone (what Lamina does, no comparisons beyond 'as in Photoshop, Affinity and similar editors'). Export copy is written for TASK-65's end state (File > Export > Quick Export as PNG, Export As... with a Format menu and preview); no export dialog is shown.
Scripts: window-screenshot.swift takes --pid (another agent's Dev copy can run at the same time); new scripts/menu-command.swift chooses a menu command through Accessibility (no mouse or key events); demo-project.swift says group; brand/README.md's procedure and shot table updated (window frame, appearance default, lamina select-layer, restoring defaults).
Docs: project-format.md and writing-lamina-projects.md say group for layer groups and name the shape tools; no other stale names (Smear, Magic (W), Export PNG..., Export JPEG..., Import Images..., Transform Layer, Fit Canvas, Actual Pixels, Edit Adjustment...) in docs/ or scripts/ outside DESIGN.md's history notes.
Checks: swiftc -typecheck on the three changed or new scripts; website rendered in headless Chrome in light and dark (images load, sizes match the new 2400x1376 and 1600x918 files); social card re-rendered and viewed. Dev app defaults restored (window frame, tool.grid, appearance key deleted). make test-ui not run (docs task).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Recaptured every web/assets screenshot from the Dev build in the familiar workspace (hero, Camera Raw and seascape in dark, Curves in Properties in light) and regenerated the social card. README and website now present the familiar layout as a feature and name tools, menus, panels and dialogs as the app does (groups, Eraser and Dodge/Burn tools, Filter > Liquify..., Properties and Adjustments panels, Layer Style dialog, Fill and Load Selection, light and dark, Quick Export as PNG and Export As...). Screenshot scripts pick a Dev copy by pid and choose menu commands through Accessibility; brand/README.md documents it; format docs say group. Verified by viewing each capture and the social card, headless Chrome renders of the site in light and dark, and swiftc -typecheck of the scripts.
<!-- SECTION:FINAL_SUMMARY:END -->
