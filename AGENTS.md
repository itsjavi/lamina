# Compositor — agent guide

macOS image editor for compositing and photo work (SwiftUI + AppKit, Swift 6.2 toolchain in Swift 5 language mode,
SwiftPM, no Xcode project), with C for pixel loops and Metal for the canvas and effects. A fork of
[robbietilton/Compositor](https://github.com/robbietilton/Compositor) with its own identity and update feed: upstream
changes are ported by hand, never merged. Distributed outside the App Store (Developer ID), App Sandboxed.

## Designing or editing a Compositor project

If you've been asked to make or change an image in a `.comp` project, you don't need the app's source code. Read
[docs/writing-comp-files.md](docs/writing-comp-files.md): it covers the file format, the rules that make a project
load, and how to write it safely while it's open, so the person can watch the canvas update as you work.

## Commands

| Task                     | Command                                                         |
| ------------------------ | --------------------------------------------------------------- |
| Unit tests               | `swift test` (or `make test`)                                   |
| Compile everything       | `swift build`                                                   |
| Dev app bundle           | `make dev` → `build/Compositor Dev.app`                         |
| Release app bundle       | `make app` → `build/Compositor.app`                             |
| Install to /Applications | `make install`                                                  |
| Release zip/DMG          | `make release` (ad-hoc unless `DEVELOPER_ID`/`NOTARY_PROFILE`)  |
| Update feed              | `make appcast` (Sparkle key: Keychain account `compositor`)     |
| Version bump + tag       | `make bump V=patch [PUSH=1]` (never tag unless the user asks)   |
| Brush benchmark          | `BRUSH_BENCHMARK=1 swift test --filter BrushPerformanceTests`   |

## Layout

| Path                           | Contents                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------ |
| `Sources/CPixels`              | C pixel loops (brushes, healing, levels, noise, lens, content fill, adjustments, dither), headers in `include/`, always built `-O3`. Swift files that call them `import CPixels` |
| `Sources/Compositor`           | The app (default MainActor isolation): `Document/` (editor session and tools), `IO/` (projects, PSD, import/export), `Rendering/` (canvas, Metal), `UI/` (panels, sheets, controls) |
| `Tests/CompositorTests`        | Swift Testing suites, `@testable import Compositor`                                         |
| `Tests/CompositorTestHost`     | Starts AppKit's event loop with a document window in the test process (see below)           |
| `Resources/`                   | `Info.plist`, `Compositor.entitlements` (sandbox), `PrivacyInfo.xcprivacy`, `AppIcon.icon` (Icon Composer; compiled by actool in `scripts/build-app.sh`) |
| `scripts/`                     | `build-app.sh` (assembles, compiles the icon, embeds Sparkle, signs), `release.sh`, `appcast.sh`, `bump-version.sh`, `acknowledgements.swift` (Credits.html) |
| `docs/`                        | The `.comp` format (`project-format.md`, `writing-comp-files.md`) and performance notes     |
| `.github/workflows/`           | `ci.yml` (tests), `release.yml` (tag-driven release)                                        |

## Builds and data

| Variant | Bundle id                    | Sandbox container (`~/Library/Containers/…`) | Who uses it                          |
| ------- | ---------------------------- | -------------------------------------------- | ------------------------------------ |
| Release | `com.itsjavi.compositor`     | `com.itsjavi.compositor`                     | The user. Agents never touch its data |
| Dev     | `com.itsjavi.compositor.dev` | `com.itsjavi.compositor.dev`                 | Development and agent verification   |

Only release builds have an updater (`SUFeedURL` + `SUPublicEDKey` from `Resources/SparklePublicKey.txt`); the Dev
build never updates itself, and Check for Updates… is disabled there. `build-app.sh` fills the variant's bundle id
into the entitlements (Sparkle's sandboxed installer services are reached by name). Projects are user documents
(`.comp` folders) wherever the person saves them; tool toggles live in `UserDefaults` (`ToolDefaults`).

## Dependencies

Only what the system frameworks can't do. Each SwiftPM package is pinned in `Package.resolved`, and
`scripts/acknowledgements.swift` puts its license in Credits.html (the build fails if it has none).

| Package                                          | Why                                                                          |
| ------------------------------------------------ | ---------------------------------------------------------------------------- |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Updates (release builds only), embedded as `Sparkle.framework`          |
| [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) | WebP export: ImageIO reads WebP but can't write it. Google's libwebp (BSD-3-Clause) as a SwiftPM package, built from source and linked statically: no binaries, no network, no other dependencies. Only `IO/WebPEncoder.swift` imports it |

## Conventions

- Match the surrounding code: its naming, its comment style and density.
- American spelling in code, comments and UI ("color", not "colour").
- The project file format is described in [docs/project-format.md](docs/project-format.md). A change to what's saved
  means a format version bump there and in `ProjectManifest.current`.
- Code that needs the C loops goes through `CPixels`; keep its functions plain C (no AppKit, no Objective-C).
- Tests run in `swift test`'s Swift Testing runner, not in the app. `CompositorTestHost` recreates what the app host
  gave them: `NSApplication.run()` (so alerts, sheets and clicks that stop a nested run loop don't end the process)
  and one visible document window (panels dock to it). `ToolDefaults` gives tests the compiled defaults because they
  never run in an `.app` bundle. A test window the app closes needs `isReleasedWhenClosed = false`.
- Some suites show real windows and activate the test process, so a test run can take focus.

## Verifying UI as an agent

Build with `make dev`, launch in the background with `open -g -n "build/Compositor Dev.app"`, and capture the window
with `screencapture -l <windowID> -o -x out.png` (window id from `CGWindowListCopyWindowInfo`, owner pid of the app).
Quit it with `osascript -e 'tell application id "com.itsjavi.compositor.dev" to quit'`. Canvas painting, drags,
sheets, menus and drag and drop still need a manual check.
