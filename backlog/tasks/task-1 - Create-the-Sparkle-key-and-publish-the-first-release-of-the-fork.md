---
id: TASK-1
title: Create the Sparkle key and publish Lamina's first release
status: Done
assignee: []
created_date: '2026-10-07 17:48'
updated_date: '2026-10-11 04:56'
labels: []
milestone: m-0
dependencies:
  - TASK-6
  - TASK-7
  - TASK-29
references:
  - >-
    backlog/decisions/decision-1 -
    Build-Compositor-as-a-SwiftPM-package-with-its-own-identity-diverging-from-upstream.md
  - >-
    backlog/decisions/decision-2 -
    Rename-the-fork-to-Lamina-with-its-own-project-format-.lamina.md
  - README.md
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The fork has its own update feed (decision-1, renamed to Lamina in decision-2, hosted on GitHub Releases per decision-3), but no Sparkle EdDSA key yet: release builds warn that they can't update themselves, and nothing has been published. The first release comes after the rename, the .lam format and the GitHub release flow, so no build ships under the old name, format or feed. Creating the key writes to the login Keychain, so the user does it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A Sparkle EdDSA key exists in the login Keychain under the account lamina, with a backup kept outside the repo
- [x] #2 Resources/SparklePublicKey.txt holds the matching public key, and make app builds without the 'can't update itself' warning
- [x] #3 A Developer ID signed and notarized release is published as a GitHub Release with its appcast (decision-3)
- [x] #4 An installed release finds a newer test release through Check for Updates… and installs it from inside the App Sandbox
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-11: the Sparkle key is in the login Keychain (account lamina, service https://sparkle-project.org) and the user keeps a backup outside the repo. v2.0.1 and v2.0.2 shipped Developer ID signed, notarized and stapled as GitHub Releases with their appcast, and the user confirmed an installed release found and installed the newer one through Check for Updates…
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Lamina's first releases are out: v2.0.1 and v2.0.2 on GitHub Releases, Developer ID signed and notarized, with a signed Sparkle feed; installed builds update themselves from inside the App Sandbox.
<!-- SECTION:FINAL_SUMMARY:END -->
