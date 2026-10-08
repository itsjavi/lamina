---
id: TASK-29
title: Publish releases and the update feed on GitHub Releases
status: To Do
assignee: []
created_date: '2026-10-07 21:06'
updated_date: '2026-10-08 21:46'
labels:
  - release
milestone: m-0
dependencies: []
references:
  - >-
    backlog/decisions/decision-3 -
    Publish-releases-and-the-update-feed-on-GitHub-Releases-not-R2.md
  - .github/workflows/release.yml
  - scripts/appcast.sh
  - docs/releasing.md
priority: high
type: chore
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-3: the repository is public, so releases go to GitHub Releases instead of the R2 bucket the tooling inherited from the sibling apps. The workflow, the appcast script and the feed URL change; the R2 steps and secrets go.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pushing a vX.Y.Z tag builds, signs and notarizes when the secrets exist, and publishes a GitHub Release with the DMG, the zip, SHA256SUMS and appcast.xml; no R2 step or secret remains
- [ ] #2 appcast.xml starts from the previous release's feed, lists every release with download links to its GitHub Release assets, and is signed with the Sparkle key from the secrets
- [ ] #3 Info.plist's SUFeedURL points to a GitHub URL that always serves the newest feed, and an installed build follows it to the newest release
- [ ] #4 docs/releasing.md and AGENTS.md describe the GitHub release flow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Since TASK-6, Info.plist's SUFeedURL is already https://github.com/itsjavi/lamina/releases/latest/download/appcast.xml (decision-3); what is left for AC #3 is publishing a feed there and checking an installed build follows it. The release steps moved from the README to docs/releasing.md (TASK-38).
<!-- SECTION:NOTES:END -->
