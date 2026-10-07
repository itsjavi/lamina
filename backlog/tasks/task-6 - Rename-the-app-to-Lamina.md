---
id: TASK-6
title: Rename the app to Lamina
status: To Do
assignee: []
created_date: '2026-10-07 20:35'
updated_date: '2026-10-07 21:06'
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
decision-2 renames the fork to Lamina before its first release, so it doesn't ship under upstream Compositor's name and so users, search and support can tell the two apps apart. Everything user-facing and every identity string moves; the Swift target and module names may stay.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Menus, the About panel, window titles and alerts say Lamina, and the builds are build/Lamina.app and build/Lamina Dev.app
- [ ] #2 README, AGENTS.md and docs use the new name and keep crediting Robbie Tilton's Compositor under its MIT license
- [ ] #3 swift test passes, and make dev and make app build apps that launch
- [ ] #4 Info.plist, the build, release and appcast scripts, CI and the Makefile use the bundle ids com.itsjavi.lamina and com.itsjavi.lamina.dev and the Sparkle Keychain account lamina; the feed URL follows decision-3
<!-- AC:END -->
