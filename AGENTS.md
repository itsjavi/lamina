# Lamina — agent guide

macOS image editor for compositing and photo work (SwiftUI + AppKit, Swift 6.2 toolchain in Swift 5 language mode,
SwiftPM, no Xcode project), with C for pixel loops and Metal for the canvas and effects. A fork of
[robbietilton/Compositor](https://github.com/robbietilton/Compositor) with its own identity and update feed: upstream
changes are ported by hand, never merged; reviewing what upstream did since the last review follows
[.claude/skills/upstream-review/SKILL.md](.claude/skills/upstream-review/SKILL.md). Distributed outside the App Store
(Developer ID), App Sandboxed.

## Designing or editing a Lamina project

If you've been asked to make or change an image in a `.lam` project, you don't need the app's source code. Read
[docs/writing-lamina-projects.md](docs/writing-lamina-projects.md): it covers the file format, the rules that make a project
load, and how to write it safely while it's open, so the person can watch the canvas update as you work.

## The interface and its spec

[docs/DESIGN.md](docs/DESIGN.md) is the maintained spec for everything people see (decision-9): a familiar layout and
the names people know from Photoshop, Affinity and similar editors, drawn with native controls, in light and dark.

- Read it before changing the interface, and update it in the same commit as any change to a tool, menu item, panel,
  dialog, shortcut, color or size. Before finishing such a task, check that the spec matches what shipped.
- New features go where familiar editors put them, under the names people already know; record the placement in the
  spec.
- A planned feature with an open Backlog task shows its control as an in-progress placeholder (the spec lists them).
  Creating such a task adds its placeholder row; shipping or dropping the task removes it.

## Commands

| Task                     | Command                                                         |
| ------------------------ | --------------------------------------------------------------- |
| Unit tests               | `swift test` (or `make test`): leaves the person's focus alone  |
| All tests, with windows  | `make test-ui` (`LAMINA_UI_TESTS=1`; CI runs these)             |
| Compile everything       | `swift build`                                                   |
| Dev app bundle           | `make dev` → `build/Lamina Dev.app`                         |
| Release app bundle       | `make app` → `build/Lamina.app`                             |
| Install to /Applications | `make install`                                                  |
| Notarized build, install | `make build-notarized` → `build/release`; `make install-notarized` also installs it (Developer ID from the Keychain, notarytool profile `lamina`) |
| Release zip/DMG          | `make release` (ad-hoc unless `DEVELOPER_ID`/`NOTARY_PROFILE`)  |
| Update feed              | `make appcast` (Sparkle key: Keychain account `lamina`)     |
| Version bump + tag       | `make bump V=patch\|X.Y.Z-beta.N [PUSH=1]` (never tag unless the user asks) |
| Publish a release        | A pushed `vX.Y.Z` tag: `release.yml` publishes a GitHub Release with the DMG, zip, `SHA256SUMS` and the update feed ([docs/releasing.md](docs/releasing.md)) |
| Brush benchmark          | `BRUSH_BENCHMARK=1 swift test --filter BrushPerformanceTests`   |
| Size, launch, memory     | `make metrics` (records and compares, `brand/metrics.json`); `make metrics-web` puts them on the website |
| `lamina` (command line)  | `swift build --product lamina`; shipped as `Contents/Helpers/lamina` |
| `lamina` and command tests | `swift test --filter 'LaminaTests\|AutomationTests'`          |
| Format and PSD tests     | `swift test --filter LaminaCoreTests` (no app, no windows)      |

## Layout

| Path                           | Contents                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------ |
| `Sources/CPixels`              | C pixel loops (brushes, healing, levels, noise, lens, content fill, adjustments, dither), headers in `include/`, always built `-O3`. Swift files that call them `import CPixels` |
| `Sources/LaminaApp`           | The app (default MainActor isolation): `Automation/` (`lamina`'s commands and their Apple Event handler), `Document/` (editor session and tools), `IO/` (opening and saving projects and importing PSDs through LaminaCore, import/export), `Rendering/` (canvas, Metal), `UI/` (panels, sheets, controls) |
| `Sources/LaminaCore`           | The project format and PSD parsing, with no AppKit or SwiftUI (Foundation, CoreGraphics, ImageIO, UniformTypeIdentifiers), nonisolated: `Model/` and `Adjustments/` (the manifest's value types and their validation), `Project/` (`ProjectManifest`, `ProjectLayerRecord`, `ProjectPackage`: reading, writing and validating `.lam` packages, importing `.comp`), `PSD/` (reader, channel coder, type layers). The app sees it through `package` access; drawing, filters and effects stay in the app as extensions of its types |
| `Sources/LaminaAutomation`     | The command catalog shared by the app and `lamina` (names, parameters, results, filter and adjustment settings), JSON values, the Apple Event codes and the bundle ids (`AppIdentity`). Foundation only, Swift 6 mode |
| `Sources/LaminaCLI`, `Sources/lamina` | `lamina`: arguments and help built from the catalog, text/JSON output, the Apple Event client, file writing and the MCP server (`lamina mcp`) |
| `Tests/LaminaAppTests`        | Swift Testing suites, `@testable import LaminaApp`                                         |
| `Tests/LaminaCoreTests`        | The format and PSD parsing against LaminaCore alone: no AppKit, no test host, off the main actor |
| `Tests/PSDFixtures`            | Writes the small Photoshop files both test targets read                                     |
| `Tests/LaminaTests`            | The catalog, `lamina` and its MCP server, without the app (fast, no windows)                |
| `Tests/LaminaTestHost`     | Starts AppKit's event loop with a document window in the test process (see below)           |
| `Resources/`                   | `Info.plist`, `LaminaApp.entitlements` (sandbox), `lamina.entitlements`, `PrivacyInfo.xcprivacy`, `AppIcon.icon` (Icon Composer; compiled by actool in `scripts/build-app.sh`) |
| `scripts/`                     | `build-app.sh` (assembles, compiles the icon, embeds Sparkle, signs), `release.sh`, `appcast.sh`, `bump-version.sh`, `acknowledgements.swift` (Credits.html), `app-icon.swift` (draws the icon's layers), `demo-project.swift` and `window-screenshot.swift` (README and website screenshots), `og-image.html` (social card), `metrics.swift` (`make metrics`) |
| `docs/`                        | The interface spec (`DESIGN.md`) and its approved mockup (`references/redesign_v2.html`), the `.lam` format (`project-format.md`, `writing-lamina-projects.md`), releasing (`releasing.md`) and performance notes |
| `backlog/`                     | Planning with [Backlog.md](https://github.com/MrLesk/Backlog.md): tasks, milestones, decisions, drafts. Change records with the `backlog` CLI (`backlog task list --plain`, `backlog instructions`) |
| `web/`, `brand/`               | The website (https://itsjavi.com/lamina/) and its assets, shared with the README; `brand/README.md` says what to update when a feature ships or the UI changes, and how screenshots are taken |
| `.github/workflows/`           | `ci.yml` (tests), `release.yml` (tag-driven release), `pages.yml` (deploys `web/`)          |

## Builds and data

| Variant | Bundle id                    | Sandbox container (`~/Library/Containers/…`) | Who uses it                          |
| ------- | ---------------------------- | -------------------------------------------- | ------------------------------------ |
| Release | `com.itsjavi.lamina`     | `com.itsjavi.lamina`                     | The user. Agents never touch its data |
| Dev     | `com.itsjavi.lamina.dev` | `com.itsjavi.lamina.dev`                 | Development and agent verification   |

Only release builds have an updater (`SUFeedURL` + `SUPublicEDKey` from `Resources/SparklePublicKey.txt`); the Dev
build never updates itself, and Check for Updates… is disabled there. `build-app.sh` fills the variant's bundle id
into the entitlements (Sparkle's sandboxed installer services are reached by name). Projects are user documents
(`.lam` packages) wherever the person saves them; tool toggles live in `UserDefaults` (`ToolDefaults`).

## Dependencies

Only what the system frameworks can't do. Each SwiftPM package is pinned in `Package.resolved`, and
`scripts/acknowledgements.swift` puts its license in Credits.html (the build fails if it has none).

| Package                                          | Why                                                                          |
| ------------------------------------------------ | ---------------------------------------------------------------------------- |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Updates (release builds only), embedded as `Sparkle.framework`          |
| [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) | WebP export: ImageIO reads WebP but can't write it. Google's libwebp (BSD-3-Clause) as a SwiftPM package, built from source and linked statically: no binaries, no network, no other dependencies. Only `IO/WebPEncoder.swift` imports it |

## Conventions

- Commit straight to `main` and push; no pull requests or feature branches while the project has no outside
  contributors.
- Match the surrounding code: its naming, its comment style and density.
- A user-facing feature or a substantial UI change updates the README, website and screenshots in the same task
  ([brand/README.md](brand/README.md)), or says in the task notes why it needs none.
- American spelling in code, comments and UI ("color", not "colour").
- The project file format is described in [docs/project-format.md](docs/project-format.md) and implemented in
  LaminaCore. A change to what's saved means a format version bump there and in `ProjectManifest.current`.
- LaminaCore stays free of AppKit, SwiftUI and Core Image. Behavior that needs them (drawing text, filters, effects)
  goes in the app as a `nonisolated extension` of the core type, nonisolated like the type's own members (an
  extension in the app otherwise takes its default MainActor isolation). App files that use core types
  `import LaminaCore` (MemberImportVisibility), and construct them through explicit `package init`s: synthesized
  memberwise initializers are internal.
- Code that needs the C loops goes through `CPixels`; keep its functions plain C (no AppKit, no Objective-C).
- Tests run in `swift test`'s Swift Testing runner, not in the app. `LaminaTestHost` recreates what the app host
  gave them: `NSApplication.run()` (so alerts, sheets and clicks that stop a nested run loop don't end the process)
  and one visible document window (panels dock to it). `ToolDefaults` gives tests the compiled defaults because they
  never run in an `.app` bundle. A test window the app closes needs `isReleasedWhenClosed = false`.
- Tests that activate the test process or put windows in front of other apps carry the `.showsWindows` trait and run
  only with `LAMINA_UI_TESTS=1` (`make test-ui`, CI); otherwise the test host's window is transparent and lets clicks
  through, so `swift test` never takes the focus of whoever is using the Mac. Give any new test like that the trait.

## Driving the running app with `lamina`

`lamina` controls a running copy of the app over Apple Events (decision-4): `lamina --help` lists the commands,
`lamina help <command>` their options; `--json` prints JSON. Put it on PATH with a symlink to the bundle's copy, e.g.
`ln -s "$PWD/build/Lamina Dev.app/Contents/Helpers/lamina" ~/.local/bin/lamina-dev`. A copy inside an app bundle
talks to that app; otherwise pick one with `--dev`, `--app <bundle id>`, `LAMINA_APP=dev|release|<id>`, or `--pid` when
several copies run (agents launching their own Dev build with `open -n` should always pass `--pid`). The first command
from a new calling app shows macOS's Automation prompt to the person.

- Commands are defined once in `Sources/LaminaAutomation/CommandCatalog.swift` (filter and adjustment settings in
  `EffectCatalog.swift`); the app implements each in `Sources/LaminaApp/Automation/` through the same `EditorSession`
  and `ProjectWorkspace` methods the menus call. Adding a command: its `CommandSpec` in the catalog, its handler in
  `AutomationDispatcher.handlers`, a test in `AutomationTests` (which also checks every result against the catalog's
  schema). `lamina`'s flags and help follow from the catalog.
- Edits are one undo step each and are refused (`busy`) while the person is mid-edit (`busyReason`); ids are short
  unique prefixes (`ShortID`); edits return what they changed and accept `expect_revision`.
- The sandboxed app never sees file paths: it returns file bytes (base64) and `lamina` writes them (`CommandClient`).
- `lamina mcp` is a stdio MCP server (`Sources/LaminaCLI/MCPServer.swift`) whose tools `MCPTools` makes from the catalog
  (tool name `apply_filter` for `apply-filter`, schemas, annotations from the command's `effect`), so a new command is a
  new tool with no MCP code. It serves MCP 2026-07-28 statelessly and the `initialize` era (2025-11-25 and earlier),
  logs only to stderr, and reports command failures as `isError` results. `MCPServerTests` drive it over pipes against
  a stub transport. Register it with `claude mcp add lamina -- <app>/Contents/Helpers/lamina mcp [--dev]` or
  `codex mcp add lamina -- …`.
- Entitlements: the app's are unchanged (receiving Apple Events needs none). `lamina` is signed with
  `Resources/lamina.entitlements` (`com.apple.security.automation.apple-events`), which the hardened runtime requires to
  send Apple Events.

## Verifying UI as an agent

Build with `make dev`, launch in the background with `open -g -n "build/Lamina Dev.app"`, and capture the window
with `screencapture -l <windowID> -o -x out.png` (window id from `CGWindowListCopyWindowInfo`, owner pid of the app).
Quit it with `osascript -e 'tell application id "com.itsjavi.lamina.dev" to quit'`. `lamina --pid <pid>` (above) can
put it in the state to capture (select a layer, apply a filter or adjustment) and `render-preview` saves the canvas as
a PNG. Canvas painting, drags, sheets, menus and drag and drop still need a manual check.
