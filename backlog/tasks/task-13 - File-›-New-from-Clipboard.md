---
id: TASK-13
title: File › New from Clipboard
status: Done
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-07 21:43'
labels:
  - upstream
milestone: m-1
dependencies: []
references:
  - 'https://github.com/robbietilton/Compositor/issues/159'
  - 'https://github.com/robbietilton/Compositor/pull/201'
  - 'https://github.com/robbietilton/Compositor/pull/176'
  - >-
    backlog/docs/research/doc-1 -
    Upstream-issues-and-PRs-worth-bringing-into-the-fork.md
priority: medium
type: feature
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Starting a document from a screenshot or a copied image takes New Canvas, Return and then Paste today. Decided in doc-1: add File › New from Clipboard (upstream issue #159, the most wanted feature request; PR #201, plus PR #176's handling of files copied in Finder).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 File › New from Clipboard opens a new document the size of the copied image, with it as the only layer, in one step; copied images and image files copied in Finder both work
- [x] #2 The command is disabled when the clipboard holds no image, and its shortcut doesn't take Photoshop's Paste in Place (⇧⌘V)
- [x] #3 Tests use a private pasteboard, never the user's clipboard
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Port PR #201: ProjectWorkspace.newFromClipboard opens a new tab the size of the copied image with it as the only layer (one undo step); pixels copied in an open project come first.
2. From PR #176, only the handling of image files copied in Finder: their URLs win over the icon Finder copies as image data; image files open as a Dock drop does (a project each), a non-image file doesn't count.
3. Shortcut ⌥⌘N instead of upstream's ⇧⌘V (Photoshop's Paste in Place); entry in Keyboard Shortcuts.
4. Disabled state: an observable clipboardOffersImage refreshed on activation and each second while active, judged only from pasteboard types and NSPasteboardItem.detectedMetadata content types (no content reads, so no macOS clipboard-access prompt).
5. Tests in NewFromClipboardTests with NSPasteboard.withUniqueName(), never the general pasteboard.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ported PR #201's ProjectWorkspace.newFromClipboard and, from PR #176, only the handling of image files copied in Finder (their URLs win over the icon Finder copies as image data; image files open as a Dock drop does, a project each; a non-image file doesn't count). PR #176's Cmd-V-on-an-empty-project behavior was not taken. Shortcut is ⌥⌘N, not upstream's ⇧⌘V (Photoshop's Paste in Place).

Disabled state: ProjectWorkspace.clipboardOffersImage, refreshed when the app becomes active and every second while it is active (only when NSPasteboard.changeCount changed). It looks only at pasteboard types and NSPasteboardItem.detectedMetadata content types, never contents, so it can't trigger macOS's clipboard-access prompt. The command itself reads the clipboard when chosen.

Verification: swift test --disable-keychain --filter NewFromClipboardTests (6 tests passed), all on NSPasteboard.withUniqueName() pasteboards. The existing SelectionClipboardTests (which write the general pasteboard) were not run, to leave the user's clipboard alone; Paste only moved its image reading into EditorSession.pasteboardImage unchanged.

No screenshot: reaching it needs an image on the real clipboard. Manual checks: menu item greys out and re-enables as the clipboard changes; ⌥⌘N with a screenshot copied; an image file copied in Finder opens in the signed, sandboxed build (tests ran unsandboxed; the pasteboard does hand out sandbox extensions for file URLs); whether macOS shows its paste-permission alert the first time.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
File › New from Clipboard (⌥⌘N) opens the copied image as a new project of its size with it as the only layer, in one undo step; pixels copied in an open project come first and image files copied in Finder open as a Dock drop does. Disabled without an image on the clipboard, judged from types and file content types only. Ports upstream #201 plus #176's Finder-file handling. Verified with NewFromClipboardTests on private pasteboards; the live menu state and sandboxed Finder files are manual checks.
<!-- SECTION:FINAL_SUMMARY:END -->
