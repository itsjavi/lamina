---
id: decision-3
title: 'Publish releases and the update feed on GitHub Releases, not R2'
date: '2026-10-07 21:06'
status: accepted
---
## Context

The release tooling came from the sibling apps, which publish zips, DMGs and Sparkle's appcast to an R2 bucket behind
downloads.itsjavi.com (scripts/release.sh, scripts/appcast.sh, .github/workflows/release.yml), and decision-2 named
`https://downloads.itsjavi.com/lamina/appcast.xml` as the feed. Lamina's repository (itsjavi/lamina) is public, so
GitHub Releases can host the binaries and the feed without a bucket or its credentials.

## Decision

- Releases (DMG, zip, SHA256SUMS) are published as GitHub Releases of itsjavi/lamina, built by the tag-driven workflow.
- Sparkle's feed lives on GitHub too, at a URL that always points to the newest feed, for example the `appcast.xml`
  asset of the latest release (`https://github.com/itsjavi/lamina/releases/latest/download/appcast.xml`, which Sparkle
  follows through GitHub's redirect); the feed lists every release, with download links to each release's assets.
- No R2 bucket and no R2 secrets.

## Consequences

- Supersedes decision-2's feed URL; the bundle id, name and project format in decision-2 stand.
- release.yml, appcast.sh, release.sh, Info.plist's SUFeedURL, the README and AGENTS.md change (TASK-29).
- `SUFeedURL` is baked into every build, so it must be final before the first release (TASK-1).
- If the latest release's feed is ever missing an older entry, installed copies can't see older versions; the appcast
  step starts from the previous release's feed so history is kept.

