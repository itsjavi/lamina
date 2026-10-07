---
id: doc-1
title: Upstream issues and PRs worth bringing into the fork
type: other
created_date: '2026-10-07 18:49'
updated_date: '2026-10-07 20:36'
tags:
  - research
  - upstream
---
# Upstream issues and PRs worth bringing into the fork

Research done on 2026-10-07 over every issue (95) and pull request (124) of
[robbietilton/Compositor](https://github.com/robbietilton/Compositor), to pick what this fork should do. Use it to create
tasks; each candidate names its source issue or PR, the evidence, a rough effort and value, and what to reuse.

## Scope and method

- Upstream `main` is identical to this fork's base (11d8d7a, 1.4.5, 2026-09-29): there are no upstream commits to port.
  The 35 merged PRs and 45 issues closed as completed are already in the fork.
- Reviewed: the 36 open and 14 declined (not planned) issues, the 34 open PRs and the 55 PRs closed without merging.
  Each item was checked against the fork's code. ✓ marks claims re-checked by hand in the code (file paths are under
  `Sources/Compositor/` unless noted); the others come from reading the issue, PR, diff and code during triage.
- Effort: S (hours), M (a day or two), L (more). Value: 1 (nice) to 3 (important).
- The open PRs date from Sep 24 to Oct 6, 2026 and have had no maintainer review. All merge cleanly into the fork's base
  except #115 and #164.

## Porting notes

- Remap paths: `Compositor/` → `Sources/Compositor/`, `Compositor/Rendering/*.c` → `Sources/CPixels/` (headers in
  `Sources/CPixels/include/`), `CompositorTests/` → `Tests/CompositorTests/`. Ignore `project.pbxproj` changes.
- A Swift file that calls new C functions needs `import CPixels` (member import visibility is on).
- Tests run under `swift test` with `Tests/CompositorTestHost`; tests that need the app's real SwiftUI menu bar (#200's
  `realMenuBarRunsItsCommands`) or real full-screen windows (#188) won't work as written.
- PRs to upstream are contributions under its MIT license. Credit the author when porting (a `Co-authored-by:` trailer
  and the PR link in the commit message).

## Decisions (2026-10-07)

Taken with the user after this research; they settle §6's product questions.

| Topic | Decision | Notes for the tasks |
| --- | --- | --- |
| New canvas from the clipboard | Yes | Take PR #201 (File › New from Clipboard, ⇧⌘V); borrow #176's import of files copied in Finder |
| More export formats | Yes: WebP and AVIF at least; PDF if it stays simple | On this Mac (macOS 27), ImageIO encodes AVIF, HEIC, TIFF and PDF, so those need no dependency (PR #208 for PDF; closed PR #149's export sheet as reference). It can't encode WebP: that needs libwebp (BSD-3-Clause, MIT-compatible) as a vendored C target, the one dependency this adds. Check AVIF encoding on macOS 26, the minimum, and offer only the formats `CGImageDestinationCopyTypeIdentifiers` lists |
| Brush flow and pen pressure | Yes, the way Photoshop does them | Flow next to Opacity in the Brush options: how much paint each dab lays down, building up within a stroke up to the stroke's opacity. Pressure as two options-bar toggles, pressure for size and pressure for opacity, as Photoshop's; mouse and trackpad strokes unchanged. Sources: closed PR #106 (flow), open PR #194 (pressure; try it on a real tablet). Order with the other brush PRs: #166, #193, flow, #194 |
| Localization | Postponed | Keep §6's notes for later |
| PSD export | Yes, if lossless and MIT-compatible | Our own layered writer in CompositorCore (closed PR #48's `PSDLayeredWriter` as the base, an MIT contribution; no third-party code). Lossless for pixels and structure: raster layers, masks, groups, opacity, blend modes, clipping and the composite. Live text, shapes, layer effects and Compositor-only adjustments can't all stay editable: each one either maps to its PSD equivalent (effects as `lfx2`, some adjustments as PSD adjustment layers) or is written as pixels. Decide per feature and say so when exporting. ImageIO only writes flat PSDs |
| PSD artboards | Yes, separate from export | One document per artboard on import (issue #65; closed PR #48 as reference), with TASK-2's PSD work |
| AI features | Postponed, under consideration | Only with an API key the user provides, or by a local CLI agent (Codex, Claude) driving the app through TASK-4/5. No bundled service |
| Prior art for TASK-4/5 | Reuse what's good, not what's hard to maintain | Take the ideas (command contract, deltas, short ids, describe/render tools), not the code. No Python bridge, no open TCP port unless a decision needs one |
| Platforms | macOS only | macOS 26+ on Apple silicon; §9's ports stay skipped |
| Vector shapes and Pen tool | A must-have, postponed | Reimplement (PR #115 as reference only). It adds vector data to projects, so it depends on the format decision below |
| Project format identity and versions | Option B, and the fork is renamed: **Lamina**, projects `.lamina` | decision-2; TASK-6 (rename), TASK-7 (format) |

### The project format's identity (decided: B, see decision-2)

Both apps write `.comp` packages with the type `com.compositor.project`, `"format": "com.compositor.project"` in the
manifest, and one integer version (11 in both today). Any fork-only feature that saves new data (vector paths, Layer
Fill, star shapes) needs a version bump. Bumping to 12 collides with upstream's own 12, which will mean something else;
not bumping lets upstream's app open the file, ignore the new fields and drop them when it saves.

- **A. Keep everything shared and number the fork's versions apart** (for example from 100). The least code now, but
  the separation is implicit, and both apps keep claiming the same extension and type, so double-clicking a file opens
  whichever LaunchServices picks.
- **B. Give the fork its own format identity, keeping the app's name.** A new type (`com.itsjavi.compositor.project`), a
  new extension and a new `format` id in the manifest, with the same package layout (`manifest.json` plus PNGs). The
  fork's version line continues from 11, so today's files stay identical in content. Upstream `.comp` files open as an
  import, like PSD: versions up to 11, and later ones only as their changes are ported. A small change: the type
  declaration, the extension, the format id, a loader that accepts both, and the docs for agents.
- **C. B plus renaming the app.** The rename is a branding call, not needed for the format. But once the fork is
  distributed (downloads.itsjavi.com), two different apps called Compositor with incompatible files confuse users,
  search and support, and the name is the upstream maintainer's. A rename touches the bundle id, the feed path, the
  sandbox container and the docs, so it's cheapest before the first release (TASK-1).

Recommendation: **B now**, while no fork files exist outside this Mac and before TASK-2 moves the format into
CompositorCore; **decide C before TASK-1's first public release**. Also note that `.comp` is already used by other tools
(for example GLSL compute shaders), which a new extension sidesteps. Record the outcome as a decision.

## 1. Bugs and robustness (do first)

| Item | Source | Evidence | Effort | Value | Reuse |
| --- | --- | --- | --- | --- | --- |
| Canvas Size, Image Size, Crop, Trim and some adjustments drop layer effects and live text | issue #180, PR #181 | ✓ `IO/ImageResizer.swift` `applyDocumentSize` rebuilds layers without shape, effects or text; ✓ `IO/CanvasResizer.swift` copies shape and text but not effects. Same in `HueSaturation.swift`, `Levels.swift`, `SelectionEdits.swift`, `FloatingSelection.swift`. Silent data loss | S | 3 | PR #181 as-is: one `ProjectSnapshot.documentLayers` mapping, `LayerEffects.scaled(by:)`, 9 tests that fail on main |
| Color Overlay only half-recolors translucent pixels | issue #211, PR #214 | ✓ the overlay is mixed over the already-composited color by the pixel's alpha (`Rendering/MetalLayerEffects.swift` and `Document/LayerEffects.swift`), unlike Photoshop | S | 2 | PR #214 (source-atop on CPU, `mix()` in Metal); its author couldn't run the tests, so run them and compare GPU with CPU output |
| Camera Raw color noise reduction reads uninitialized memory | PR #178 (also in #179) | ✓ `Sources/CPixels/AdjustPixels.c`: the `malloc`ed chroma plane is skipped for clear pixels (`if (!alpha) continue;`) and then blurred | S | 2 | PR #178 as-is (one line) |
| An oversized paste leaves a document that can't be saved | closed PR #12 | ✓ `Document/SelectionClipboard.swift` `addPixelLayer` inserts pasted images with no `DocumentLimits` check, while save enforces them (`IO/ProjectStore.swift`). E.g. a browser full-page screenshot taller than 30,000 px. Duplicate has no budget check either | S | 3 | Reimplement as one admission helper over `DocumentLimits` (not the PR's hard-coded caps); keep the NSImage fallback for PDF/vector paste |
| A malformed rotation or hue value crashes the inspector | closed PR #10 | ✓ `Document/LayerTransform.swift` `isValid` only checks rotation is finite; ✓ `UI/TransformInspector.swift` formats with `Int(value.rounded())`, which traps on huge values. Hue handles likewise (`UI/HueSaturationSheet.swift`). Agent-written `.comp` files plus live reload make bad values likelier in this fork | S | 2 | Reimplement: bound the values at load, format safely |
| ⌘-clicking a mask or layer thumbnail can hang or exhaust memory | closed PR #17 | `Document/MaskTracing.swift` builds an unbounded edge graph on the main actor; Magic Wand already traces natively with a cap (`Sources/CPixels/WandPixels.c`) | S | 2 | Reimplement: threshold to a byte mask and use `MagicWand.outline` |
| New Canvas doesn't focus or select the Width field | issue #184 | `UI/NewCanvasSheet.swift` asks for focus in `onAppear` on an inline view and never selects the text (not run) | S | 2 | — |
| Optional hardening | closed PRs #11, #15; open PR #210 | #11: `ContentFill.c` has no size guard and uses int index math (unreachable within today's limits, reachable through the #12 gap). #15: live-mask allocation failures are swallowed, so export or merge can silently omit layers under memory pressure (port only its failure latch). #210: draws the slider before pressing it in `SliderSnapTests`; the test passes here, so it's only hardening | S each | 1 | #11 guard, #15 latch, #210 as-is |

## 2. Performance

| Item | Source | Evidence | Effort | Value | Reuse |
| --- | --- | --- | --- | --- | --- |
| Camera Raw preview about 9× faster (≈1030 → 115 ms), same pixels | PR #179 | Multicore `dispatch_apply` main pass and box blur, a lookup table for opaque pixels, scopes measured on a ≤512 px copy; output pinned by pixel hashes | M | 3 | Adapt: the hashes were recorded in upstream's Xcode build, while the fork builds CPixels at -O3; re-record against the fork's single-threaded kernel first. Its timing tests may flake on CI |

## 3. Photoshop-parity features with ready PRs

All open, focused, with tests. Most edit `CompositorApp.swift` menus and the README, so port them one at a time.

| Feature | Source | Notes | Effort | Value | Reuse |
| --- | --- | --- | --- | --- | --- |
| Image › Image Rotation 90° / 180° | issue #212, PR #195 | Lossless vImage turn off the main thread; layers, masks, selection and guides turn; text and shapes stay editable; one undo. The fork only has Flip Canvas. Port after #181 so it doesn't drop effects | M | 3 | as-is |
| Filter › Unsharp Mask and High Pass | PR #196 | The fork has no sharpening filter. Live preview, selection-limited, C in `AdjustPixels.c` | S | 3 | as-is |
| Align and Distribute layers | PR #191 | Align to selection, canvas or each other; distribute centers or spacing; folders move as one; one undo | M | 3 | adapt: measure opaque pixels, not the transform box, as Photoshop does |
| Shortcuts for any menu command, and clearing a key | PR #186 | "More Menu Commands" section, a clear button, a loader that survives one bad saved entry; fixes the Delete key (U+0008 vs U+007F). Base for #188, #192, #200, #201, and its "Menu › Item" names suit TASK-4 command naming | M | 2 | as-is |
| Dodge and Burn brush modes | issue #169, PR #193 | Range and Exposure, build-up capped per stroke, alpha kept, masks refused; a new C kernel. Upstream declined painting features in general (see stance), which the fork may decide differently | M | 2 | as-is (conflicts with #194 in `BrushSettings`) |
| Edit › Stroke along the selection | issue #177, PR #190 | Width, color, opacity, Inside/Center/Outside; works on masks | M | 2 | as-is; use luminance instead of `value.red` on masks |
| Filter › Last Filter (⌘F) | PR #192 | Re-runs the last filter with its settings, one undo; ⌘F is free | S | 2 | as-is (after #186) |
| Camera Raw: reset a section from its header | PR #187 | ↺ per section; a test catches settings missing from a section | S | 2 | as-is |
| Camera Raw presets | PR #198 | Named presets in Application Support JSON (no format change), tolerant loading, unreadable file kept as `.bak`; makes the settings `Codable`, which also helps TASK-2 and TASK-4 | M | 2 | as-is |
| Brush tip, mode and colors carry over to new documents | PR #166 (issue #2, partly done) | Uses the existing `ToolDefaults`; the fork's test detection already keeps tests on compiled defaults | S | 2 | as-is |

## 4. Layer commands left out of a merged PR

PR #163's masks, Auto Select, tabs and Ungroup were taken upstream; its layer commands were left out to keep menus short.
Missing in the fork: Apply Layer Mask, Merge Visible, Flatten Image, Copy/Paste Layer Style, Show/Hide All Other Layers,
intersect selection. Core compositing commands and natural TASK-4 commands. Port from commit `aea6e20f`
(`ApplyLayerMask.swift`, `LayerStyleClipboard.swift`, `LayerMerge`). Effort S–M, value 3.

## 5. Small features without a ready PR

| Feature | Source | Notes | Effort | Value |
| --- | --- | --- | --- | --- |
| Custom crop ratios (e.g. 9:20) and Crop buttons next to the ratio picker | issues #165, #202 (#92 partly done) | Fixed list in `UI/CropControls.swift` / `Document/Crop.swift`; a `Spacer` pushes Cancel/Apply away | S | 2 |
| WebP import | issue #168 | ImageIO decodes WebP; the importer's type lists leave it out (`IO/ImageImporter.swift`, `IO/ImageFileDrop.swift`). Export would need libwebp (ImageIO can't encode it) | S | 2 |
| New Canvas in cm/in/mm with DPI | issues #185, #151 | New Canvas is pixels only and documents default to 72 ppi; reuse the unit conversions of `UI/ImageSizeSheet.swift` | S–M | 2 |
| History panel | closed PR #146 | Jump through `DocumentHistory`'s undo/redo stacks; take only this part of the PR (its selection tools are naive) | S | 2 |

## 6. Needs a product decision

The fork can differ from upstream here; each has a source to start from. The Decisions section above settles the
clipboard canvas, export formats, flow and pressure, localization, PSD export and artboards, and AI.

- **New canvas from the clipboard** (issue #159, PR #201; #176 is the weaker variant). The most-wanted feature request
  outside platform ports; upstream rejected the idea twice (#28, #79). Today: New Canvas already sizes itself from the
  clipboard, then ⌘V.
- **More export formats**: HEIC/AVIF/TIFF at 8 bits (closed PR #149) and PDF (PR #208, 67 lines). Upstream keeps export to
  PNG and JPEG. Pairs with a CLI `export --format`.
- **Painting depth**: brush flow (issue #63, closed PR #106), pen pressure (PR #194, never tried on a real tablet), Dodge
  and Burn (§3). Upstream keeps the brush simple ("compositing, not painting").
- **Workspace UI**: command palette (PR #200; also a mechanism TASK-4 can reuse), Navigator (PR #199; its thumbnail is a
  synchronous CPU composite on the main thread, rework first), screen modes and hiding panels (PR #188; differs from
  Photoshop's keys), tool bar in two columns (PR #189). Upstream keeps menus short on purpose.
- **Font menu**: PR #207 commit 1 lists all faces of a family (a real fix); commit 2's search field inside an NSMenu is
  fragile.
- **New adjustment and effect capabilities**: Layer Fill separate from opacity (issue #62; new format field and renderer
  change), LUT (`.cube`) adjustment layers and adjustment presets (issue #171), more filters as adjustment layers (issues
  #61, #97; PR #170 Structure), effect extras from closed PR #64 (center stroke, shadow spread/choke, per-effect blend
  modes).
- **PSD**: one document per artboard (issue #65) and layered PSD export (closed PR #48's writer; #40's ordering as
  reference). Best built into CompositorCore with TASK-2. Upstream deferred PSD export on purpose. Also: PSD layer effects
  are dropped on import (`IO/PSD/PSDDocumentBuilder.swift`, follow-up on issue #160).
- **External apps**: Edit in External App, e.g. Topaz (PR #197; needs the `files.bookmarks.app-scope` entitlement;
  niche). Relates to issue #167 (plugins / external filters).
- **Perspective crop** (issue #206): Camera Raw Geometry and Distort exist; a 4-corner crop that straightens the document
  is missing.
- **Bucket fill** (issue #144, closed PR #96): Magic Wand + Edit › Fill covers it today.
- **Generative AI** with the user's own key (closed PR #58): the first feature that would send pixels off the Mac;
  privacy decision. An agent over TASK-5's MCP could cover it instead.
- **Localization** (issue #205 and #74, #117, #123, #222; PRs #213, #215, #219 open and nine closed). Only worth it if
  the fork targets non-English users; it adds upkeep for every new string. Best groundwork: #126 (1,012 keys, coverage
  script) and #113 (display names on enums, `LocalizedStringKey` hints); #213 for a Settings window. Keep persisted raw
  values English; match blend modes by tag, not title. SwiftPM gotcha: a String Catalog compiles into `Bundle.module`,
  while SwiftUI `Text("…")` reads `Bundle.main`, so `build-app.sh` must copy the `.lproj` folders into the app.

### Format version collision

PRs #134 (star/polygon shapes, line styles), #170 (Structure) and #218 (RAW develop) each bump the `.comp` format to
version 12, and #115 adds persisted vector data. At most one can be "12", and decision-1 keeps the shared
`com.compositor.*` identifiers, so a fork-only v12 would mean something else than upstream's eventual v12. Decide how
the fork versions format extensions (TASK-2 is the natural place) before taking any of them.

## 7. Input for TASK-4 and TASK-5 (automation)

**Demand.** Issue #172 asks for MCP plainly. Issue #119 (declined) first proposed an off-by-default automation endpoint,
then narrowed it to what file editing can't do: filters (Gaussian Blur, Camera Raw), Remove Background, Magic Wand and
object selection, Content-Aware Fill, Spot Healing, Clone Stamp, painting and gradients, with nothing running when off
and no `.comp` change. Use that as the minimum command set, plus listing projects and layers, selecting, describing,
rendering a preview and exporting.

**Prior art.**
- Closed PR #89: an in-app `EditorAutomation` on the main actor calling the same `ProjectWorkspace`/`EditorSession`
  methods as the UI; one undo step per command; explicit document ids; optional expected revision; refuses while the
  user is mid-edit. Transport: loopback TCP with a per-launch token and a 0600 discovery file, plus a bundled Python
  stdio bridge that does file I/O outside the sandbox and sends bytes. 32 coarse, typed tools.
- Closed PR #91: the same tool layer over Streamable HTTP in the app; results are deltas (changed sections, touched
  layers, removed ids) and ids are shortest unique prefixes.
- Closed PR #174: 129 tools and a 128 KB tool list, an example of tool sprawl to avoid.
- Third-party servers: Josusanz/compositor-mcp writes `.comp` files directly (no app changes, but no filters or
  painting); marcushorndt/compositor-mcp compiles the document model into a headless process (the TASK-2 idea);
  md-f-sarker/compositor-mcp runs in-app by patching the app delegate.

**Takeaways.**
- Take #89's command contract and #91's deltas and short ids; keep tools few, coarse and typed.
- Every upstream attempt opened a loopback TCP port, which needs `com.apple.security.network.server` (the fork has only
  `network.client`) plus token handling and, for HTTP, Origin/Host checks. The fork's candidates (Apple Events, a Unix
  socket in an app-group container) avoid an open port; check the sandbox rules for each.
- #89's split, where the unsandboxed client reads and writes files and sends bytes, fits a CLI and solves sandbox path
  access.
- Don't depend on `/usr/bin/python3` (a Command Line Tools shim); TASK-5's Swift `mcp` subcommand avoids it.
- PR #186's "Menu › Item" names and PR #200's palette (runs live menu commands by name) are possible mechanisms.
- Fix §1's effects-dropping bug (#180) first, or size commands run by agents will silently lose effects and live text.
- Upstream won't take this direction: the maintainer prefers the file route and computer use for now and would rethink AI
  for a v2 rather than add an entry point into fast-changing internals.

## 8. Input for TASK-2 (CompositorCore)

- naco-siren/Compositor's `ipados` branch (issue #203): commits 1–3, 9, 11 and 12 move AppKit out of `Document/`, `IO/`
  and `Rendering/` behind one `Platform.swift`; direct prior art for the extraction.
- marcushorndt/compositor-mcp compiles the document model headless (proof it can stand alone).
- PR #181's `ProjectSnapshot.documentLayers` gives one snapshot→layers mapping; PR #198 makes Camera Raw settings
  `Codable`.
- PSD work that belongs there: artboards (#65), export (#48), effects kept on import (#160 follow-up).

## 9. Skip

- **Platform ports and older systems**: Linux (issue #19, the highest demand: 30 comments, 43 reactions), Windows (#23,
  #182; PRs #216, #87), iPadOS (#203), macOS 12–15 (#209, #70, #101, #142, #221; PRs #8, #35, #60, #72), Intel (#81,
  #156). The fork is macOS 26+ on Apple silicon. Community ports exist as separate repos.
- **Out of scope**: collage (#18), RGBA channel editing (#31), OpenRaster (#69; maybe later as interchange on top of
  TASK-2), node view (#76), layer locks (#85), AI/EPS (#130), light theme (#217; the app is dark by design and custom
  drawing would need an audit).
- **PRs not worth porting**: vector model and Pen tool (#115, 8.4k lines, conflicts, binds Direct Selection to A; reimplement
  if a Pen tool is wanted), pixel brush (#164), ⌘V creating a canvas (#176), RAW develop workspace (#218; split it if any
  part is wanted), AI upscaler (#73; try `VTSuperResolutionScaler` if ever), per-character text undo (#100), finishing text
  before actions and rasterize confirmation (#132, #135), brush blend modes (#107), the security PRs whose risks don't
  exist in the fork (#13, #14, #16), the README link (#128), and #125 (opened by mistake).

## 10. Already in the fork

- The 35 merged PRs and 45 completed issues.
- Open issues already covered: #84 (text size and color, layer menus), #143 (release notes: `scripts/appcast.sh` embeds
  them; they still need writing per release), #204 (requirements in the README), #221 (unsupported macOS, documented).
- Closed PRs whose feature shipped another way: Text tool (#27), New Canvas from the clipboard size (#28), title bar drag
  (#42), PSD import (#46, #47; native reader), filter layers (#82; as adjustment layers), automatic update checks (#83),
  crop to selection (#95), selected-letter color (#137), canvas presets (#141), Darkroom's filters (#71).
- Completed issues that are only partly done: #50 (effects lost; the rest is #180), #92 (crop ratios; rest is #165), #78
  (per-letter size still missing; #174 had size runs), #2 (brush settings; PR #166), #131 (Open Recent without
  favorites), #160 (PSD effects dropped on import).

## Upstream stance, for predicting what upstream will and won't take

Paraphrased from the maintainer's comments:
- **Scope**: compositing, effects and adjustments; not painting or illustration (brush flow, blend modes, bucket, pixel
  brush).
- **UI**: short menus on purpose; one feature per PR.
- **Formats**: export PNG and JPEG only, 8 bits per channel; PSD export deferred; wary of large vendored C++.
- **Platforms**: macOS 26.5+ and Apple silicon only; ports belong in separate repos.
- **Localization**: on hold while maintained alone (can't review languages he doesn't read); a String Catalog would be the
  groundwork later.
- **AI and automation**: keep agents on `.comp` files; may rethink AI in a v2; won't commit to an automation entry point
  or own a local endpoint's security.
- **Hardening**: treated as robustness, not security; wants reproduced crashes.

## Suggested task order

1. Bugs: #181, #214, #178, the paste admission (#12), safe rotation/hue values (#10), native mask tracing (#17), New
   Canvas focus (#184).
2. Camera Raw speed (#179), then its reset (#187) and presets (#198).
3. Parity features: Image Rotation (#195), Unsharp Mask and High Pass (#196), Align and Distribute (#191), the layer
   commands from #163, shortcuts for every command (#186) then Last Filter (#192), Edit › Stroke (#190), Dodge and Burn
   (#193), brush settings across documents (#166).
4. Small features: custom crop ratios and button placement, WebP import, New Canvas units and DPI, History panel.
5. Decided product features: New from Clipboard (#201), export to AVIF, WebP and PDF, brush flow and pen pressure.
6. Decide the project format's identity (B recommended), then TASK-2 with PSD artboards and PSD export, and fold §7–§8
   into TASK-4, TASK-5 and TASK-2.
7. Later: vector shapes and the Pen tool (after the format decision), AI features, localization.

## Tasks created from this research (2026-10-07)

| Finding | Task |
| --- | --- |
| Rename to Lamina; `.lamina` projects (decision-2) | TASK-6, TASK-7; TASK-1 (first release) now follows them |
| Effects and live text dropped by size changes (#180, #181) | TASK-8 |
| Color Overlay on translucent pixels (#211, #214) | TASK-9 |
| Camera Raw memory read and speed (#178, #179) | TASK-10; section reset and presets (#187, #198) in TASK-22 |
| Paste limits, saved values, mask tracing (#12, #10, #17) | TASK-11 |
| New Canvas focus, units and resolution (#184, #185, #151) | TASK-12 |
| New from Clipboard (#159, #201) | TASK-13 |
| Image Rotation (#212, #195) | TASK-14 |
| Unsharp Mask and High Pass (#196) | TASK-15 |
| Align and Distribute (#191) | TASK-16 |
| Layer commands from #163 | TASK-17 |
| Shortcuts for every command, Last Filter (#186, #192) | TASK-18 |
| Edit › Stroke (#177, #190) | TASK-19 |
| Brush settings, Dodge and Burn (#166, #193) | TASK-20; flow and pressure (#106, #194) in TASK-21 |
| Custom crop ratios, crop buttons (#165, #202) | TASK-23 |
| WebP import; AVIF, WebP, HEIC, TIFF, PDF export (#168, #149, #208) | TASK-24 |
| History panel (#146) | TASK-25 |
| PSD artboards (#65, #48) and layered PSD export (#48) | TASK-26, TASK-27 (after TASK-2) |
| Vector shapes and Pen tool (#115, reference only) | TASK-28 (postponed) |
| AI features; localization | DRAFT-1, DRAFT-2 (postponed) |
| Automation prior art (§7) and Core prior art (§8) | input for TASK-4, TASK-5 and TASK-2 |

Not turned into tasks yet: the optional hardening in §1 (#11, #15, #210) and §6's remaining product questions
(workspace UI, Layer Fill, LUTs and presets, more adjustment layers, external apps, perspective crop, bucket fill).
