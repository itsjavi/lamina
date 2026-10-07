---
id: TASK-1
title: Create the Sparkle key and publish the first release of the fork
status: To Do
assignee: []
created_date: '2026-10-07 17:48'
labels: []
dependencies: []
references:
  - >-
    backlog/decisions/decision-1 -
    Build-Compositor-as-a-SwiftPM-package-with-its-own-identity-diverging-from-upstream.md
  - README.md
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The fork has its own update feed (decision-1), but no Sparkle EdDSA key yet: release builds warn that they can't update themselves, and no build has been published to downloads.itsjavi.com/compositor. Creating the key writes to the login Keychain, so the user does it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A Sparkle EdDSA key exists in the login Keychain under the account compositor, with a backup kept outside the repo
- [ ] #2 Resources/SparklePublicKey.txt holds the matching public key, and make app builds without the 'can't update itself' warning
- [ ] #3 A Developer ID signed and notarized release is published with its appcast under downloads.itsjavi.com/compositor
- [ ] #4 An installed release finds a newer test release through Check for Updates… and installs it from inside the App Sandbox
<!-- AC:END -->
