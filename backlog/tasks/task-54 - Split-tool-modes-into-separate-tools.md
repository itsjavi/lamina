---
id: TASK-54
title: Split tool modes into separate tools
status: Done
assignee:
  - '@claude'
created_date: '2026-10-09 02:14'
updated_date: '2026-10-09 05:07'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/references/redesign_v2.html
documentation:
  - docs/DESIGN.md
priority: high
type: feature
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Several Lamina tools hide what familiar editors show as separate tools: Brush has Paint, Erase, Dodge and Burn modes; Smear has Liquify, Blur and Smudge; Marquee, Lasso, Magic and Shape switch their kind with a picker or Tab. People scan the toolbar for Eraser, Dodge or Polygonal Lasso and don't find them. The engines can stay shared; what changes is how tools are chosen, keyed and remembered. Liquify isn't a toolbar tool elsewhere, so it moves to Filter ▸ Liquify….
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 These are tools of their own: Rectangular and Elliptical Marquee; Lasso and Polygonal Lasso; Object Selection and Magic Wand; Brush and Eraser; Dodge and Burn; Blur and Smudge; Rectangle, Ellipse and Line
- [x] #2 Tool keys follow docs/DESIGN.md, and Shift plus a tool's key cycles the tools that share its slot
- [x] #3 Filter ▸ Liquify… (⇧⌘X) picks the Liquify brush with its own options bar and Done and Cancel; Liquify no longer appears in the toolbar
- [x] #4 Each tool remembers its own settings as today, and brush defaults saved by earlier versions carry over
- [x] #5 Status hints, help tags and tests cover the new tools and keys
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 docs/DESIGN.md matches what shipped
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Tool model (new Document/NavigationTool.swift): one NavigationTool case per tool in toolbar order (Rectangular/Elliptical Marquee, Lasso/Polygonal Lasso, Object Selection/Magic Wand, Brush, Eraser, Gradient/Paint Bucket, Blur/Smudge, Dodge/Burn, Rectangle/Ellipse/Line, plus liquify outside the toolbar and idle). A ToolSlot enum lists each slot's tools and key (DESIGN.md Toolbar table); tools expose slot, name, help label, symbol and the derived kinds (lassoKind, shapeKind, toneLightens) that replace marqueeKind, lassoKind, wandMode, shapeKind, brushMode and blurMode.
2. EditorSession: per-slot last-used tool (slotTools, tool(in:)), pressToolKey(key, shift:) shared by the canvas and the layer list (plain key picks the slot's last tool, Shift cycles within the slot when it is active), remove Tab mode cycling and the mode toggles; lastFillTool folds into the slot memory.
3. Engines stay shared: brush begin/finish, warp (WarpMode liquify/smudge replaces BlurToolMode), selection drafts, shapes and cursors read the tool instead of the modes.
4. Settings memory: brush tip families grow to brush, clone, smear, eraser, tone (Dodge/Burn), liquify; new families start from the tip they shared before (eraser/tone from brush, liquify from smear) when nothing is saved for them. The saved brushMode maps to the Dodge slot's last tool (Burn or Dodge). Migration test.
5. Liquify: Filter > Liquify... (Shift-Cmd-X, registered in ShortcutDefinition.all) records the previous tool and history position and selects the Liquify brush; its bar is the brush bar (Size, Hardness, Strength) with Cancel and Done. Done returns to the previous tool; Cancel jumps history back to the recorded position, then returns. Return/Escape do the same on the canvas.
6. UI: rail lists every toolbar tool (TASK-55 replaces it) through one ToolIcon view; remove mode pickers that duplicated tool choice (Marquee shape, Magic mode, Lasso kind, Shape kind, Brush mode, Smear mode); bar titles use tool names; status hints move to a toolHint property per tool; help tags read 'Tool Name (Key)'. Keyboard Shortcuts list: new tool names and O, Shift-cycle entries per slot, Tab entry removed, saved overrides carried to renamed ids.
7. Tests: update suites that used modes; add slot/key, liquify cancel/done and BrushDefaults migration tests. swift build, targeted suites, full swift test; make dev and capture the window.
8. DESIGN.md: record anything settled (interim icons for new tools, Liquify Return/Escape, Tab removed).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tool model: NavigationTool has one case per tool in toolbar order (rectangularMarquee, ellipticalMarquee, lasso, polygonalLasso, objectSelection, magicWand, crop, eyedropper, spotHealing, brush, cloneStamp, eraser, gradient, paintBucket, blur, smudge, dodge, burn, type, rectangle, ellipse, line, hand, zoom) plus liquify (no slot) and idle, in Sources/LaminaApp/Document/NavigationTool.swift. ToolSlot lists each slot's tools in flyout order and its key; NavigationTool.slot, title, label ('Eraser Tool (E)'), symbol and hint come from there. The old modes are derived from the tool (lassoKind, shapeKind, toneLightens, warps, usesBrushDynamics); brushMode, blurMode, wandMode, marqueeKind, lassoKind, shapeKind, lastFillTool, cycleToolMode and the toggle/press*Key helpers are gone. For TASK-55: EditorSession.slotTools (observed) holds each slot's last tool, tool(in:) reads it, pressToolKey(_:shift:) is the one key path (canvas and Layers panel), and ToolIcon(tool:) in UI/ToolIcon.swift draws each tool's icon.

Decisions: Shift plus a slot's key steps to the next tool only when that slot's tool is active; from another tool it picks the slot's last tool (Lamina's Shift-G/Shift-U behavior before). A held key counts once for every tool key. Tab is gone from the canvas and the Layers panel (it also stepped Spot Healing's type, Clone Stamp's sample and Gradient's shape; those stay in their bars). Liquify is a tool outside the rail: Filter > Liquify... records the previous tool and History position; Done/Return returns keeping strokes, Cancel/Escape jumps History back to that position (one move, Redo brings it back), any other tool choice keeps the strokes. Menu item dims without layer pixels (empty layer or mask targeted). The rail lists every tool (spacing 4) until TASK-55; Dodge/Burn use sun.max/flame until TASK-55 draws custom icons.

Settings: tip families brush (Brush, Spot Healing), clone, smear (Blur, Smudge), eraser, tone (Dodge, Burn), liquify. Settings saved before the split (no tool.brushTipFamilies key) start eraser/tone from the brush tip and liquify from the smear tip; the first tip save writes brushTipFamilies=6 so later untouched families keep their compiled defaults. The saved brushMode becomes the Dodge slot's tool (Burn when it was Burn), saved from now on as tool.toneTool; Paint/Erase need nothing since Brush and Eraser are separate tools. Flow, Smoothing and the pressure buttons stay shared by Brush, Eraser, Dodge and Burn as before. selectTool now swaps tips from the tip in use (activeTipFamily) rather than the current tool's, fixing a stale tip after Cmd-T went straight to Move. Keyboard Shortcuts: tool entries renamed (old ids carried over via ShortcutSettings.renamedIDs), Dodge / Burn (O) added, Cycle tool mode (Tab) removed, a 'Next ... tool' Shift entry per multi-tool slot, Liquify (Shift-Cmd-X) registered. Eraser bar drops the foreground swatch (meaningless there; DESIGN's Eraser bar has none). README selection/painting lines updated minimally; full README/website/screenshots are TASK-66.

Verification: swift build clean (no new warnings); swift test passes (693 app tests in 102 suites, 47 + 22 in the other targets), including new ToolSlotTests (slots, keys, labels, hints, Shift cycling from canvas and Layers panel, renamed shortcut ids), LiquifyTests (menu pick, Done, Cancel with Redo, own tip, Escape/Return, dimmed without pixels, Shift-Cmd-X registered) and BrushDefaultsTests.settingsSavedBeforeTheToolsSplitCarryOver. Visual check: make dev, launched in the background on the demo project with a temporary (reverted, never committed) env override of the starting tool; captured the window on Liquify (Size, Hardness, Strength, Cancel, Done; hint 'Return Done · Escape Cancel'), Eraser (no color swatch, eraser icon selected in the rail) and Object Selection (no mode picker, hint 'Shift-W for Magic Wand'). The rail lists all 25 toolbar tools in toolbar order and scrolls. Not checked by hand: the Filter menu item drawn in the menu bar (the Debug build would assert at launch if Shift-Cmd-X were unregistered), canvas painting and real key presses. make test-ui not run (orchestrator runs it).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Split the mode-based tools into tools of their own: Rectangular/Elliptical Marquee (M), Lasso/Polygonal Lasso (L), Object Selection/Magic Wand (W), Brush (B), Eraser (E), Gradient/Paint Bucket (G), Blur/Smudge (R), Dodge/Burn (O), Rectangle/Ellipse/Line (U). NavigationTool has a case per tool and ToolSlot groups them with their keys; a key picks the slot's last tool (EditorSession.slotTools, for TASK-55's flyouts), Shift and the key steps through the slot, Tab no longer cycles modes. Engines stay shared; mode pickers that duplicated the tool choice are gone. Filter > Liquify... (Shift-Cmd-X) picks a Liquify brush outside the toolbar with Cancel and Done (Escape/Return); Cancel jumps History back to where Liquify was chosen. Eraser, Dodge/Burn and Liquify keep their own tips, migrated from the tip they shared, and a saved Burn mode carries into the Dodge slot. Hints, help tags ('Eraser Tool (E)') and Keyboard Shortcuts follow; DESIGN.md and two README lines updated. Verified with swift test (all suites, new ToolSlotTests, LiquifyTests and a migration test) and window captures of the Dev build.
<!-- SECTION:FINAL_SUMMARY:END -->
