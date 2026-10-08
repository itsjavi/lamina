---
id: TASK-6
title: Rename the app to Lamina
status: Done
assignee:
  - '@claude'
created_date: '2026-10-07 20:35'
updated_date: '2026-10-08 18:58'
labels:
  - identity
milestone: m-0
dependencies: []
references:
  - >-
    backlog/decisions/decision-2 -
    Rename-the-fork-to-Lamina-with-its-own-project-format-.lamina.md
priority: high
type: chore
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-2 renames the fork to Lamina before its first release, so it doesn't ship under upstream Compositor's name and so users, search and support can tell the two apps apart. Its 2026-10-08 amendment widens the rename to everything, not just what users see: Swift targets, folders, the test host, pasteboard types and docs. The app target becomes `LaminaApp` (an executable `Lamina` would clash with the `lamina` command-line tool on a case-insensitive disk). Settings from the Compositor builds don't carry over (new sandbox container).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Menus, the About panel, window titles and alerts say Lamina, and the builds are build/Lamina.app and build/Lamina Dev.app
- [x] #2 Info.plist, the build, release and appcast scripts, CI and the Makefile use the bundle ids com.itsjavi.lamina and com.itsjavi.lamina.dev and the Sparkle Keychain account lamina; the feed URL follows decision-3
- [x] #3 The app target, its folder, tests and test host are LaminaApp, LaminaAppTests and LaminaTestHost; pasteboard and drag types use com.itsjavi.lamina.*
- [x] #4 git grep -i compositor finds only credits to upstream Compositor (MIT), the .comp importer and its docs, and backlog history
- [x] #5 swift test passes, and make dev and make app build apps that launch
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. git mv the app, test and test-host folders and files to LaminaApp / LaminaAppTests / LaminaTestHost; entitlements to LaminaApp.entitlements (lamina.entitlements is the CLI's: case-insensitive clash).
2. Scripted replacement over Sources, Tests, scripts, Makefile and CI: bundle ids, pasteboard types, type names (CompositorApp → LaminaMain, since Lamina is already the CLI's entry type), imports, user-facing strings; lowercase accounts and paths in scripts.
3. By hand: Package.swift, build-app.sh product and binary names, Info.plist identity and feed URL (decision-3), README, AGENTS.md, docs, LICENSE and copyright.
4. Verify: build, full swift test, make dev and make app, launch both hidden.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- App target LaminaApp (module), entry point `LaminaMain`, tests LaminaAppTests (the old CompositorTests suite is now AppTests), host LaminaTestHost, app entitlements Resources/LaminaApp.entitlements. Bundle executable is still Contents/MacOS/Lamina.
- Pasteboard and drag types are com.itsjavi.lamina.*; the CPU-canvas debug default is LaminaCPUCanvas.
- Info.plist: Lamina names, com.itsjavi.lamina, SUFeedURL https://github.com/itsjavi/lamina/releases/latest/download/appcast.xml (decision-3; TASK-29 still has to publish it), copyright © 2026 Javi Aguilar. LICENSE keeps Wonder Assembly's notice under the new one.
- README install section: no release yet, build from source. R2 steps in release.yml/appcast.sh were only renamed; TASK-29 replaces them.
- The format identifiers were TASK-7's.

Validation:
- Full swift test after the rename: 709 tests in 100 suites passed (116 s).
- make dev → build/Lamina Dev.app (com.itsjavi.lamina.dev, new sandbox container) and make app → build/Lamina.app (com.itsjavi.lamina, 25 MB, Sparkle services com.itsjavi.lamina-spks/-spki); both codesign --verify clean and launch (hidden, -g -j).
- git grep -i compositor outside backlog: only the upstream credit (README, AGENTS.md, LICENSE, docs/project-format.md) and the .comp importer.
- Menu titles come from code and CFBundleName (Lamina); not checked visually: the user needed the screen. Launching the release build created an empty com.itsjavi.lamina container.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Renamed everything to Lamina: app target LaminaApp (bundle Lamina.app / Lamina Dev.app), tests and test host, bundle ids com.itsjavi.lamina(.dev), Sparkle account lamina, pasteboard types, the GitHub feed URL, scripts, CI, README, AGENTS.md and docs; only the upstream credit and the .comp importer keep the old name. Verified by the full suite (709 passing), both bundles building, signing and launching, and a repo-wide grep.
<!-- SECTION:FINAL_SUMMARY:END -->
