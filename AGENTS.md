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
| `lamina` (command line)  | `swift build --product lamina`; shipped as `Contents/Helpers/lamina` |
| `lamina` and command tests | `swift test --filter 'LaminaTests\|AutomationTests'`          |

## Layout

| Path                           | Contents                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------ |
| `Sources/CPixels`              | C pixel loops (brushes, healing, levels, noise, lens, content fill, adjustments, dither), headers in `include/`, always built `-O3`. Swift files that call them `import CPixels` |
| `Sources/Compositor`           | The app (default MainActor isolation): `Automation/` (`lamina`'s commands and their Apple Event handler), `Document/` (editor session and tools), `IO/` (projects, PSD, import/export), `Rendering/` (canvas, Metal), `UI/` (panels, sheets, controls) |
| `Sources/LaminaAutomation`     | The command catalog shared by the app and `lamina` (names, parameters, results, filter and adjustment settings), JSON values, the Apple Event codes and the bundle ids (`AppIdentity`). Foundation only, Swift 6 mode |
| `Sources/LaminaCLI`, `Sources/lamina` | `lamina`: arguments and help built from the catalog, text/JSON output, the Apple Event client and file writing |
| `Tests/CompositorTests`        | Swift Testing suites, `@testable import Compositor`                                         |
| `Tests/LaminaTests`            | The catalog and `lamina`, without the app (fast, no windows)                                |
| `Tests/CompositorTestHost`     | Starts AppKit's event loop with a document window in the test process (see below)           |
| `Resources/`                   | `Info.plist`, `Compositor.entitlements` (sandbox), `lamina.entitlements`, `PrivacyInfo.xcprivacy`, `AppIcon.icon` (Icon Composer; compiled by actool in `scripts/build-app.sh`) |
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

## Driving the running app with `lamina`

`lamina` controls a running copy of the app over Apple Events (decision-4): `lamina --help` lists the commands,
`lamina help <command>` their options; `--json` prints JSON. Put it on PATH with a symlink to the bundle's copy, e.g.
`ln -s "$PWD/build/Compositor Dev.app/Contents/Helpers/lamina" ~/.local/bin/lamina-dev`. A copy inside an app bundle
talks to that app; otherwise pick one with `--dev`, `--app <bundle id>`, `LAMINA_APP=dev|release|<id>`, or `--pid` when
several copies run (agents launching their own Dev build with `open -n` should always pass `--pid`). The first command
from a new calling app shows macOS's Automation prompt to the person.

- Commands are defined once in `Sources/LaminaAutomation/CommandCatalog.swift` (filter and adjustment settings in
  `EffectCatalog.swift`); the app implements each in `Sources/Compositor/Automation/` through the same `EditorSession`
  and `ProjectWorkspace` methods the menus call. Adding a command: its `CommandSpec` in the catalog, its handler in
  `AutomationDispatcher.handlers`, a test in `AutomationTests` (which also checks every result against the catalog's
  schema). `lamina`'s flags and help follow from the catalog.
- Edits are one undo step each and are refused (`busy`) while the person is mid-edit (`busyReason`); ids are short
  unique prefixes (`ShortID`); edits return what they changed and accept `expect_revision`.
- The sandboxed app never sees file paths: it returns file bytes (base64) and `lamina` writes them (`CommandClient`).
- Entitlements: the app's are unchanged (receiving Apple Events needs none). `lamina` is signed with
  `Resources/lamina.entitlements` (`com.apple.security.automation.apple-events`), which the hardened runtime requires to
  send Apple Events.

## Verifying UI as an agent

Build with `make dev`, launch in the background with `open -g -n "build/Compositor Dev.app"`, and capture the window
with `screencapture -l <windowID> -o -x out.png` (window id from `CGWindowListCopyWindowInfo`, owner pid of the app).
Quit it with `osascript -e 'tell application id "com.itsjavi.compositor.dev" to quit'`. `lamina --pid <pid>` (above) can
put it in the state to capture (select a layer, apply a filter or adjustment) and `render-preview` saves the canvas as
a PNG. Canvas painting, drags, sheets, menus and drag and drop still need a manual check.
