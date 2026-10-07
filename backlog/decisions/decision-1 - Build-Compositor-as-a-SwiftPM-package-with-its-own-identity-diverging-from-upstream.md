---
id: decision-1
title: >-
  Build Compositor as a SwiftPM package with its own identity, diverging from
  upstream
date: '2026-10-07 17:47'
status: accepted
---
## Context

Compositor is a fork of robbietilton/Compositor (MIT), which builds with an Xcode project, ships as
`com.wonderassembly.compositor` and updates from upstream's appcast with upstream's Sparkle key. The other apps here
(ProjectHub, LaunchDeck, NoteMD, Prompter) are SwiftPM packages with a Makefile, a build script that assembles and signs
the bundle, Release/Dev variants, an Icon Composer icon, and the same release, appcast and CI tooling. Builds of the
fork with upstream's feed and key would auto-update to upstream releases and replace the fork's changes.

## Decision

- Compositor is a SwiftPM package laid out like the sibling apps: `Sources/Compositor` (the app), `Sources/CPixels`
  (the C pixel loops that the Xcode project reached through a bridging header), `Tests/CompositorTests`, `Resources/`,
  `scripts/build-app.sh`, a Makefile and the shared release scripts. The Xcode project, its asset catalog and the
  XCUITest template target are removed.
- Its own identity: bundle id `com.itsjavi.compositor` (`.dev` for the Dev build), feed
  `https://downloads.itsjavi.com/compositor/appcast.xml`, and its own Sparkle EdDSA key (Keychain account
  `compositor`). The `.comp` type identifiers (`com.compositor.*`) are the file format's and stay unchanged.
- The Xcode project's build settings are kept as they were: Swift 5 language mode with approachable concurrency and
  member import visibility, MainActor default isolation in the app, C at `-O3` in every configuration, and the App
  Sandbox with user-selected file access, network client and Sparkle's installer services.
- The icon is an Icon Composer `.icon` whose one layer is upstream's gradient art.
- Structure first: no UI-free Core library yet; the tests import the app target.

## Consequences

- Upstream changes can no longer be merged; they are ported by hand.
- Installs of the fork have their own preferences and sandbox container, apart from upstream's app.
- `swift test` runs the suites outside an app. `Tests/CompositorTestHost` starts AppKit's event loop with a document
  window, as the app host did, and `ToolDefaults` recognizes tests by the missing `.app` bundle.
- No SwiftUI previews or asset catalogs; the codebase had no previews and only the icon in its catalog.
- Follow-ups: the Sparkle key and first release, a Core library, and Swift 6 language mode.

