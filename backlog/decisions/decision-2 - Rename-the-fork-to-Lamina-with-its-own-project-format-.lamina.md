---
id: decision-2
title: Rename the fork to Lamina with its own project format (.lamina)
date: '2026-10-07 20:32'
status: accepted
---
## Context

decision-1 gave the fork its own bundle id and update feed but kept upstream's name and project format: `.comp`
packages of type `com.compositor.project`, `"format": "com.compositor.project"` in the manifest, and one integer version
(11 in both apps). Any fork-only feature that saves new data (vector paths, Layer Fill, new shapes) would need version
12, which collides with upstream's own 12; not bumping lets upstream's app open the file and drop the new data when it
saves. Both apps also claim the same extension and type. Shipping a different app under upstream's name would confuse
users, search and support (doc-1, "Open question: the project format's identity").

Names considered and checked against existing apps and formats (2026-10-07): Veneer, Lightbench, AstraPix and
CosmoPhoto were usable; PhotoStudio, Photon, PhotoComposer, Lumax, Mattebox, BlendStack, LayerDeck and others clash with
existing photo apps, brands or file formats. Lamina showed no image editor of that name (it is used by an AI music stem
splitter, a Go developer toolkit, a beauty salon app and an old leaf-measurement tool); `.lamina` is not a known format.

## Decision

- The app is called **Lamina** (Latin for a thin layer). Bundle id `com.itsjavi.lamina` (Dev: `com.itsjavi.lamina.dev`),
  feed `https://downloads.itsjavi.com/lamina/appcast.xml`, Sparkle key in the Keychain account `lamina`, data in the
  `com.itsjavi.lamina` sandbox container.
- Projects get their own identity: extension `.lamina`, exported type `com.itsjavi.lamina.project` (conforming to
  `com.apple.package`), and `"format": "com.itsjavi.lamina.project"` in `manifest.json`. The package layout stays the
  same (`manifest.json` plus PNG layers).
- The version line continues from 11, so today's projects are identical in content; the fork's first format change is
  version 12 of the Lamina format, unrelated to upstream's 12.
- Upstream Compositor `.comp` projects open as an import, like PSD: versions up to 11, and later ones only as their
  changes are ported. Lamina doesn't write `.comp`.
- The Swift targets and module names (`Compositor`, `CPixels`) may stay, to keep the change small. The README and LICENSE
  keep crediting Robbie Tilton's Compositor (MIT).

## Consequences

- The rename and the format change happen before the first release (TASK-1), while no Lamina builds or files exist
  outside this Mac.
- `docs/project-format.md` and `docs/writing-comp-files.md` (agents write projects from it) move to the Lamina format.
- Upstream format changes after version 11 need porting into the importer, not just the reader.
- Pasteboard and drag types named `com.compositor.*` (layer rows, effects, masks) are internal; renaming them is
  optional and only affects drag and drop between the two apps.
- Before the first public release, check the name's domain, the Mac App Store and the US and EU trademark registers.
- Supersedes decision-1's choice to keep the `com.compositor.*` file identifiers and its `com.itsjavi.compositor`
  bundle id and feed.

## Amendment (2026-10-08)

Changed by the user before any of it shipped:

- The project extension is **`.lam`**, not `.lamina` (macOS doesn't claim it). The exported type
  `com.itsjavi.lamina.project` and the manifest's `"format"` stay as above.
- **Everything is renamed**, not just what users see: the Swift targets, folders and test host, the `com.compositor.*`
  pasteboard and drag types, and docs file names. Only the credits to upstream Compositor and the `.comp` importer keep
  the old name. The app target is `LaminaApp` (with `LaminaAppTests` and `LaminaTestHost`), because an executable
  target named `Lamina` would clash with the `lamina` command-line tool on a case-insensitive file system; the bundle
  is still `Lamina.app`.
- The person's settings and recent projects from the Compositor builds don't carry over: the new bundle id gets a new
  sandbox container, which the app can't read the old one from. Their `.comp` projects open as imports.

