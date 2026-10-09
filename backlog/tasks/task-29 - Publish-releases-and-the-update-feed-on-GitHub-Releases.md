---
id: TASK-29
title: Publish releases and the update feed on GitHub Releases
status: In Progress
assignee: []
created_date: '2026-10-07 21:06'
updated_date: '2026-10-09 15:10'
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
- [x] #2 appcast.xml starts from the previous release's feed, lists every release with download links to its GitHub Release assets, and is signed with the Sparkle key from the secrets
- [ ] #3 Info.plist's SUFeedURL points to a GitHub URL that always serves the newest feed, and an installed build follows it to the newest release
- [x] #4 docs/releasing.md and AGENTS.md describe the GitHub release flow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Since TASK-6, Info.plist's SUFeedURL is already https://github.com/itsjavi/lamina/releases/latest/download/appcast.xml (decision-3); what is left for AC #3 is publishing a feed there and checking an installed build follows it. The release steps moved from the README to docs/releasing.md (TASK-38).

2026-10-09: release.yml runs on macos-26 (the xcode-27 label matched no runner), drops the R2 step and secrets, and also takes vX.Y.Z-<pre-release> tags: those publish a GitHub pre-release without appcast.xml (GitHub's latest release is never a pre-release, so the feed and the website skip them). appcast.sh links each new item to releases/download/vX.Y.Z/ (derived from SUFeedURL), keeps every version (--maximum-versions 0) and refuses pre-releases; checked with a throwaway key that generate_appcast keeps earlier items and their URLs, and that the wrong-key guard still fails. bump-version.sh accepts X.Y.Z-beta.N with semver ordering. Website: Download buttons link to releases/latest and, with JavaScript, to the newest DMG and its version from GitHub's API (CORS allowed). The user set up the release environment (v* tags) and its six secrets, and a local make release came out Developer ID signed, notarized and stapled (spctl: Notarized Developer ID). Left: AC #1 and #3 need the first tag run (v2.0.0) and a second release to update to.
<!-- SECTION:NOTES:END -->
