---
id: decision-9
title: >-
  The interface follows the layout and names people know from established image
  editors, kept in docs/DESIGN.md
date: '2026-10-09 02:11'
status: accepted
---
## Context

Most people who try Lamina already know another image editor, usually Photoshop or Affinity Photo (decision-7 pitches
Lamina as a simpler alternative to both). Lamina's own interface worked, but almost nothing was where they expected or
called what they expected: Eraser, Dodge and Burn were modes of the Brush, Liquify, Blur and Smudge were modes of a
"Smear" tool, adjustments sat directly in the Image menu, the Move tool's bar held X, Y, W and H, Free Transform lived
in the Layer menu, each layer effect opened its own panel, and the app was dark only. Each difference costs a switcher a
search.

In October 2026 the interface was redesigned as an interactive mockup at the size of a 14-inch MacBook Pro window and
approved: docs/references/redesign_v2.html.

## Decision

- **Familiar, not a copy.** Lamina uses the layout and vocabulary that established raster editors share: tools in a
  single column at the left, grouped with flyouts; a context options bar above the canvas; panels docked at the right
  (Properties and Adjustments over Layers, History as a panel icon); menus in the conventional order; dialogs with their
  settings on the left and OK, Cancel and Preview on the right; zoom and document size in a status bar under the canvas.
  Where editors disagree, the most widely known convention wins, which is usually Photoshop's. Lamina never copies
  another product's visuals, icons, colors or branding; it draws with native macOS controls, SF Symbols and system
  colors.
- **Established names.** Every tool, command and option takes the name people already know. A Lamina-only feature uses
  the same vocabulary and sits in the nearest conventional place.
- **Light and dark.** The app follows the macOS appearance, with an override (System, Light, Dark) in Settings.
- **Fits 1500 × 860 pt**, the usable area of a 14-inch MacBook Pro at its default scaling, with nothing clipped.
- **docs/DESIGN.md is the spec** and stays current: every change to the interface updates it in the same commit.
- **Planned features show in place.** A feature with an open Backlog task shows its control where it will live, and
  using it says the feature is in progress. Features with no task don't appear.
- **Workspace first.** Milestone m-5 (Familiar workspace) is finished before any other new feature work starts; fixes
  and releases can still ship.

Rejected:

- Polishing Lamina's own layout: every switcher would still relearn it.
- Reproducing one product's interface pixel for pixel: it imitates another company's design and fights native macOS
  controls.
- A Claude Design design-system project: it syncs web component libraries, and Lamina's interface is SwiftUI and AppKit,
  so it would be a second copy to keep in step by hand. It may suit the website later.
- Hiding planned features until they ship: people can't tell what is coming, and the layout would shift with every
  release.

## Consequences

- Tool modes become tools of their own, so tool keys, per-tool defaults and the status hints change.
- Menu items move and are renamed, and some shortcuts change to the conventional ones (listed in docs/DESIGN.md).
  Shortcuts people customized for renamed items must carry over.
- Adjustment layers are edited in the Properties panel instead of floating panels.
- Every hard-coded interface color becomes a named role with light and dark values.
- README, website and screenshots are refreshed once the workspace lands, at the end of m-5.
- Agents finishing any interface task check that docs/DESIGN.md matches what shipped, and new feature tasks with
  visible UI add their in-progress placeholder to the spec.

