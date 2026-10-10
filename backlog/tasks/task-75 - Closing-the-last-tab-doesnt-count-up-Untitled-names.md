---
id: TASK-75
title: Closing the last tab doesn't count up Untitled names
status: Done
assignee: []
created_date: '2026-10-09 15:51'
updated_date: '2026-10-10 03:45'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/231'
  - >-
    backlog/docs/research/doc-4 -
    Upstream-review-2026-10-09-Compositor-1.4.5-to-1.4.8.md
priority: low
type: bug
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Closing the only tab (its × or ⌘W) when it holds New Document's welcome replaces it with a new empty tab named Untitled 2, then Untitled 3 and so on, because ProjectWorkspace.removeTab adds a tab with addTab(reuseEmpty: false) and nextNumber never resets (upstream issue #231, still open there, reported against the same code). Photoshop dims Close when no document is open.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 With no other tabs left, the empty tab is named Untitled and numbering starts again
- [x] #2 A sole empty tab shows no close button and File › Close is dimmed for it; closing a document's last tab still leaves the welcome tab
- [x] #3 A test covers closing tabs down to none and the names that follow, and DESIGN.md's tab rules say it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ProjectWorkspace: when the last tab closes (`removeTab`, `closeWindow`), put back an empty tab named Untitled and reset the numbering (`startOver`); `isOnlyWelcome` says a sole empty tab is the welcome.
2. The tab strip leaves out the welcome's close button (and its width in the pill); File › Close is dimmed for it, and `close(_:)` refuses it too.
3. ProjectWorkspaceTests: closing every tab, twice; DESIGN.md's tab rules and File menu.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Closing the last tab (its ×, ⌘W, or closing the window) now leaves an empty tab named Untitled with New Document as its welcome, and the next new tab is Untitled 2 again (`ProjectWorkspace.startOver`, used by `removeTab` and `closeWindow`, which used to add "Untitled N" with `addTab(reuseEmpty: false)`). `ProjectWorkspace.isOnlyWelcome` (one tab, no document) hides that tab's close button (the pill drops the button's width and keeps 11 pt either side), dims File › Close, and makes `close(_:)` refuse, so ⌘W does nothing there. An empty tab beside others still closes, and a document's last tab still leaves the welcome.

Tests: `ProjectWorkspaceTests.closingEveryTabStartsOverAtUntitled` (the welcome can't be closed; two rounds of creating Untitled 2 and 3 and closing every tab, each ending at Untitled with Untitled 2 next). ProjectWorkspaceTests, NewFromClipboardTests and TitleBarDragTests pass. File › Close's dimmed state follows the tested `isOnlyWelcome` through its `.disabled`; the menu itself was not opened in a running app (menus need a manual check).

DESIGN.md: a Workspace layout rule for tab names, closing the last tab and the welcome's missing close button; File › Close in Menus. No README or website change: a small fix to existing behavior.

Before and after: the tab strip after closing the welcome tab once, rendered offscreen from `ProjectTabStrip` in light appearance. Before, it came back as Untitled 2 with a close button; after, it stays Untitled with none.
![Before: Untitled 2 with a close button](../assets/task-75/before-tab-strip-after-closing-welcome.png)
![After: Untitled, no close button](../assets/task-75/after-tab-strip-after-closing-welcome.png)
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Closing the last tab leaves the welcome as Untitled with numbering starting again; the welcome on its own has no close button and File › Close is dimmed for it (`ProjectWorkspace.isOnlyWelcome`). Verified by ProjectWorkspaceTests.closingEveryTabStartsOverAtUntitled and before/after offscreen renders of the tab strip; DESIGN.md's tab rules and File menu updated.
<!-- SECTION:FINAL_SUMMARY:END -->
