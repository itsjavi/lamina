---
id: TASK-6
title: Rename the app to Lamina
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
updated_date: '2026-10-08 18:43'
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
- [ ] #1 Menus, the About panel, window titles and alerts say Lamina, and the builds are build/Lamina.app and build/Lamina Dev.app
- [ ] #2 Info.plist, the build, release and appcast scripts, CI and the Makefile use the bundle ids com.itsjavi.lamina and com.itsjavi.lamina.dev and the Sparkle Keychain account lamina; the feed URL follows decision-3
- [ ] #3 The app target, its folder, tests and test host are LaminaApp, LaminaAppTests and LaminaTestHost; pasteboard and drag types use com.itsjavi.lamina.*
- [ ] #4 git grep -i compositor finds only credits to upstream Compositor (MIT), the .comp importer and its docs, and backlog history
- [ ] #5 swift test passes, and make dev and make app build apps that launch
<!-- AC:END -->
