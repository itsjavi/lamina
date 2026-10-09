---
name: upstream-review
description: Review what changed in upstream Compositor (robbietilton/Compositor) since the last review (commits, issues and pull requests), decide what Lamina should port, adapt, decide on or skip, and record it in the backlog without duplicating existing records. Use when asked to check upstream, catch up with Compositor, or triage upstream issues and PRs.
---

# Upstream review

Lamina is a hand-ported fork of [robbietilton/Compositor](https://github.com/robbietilton/Compositor) (decision-1):
upstream changes are never merged, only ported, adapted or skipped. A review covers everything upstream did since the
checkpoint in [checkpoint](checkpoint): `commit=` (the last upstream commit reviewed), `since=` (when issues and PRs were
last queried) and `doc=` (the backlog doc that recorded that review).

## 1. Make the worksheet

```bash
.claude/skills/upstream-review/scripts/upstream-report.sh --out <scratchpad>/upstream.md
```

It fetches upstream `main` into `refs/upstream/main` (inspect with `git show <sha>`) and writes:

- every non-merge commit since the checkpoint, oldest first, with its PR when it came through one, and each file mapped
  to Lamina's path (`path-map.tsv` holds renames; add a line when you find a new one), "moved" or "new upstream file";
- release-only commits (version bumps, appcast) and merges, listed apart;
- every issue and PR updated since `since=`, marked "new" when opened after it, and the open PRs not touched since;
- a Backlog column: the upstream-related backlog records that already cite the number.

Keep the two values at its top, upstream head and "Queried at", for step 5. `--from` and `--since` override the
checkpoint.

## 2. Know what's settled before judging

- The last review's doc (`doc=`) and [doc-1](../../../backlog/docs/research/) (the first review): its Decisions table,
  Upstream stance, Skip list and Format notes are settled calls; don't reopen them without new evidence.
- `backlog task list --plain`, `backlog/drafts/`, `backlog/decisions/`, and `backlog search "<keywords>"` for anything
  the Backlog column doesn't catch (upstream items often reach the backlog under Lamina's own wording).
- [docs/DESIGN.md](../../../docs/DESIGN.md) (decision-9): Lamina uses the layout and names people know from Photoshop
  and similar editors, native controls and named color roles. It is the bar every UI change is judged against.
- AGENTS.md's Layout section: LaminaCore holds the project format and PSD parsing, CPixels the C loops, and the UI was
  rebuilt (toolbar, options bars, dock, Layers panel, menus, dialogs), so most upstream UI diffs don't apply as written.

## 3. Triage

What Lamina takes from upstream (the person's rules, 2026-10-09):

- **Take:** fixes to bugs in features Lamina has and performance of existing features; features Photoshop has and
  Lamina lacks; changes that bring Lamina's interface closer to Photoshop where it differs; easy interface QoL that
  fits DESIGN.md (for example rearranging tools).
- **Don't take:** features Photoshop doesn't have (if interesting, propose a draft, never a task); anything that moves
  the interface back toward Compositor's style. Photoshop is the reference for how a feature looks and where it lives,
  never upstream's presentation.

Give every commit (or group of commits making one change) and every new or changed issue and PR one category:

| Category | Meaning |
| --- | --- |
| already in Lamina | cite the task or the code |
| fix | a bug or slowness in something Lamina has; Lamina's code still has the problem (say whether upstream's change ports as-is or must be adapted) |
| Photoshop feature | Photoshop has it, Lamina doesn't; state Photoshop's name, menu, key and panel, and what upstream code is reusable |
| closer to Photoshop | Lamina's interface or behavior differs from Photoshop's here |
| QoL | an easy interface improvement that fits DESIGN.md |
| draft | not in Photoshop but interesting; a draft at most |
| skip | say why: not in Photoshop and not interesting, Compositor's UI style, platforms (macOS 26+, Apple silicon only), release plumbing, localization while draft-2 is postponed, already declined |

- Check claims against Lamina's code, not names: open the file the worksheet maps to and confirm the upstream "before"
  is still there. Lamina reworked some code upstream still has (multicore Camera Raw kernels, Layer Style dialog,
  Export As, New Document), so a fix may need re-deriving rather than applying.
- UI: judge the problem, not upstream's presentation. When upstream invents its own UI for something familiar editors
  have (Navigator minimap, command palette, Canvas Only), propose the Photoshop shape (name, menu, key, panel) or skip.
  Never port upstream's look (literal grays, layouts, its own names for familiar things).
- Pixel changes: note hashes to re-record (`CameraRawSpeedTests`), CPU/Metal parity (`render(_:mask:effects:gpu:)`),
  and tests to bring.
- Upstream issues with no upstream fix are still worth a look: check whether the bug exists in Lamina.
- For a large review, fan out read-only subagents by area (pixels, C and effects; UI fixes; new features) with the
  context block below, and keep the triage and the backlog writing yourself.

Subagent context block:

> Lamina (this repo) is a hand-ported fork of robbietilton/Compositor. Upstream main is at the local ref
> `refs/upstream/main` (`git show <sha>`); issues and PRs via `gh api repos/robbietilton/Compositor/issues/<n>` and
> `gh pr diff <n> -R robbietilton/Compositor`. Path remap: `Compositor/X` → `Sources/LaminaApp/X` (project format in
> `Sources/LaminaCore`), `Compositor/Rendering/*.c|h` → `Sources/CPixels/` (headers in `include/`), `CompositorTests/`
> → `Tests/LaminaAppTests/`; search by symbol when a path moved. UI follows docs/DESIGN.md (Photoshop's names and
> places, native controls, color roles). Read-only: no edits, builds or tests. Per item report its category (already
> in Lamina / fix / Photoshop feature / closer to Photoshop / QoL / draft / skip), Lamina file:line evidence, effort
> S/M/L, value 1–3, porting notes.

## 4. Agree, then record

Show the person the triage as a list grouped by category (one line per item: what, upstream source, effort, task if
any) and wait for their go-ahead before creating or changing any backlog record: tasks, drafts, docs, notes. Record
only what they approve.

- One research doc per review: `backlog doc create "Upstream review YYYY-MM-DD" -p research -t other`, then fill it
  (frontmatter tags `research`, `upstream`). Sections: Scope (range, counts, checkpoint values), Port, Adapt, Decide,
  Already in Lamina, Skip, Issues and PRs (one row each), Tasks created. Each row: item, upstream source (commit, PR,
  issue), evidence in Lamina, effort, value, reuse notes. Cite upstream numbers as `#n` so the next worksheet's
  Backlog column finds them.
- Draft items become `backlog task create --draft` records when approved, never tasks.
- Tasks only for approved items that have no task yet (check the Backlog column and `backlog search`). Label
  `upstream`, name the doc and the sources in the description, credit contributors (their commits ported keep a
  `Co-authored-by:` trailer and the PR link). Group small related ports when they touch the same code (for example
  two Camera Raw kernel fixes), not unrelated ones.
- A task that adds visible interface needs its DESIGN.md placeholder row and `PlannedFeature` case when created
  (DESIGN.md, In-progress placeholders). Record the person's answers in the doc's Decisions section.
- If an upstream change touches an open task's subject (a fix to something a task will port), add a note to that task
  instead of a new one.

## 5. Advance the checkpoint

```bash
.claude/skills/upstream-review/scripts/advance-checkpoint.sh <upstream head> <queried-at> <doc-id> [--push]
```

Commit `checkpoint` (and `path-map.tsv` if it changed) with the review doc. `--push` also moves origin's
`upstream-checkpoint` branch to the reviewed upstream commit, keeping it reachable from the fork's remote.

## When porting later

- Remap paths as above; a Swift file calling new C needs `import CPixels`; tests run under `swift test` with
  `LaminaTestHost` (tests that put windows in front take `.showsWindows`).
- Any change to what people see updates DESIGN.md in the same commit; a user-facing feature also updates README,
  website and screenshots (brand/README.md).
- A change to what's saved is a format version bump in LaminaCore and docs/project-format.md; upstream's `.comp`
  versions past 11 are only readable once their changes reach the importer.
