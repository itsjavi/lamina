---
id: doc-4
title: Upstream review 2026-10-09 (Compositor 1.4.5 to 1.4.8)
type: other
created_date: '2026-10-09 15:50'
updated_date: '2026-10-09 16:41'
tags:
  - research
  - upstream
---
# Upstream review 2026-10-09 (Compositor 1.4.5 to 1.4.8)

The second review of [robbietilton/Compositor](https://github.com/robbietilton/Compositor), after
doc-1 (2026-10-07). Made with the `upstream-review` skill (`.claude/skills/upstream-review/`); its checkpoint now points
past this review.

## Scope

- Commits: `11d8d7a..22c7b8d` (Compositor 1.4.5 to 1.4.8): 61 commits: 7 merges, 6 release-only (version bumps and
  appcast), 48 others; 52 files, +2,992 −668.
- Issues and PRs updated since 2026-10-07: 59 (27 issues, 32 PRs), 32 of them opened since then. Every one has a row
  below or in a task.
- Each commit was checked against Lamina's code (Lamina file:line evidence is in the tasks). Judged by docs/DESIGN.md
  (decision-9) and doc-1's settled decisions.
- Upstream's direction since doc-1: the maintainer merged several PRs doc-1 had triaged (#178, #192, #199, #200, #208,
  #210, #214, #235), built his own versions of others (Image Rotation instead of #195, Canvas Only instead of #188),
  and added Scanlines, Export As and RAW import polish. Translations are on hold upstream; HDR is planned there (#224).

## Decisions (2026-10-09)

Taken with the person after this review; the `upstream-review` skill carries them for the next ones.

- Take from upstream: fixes to bugs and performance in features Lamina has; features Photoshop has and Lamina lacks;
  changes that bring the interface closer to Photoshop; easy interface QoL.
- Don't take: features Photoshop doesn't have (a draft at most, when interesting); anything that moves the interface
  back toward Compositor's style. Photoshop is the reference for names, places and keys, never upstream's presentation.
- Every Photoshop feature becomes a task with its in-progress placeholder, the big ones (CMYK proofing, 16/32-bit)
  included.

## Fixes

| Item | Upstream source | Evidence in Lamina | Effort | Value | Task |
| --- | --- | --- | --- | --- | --- |
| Inner Glow and Inner Shadow recolor translucent pixels fully | 9cb57db | LayerEffects, LayerEffectsSurface and the Metal kernel match upstream's code before the fix; TASK-9's source-atop is there | S | 3 | TASK-68 |
| Shadows and Highlights keep tones in order (banding when lifting shadows) | 0b4c56c, #236 | `tone_shadows` in AdjustPixels.c isn't monotonic: at +100, 0 → 0.5 and 0.1 → 0.36 | S | 3 | TASK-69 |
| Color noise reduction smooths color and keeps brightness | 42a559b | AdjustPixels.c still blurs an HSL saturation plane (TASK-10 left that block) | S | 2 | TASK-69 |
| RAW import dithered to 8 bits, rounded in C; Importing… in the develop sheet | 6345432, 196342c, 0907f51, 6e6ca38 | RawImporter renders straight to RGBA8; `finishRawDevelop` closes the sheet at once | S | 2 | TASK-70 |
| The hand stays closed for the whole pan | c0a1cd0 | Space key repeats reset the cursor to the open hand mid-pan | S | 2 | TASK-72 |
| Layers and Adjustments don't flash dimmed for a stroke or a move | 06313a9 | `canEditLayers` drives the panels' enabled look and goes false for every stroke and move | M | 2 | TASK-73 |
| Closing the last tab counts up "Untitled 2, 3…" | issue #231 (no upstream fix) | `ProjectWorkspace.removeTab` adds a new numbered tab; `nextNumber` never resets | S | 2 | TASK-75 |
| Options bars squeeze or clip in a narrow window | 68396ff (PR #226) | `OptionsBarRow` and `MoveToolBar` don't scroll; FreeTransformBar already does | S | 1–2 | TASK-76 |
| Disabled Layers footer icons dim unevenly; the rename row jumps (QoL) | 790195f, 7fb40a9, 8f7d344 (PR #226) | explicit `ColorRole.icon` foreground stops SwiftUI dimming; the rename bezel resizes the row | S | 1–2 | TASK-77 |
| Font menus leave out families macOS hides (Rockwell, Seravek, Iowan Old Style…) | PR #207 (commit 1) | the menus list `availableFontFamilies`, which omits them, though `availableMembers` returns their faces (checked on this Mac) | S | 2 | TASK-91 |

Trivial, no task: 07eee7e (PR #210) adds `window.displayIfNeeded()` before pressing the slider in `SliderSnapTests`;
Lamina's test lacks it and passes today. Take it with the next test change nearby.

## Closer to Photoshop

| Item | Upstream source | Evidence in Lamina | Effort | Value | Task |
| --- | --- | --- | --- | --- | --- |
| Layers opens groups and scrolls to a layer picked on the canvas | #235 (d2b8aaf, b4e147b) | `selectLayer`/`selectLayers` don't expand groups; the list scrolls only to rename | S–M | 3 | TASK-71 |
| Export As shows transparency on a checkerboard | b1db93d | ExportSheet previews on `pasteboard`, no checkerboard; FilterPreview has one to share | S | 2 | TASK-74 |

## Photoshop features

Each has a task and its in-progress placeholder in the app (DESIGN.md, In-progress placeholders), except PSD effects,
which has no control of its own. The keys were free in Lamina: ⌘F (unowned since Last Filter moved to ⌃⌘F), ⌘Y, ⇧⌘Y,
F, and Tab (which did nothing on the canvas).

| Feature | Source | Photoshop's shape | Reuse | Effort | Task |
| --- | --- | --- | --- | --- | --- |
| Screen modes and hiding the panels | ad4bddf, 088a5c1, 720c121 (upstream's own Canvas Only); closed PR #188 | View ▸ Screen Mode (Standard, Full Screen Mode With Menu Bar, Full Screen Mode), F cycles; Tab hides the panels, Shift-Tab all but the toolbar | #188's `ScreenModeController`; ad4bddf's window handling. State per window, not per document | M | TASK-78 |
| Search | PR #200 and its follow-ups (cb139a1, 384632d, 231b7d3, 07b8b1e, 94b57f7, bba92dc, 720c121, 6b81d4a) | Edit ▸ Search (⌘F): commands, tools and panels by name | `CommandPaletteSearch`, `CommandPaletteMenu`, the panel controller, three tests; tools rebuilt from `ToolSlot.items` | M | TASK-79 |
| Navigator | PR #199 (6490bb3), 3e09948 (minimap) | Window ▸ Navigator, a panel; upstream's corner minimap isn't Photoshop's | `NavigatorGeometry`, viewport helpers, the zoom slider, geometry tests; thumbnail rebuilt off the main thread | M | TASK-80 |
| Pencil Tool | closed PR #164 (a Pixel mode of the Brush) | Brush slot, after the Brush Tool | — (Lamina keeps tools separate) | M | TASK-81 |
| Perspective Crop Tool | issue #206 | Crop slot, after the Crop Tool | — | M | TASK-82 |
| Fill opacity | issue #62 | "Fill:" under Opacity in Layers; Fill Opacity in Blending Options | PSD import already reads fill | M | TASK-83 |
| Color Lookup (LUTs) | issue #171 | Image ▸ Adjustments ▸ Color Lookup…, and an adjustment layer | — | M | TASK-84 |
| Layer Style options | closed PR #64 | a Blend Mode per effect, Spread, Choke, Stroke's Center position | PR #64 for center stroke and spread/choke | M | TASK-85 |
| Toolbar in one column or two | open PR #189 | the double arrow at the toolbar's top | PR #189 | S–M | TASK-86 |
| Rearrange the tools | the person's request | Edit ▸ Toolbar… (Customize Toolbar) | — | M | TASK-87 |
| PSD import keeps layer effects | issue #160 follow-up | Photoshop files open with their effects | Lamina's six effects map from `lfx2` | M | TASK-88 |
| CMYK soft proofing | open PR #245; issues #225, #229 | View ▸ Proof Setup, Proof Colors ⌘Y, Gamut Warning ⇧⌘Y | PR #245 (ColorSync transforms), unreviewed upstream | L | TASK-89 |
| 16 and 32 bits per channel (HDR) | issues #224, #225 | Image ▸ Mode ▸ 8, 16, 32 Bits/Channel | — (upstream plans its own HDR work) | L | TASK-90 |

## Drafts (not in Photoshop)

| Idea | Source | Draft |
| --- | --- | --- |
| Filter ▸ Pixelate ▸ Scanlines… (split out of Dither, much extended) | 06c3a22, 1187736, cdde327 | DRAFT-3 |
| Structure adjustment layer | open PR #170 | DRAFT-4 |
| Edit in External App | open PR #197, issue #167 | DRAFT-5 |

## Already in Lamina

| Upstream | Lamina |
| --- | --- |
| Color Overlay on translucent pixels (e7e295e, #214, #211) | TASK-9 |
| Color noise reduction and clear pixels (a2718d9, 61ea182, #178) | TASK-10 |
| Filter ▸ Last Filter, then on ⌃⌘F (0415aa4, c9d769d, 6b81d4a, #192) | TASK-18, TASK-62 |
| Image ▸ Rotate Canvas 90° (754f188; #195 closed, #212) | TASK-14 (Image ▸ Image Rotation, Photoshop's names) |
| New Canvas in in/cm/mm at 72 or 300 DPI, transparent/white/black (b0b4f01, ab9779a, a00d8b6; #151, #185) | TASK-12, TASK-65 (New Document) |
| File ▸ Export PDF, then Export As with PNG, JPEG, PDF (9287cf1, aac6e02, 450af5f, #208) | TASK-24, TASK-65 (also HEIC, AVIF, WebP, TIFF) |
| One View ▸ Snap for all snapping (bba92dc) | TASK-62 |
| Theme switcher (#217) | TASK-51 |
| Crop custom ratios and 9:20 (#241) | TASK-23 |
| WebP import (#244) | TASK-24 |
| Pen pressure (#194) | TASK-21 |
| Star and polygon shapes (#134), vector features (#233) | m-2: TASK-28, TASK-32 |
| Release notes in the update dialog (#246) | `scripts/appcast.sh` embeds `Lamina-<version>.html` or `.md`; a Help ▸ What's New item isn't worth it |
| Camera Raw temperature in Kelvin for RAW files (#252) | The RAW develop sheet already uses Kelvin (2,000–12,000 K, from the camera's as-shot value); Camera Raw Filter on an 8-bit layer is −100…+100, as Photoshop's is for rendered images. Optional: say so in the Temperature help tag |

## Skip

| Upstream | Why |
| --- | --- |
| Don't Save marked destructive, then back to a plain button (283d360, 4e035bf) | Net no change; Lamina's alert is the same as the fork base's |
| Edit menu without macOS's text extras (710dd66) | DESIGN.md keeps them (inline type editing uses Dictation and Emoji & Symbols); the fix relies on private menu identifiers |
| Layer effects button "Add layer effect" (f25effa) | Lamina uses Photoshop's "Add a layer style" |
| Navigator as a canvas minimap, Canvas Only on F, palette as View ▸ Search Commands (3e09948, ad4bddf, 720c121) | Upstream's own presentation; Photoshop's shapes are TASK-78 to TASK-80 |
| Float the chrome over the canvas in Liquid Glass (open PR #227) | Breaks DESIGN.md's flat regions separated by edges |
| PR #226's other parts (status bar hiding, ContentUnavailableView) | Upstream declined them too |
| Localization: PRs #213, #215, #219, #220, #223, #230, #234, #237, #239, #240, #242, #251; issues #205, #222, #243, #247 | draft-2 stays postponed; upstream holds translations too. Demand is real (16 items in three days, mostly Simplified Chinese), worth weighing when draft-2 comes back |
| Older macOS, Intel, Linux, Windows: #9, #19, #23, #209, #216, #228, #238, #248, #249; requirements questions #204, #221 | macOS 26+ on Apple silicon (doc-1); the README lists the requirements |
| Illustrator files (#250) | Out of scope; m-2 covers vector work |
| Expand high-precision RAW development (#218, closed) | doc-1: skip as a whole |
| Release plumbing (24ef288, 675d8a4, e64f749, appcast commits), README-only commits | Not ported |

## Records created

- Tasks: TASK-68 to TASK-77 and TASK-91 (fixes and closer to Photoshop), TASK-78 to TASK-90 (Photoshop features, with
  their placeholders), all in m-1 (TASK-87 without the `upstream` label: it came from the person, not upstream).
- Drafts: DRAFT-3 to DRAFT-5.
