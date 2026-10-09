# Public presentation: README, website, social card and screenshots

Everything people see before installing Lamina. Keep it in sync with the app: when a feature ships or the UI changes
substantially, update the affected pieces in the same task.

| What        | Where                                               | Shows                                                         |
| ----------- | --------------------------------------------------- | ------------------------------------------------------------- |
| README      | `README.md`                                         | Pitch (decision-7), why, feature list, screenshot table, build |
| Website     | `web/index.html`, `web/styles.css`                  | Hero, why, feature rows, details grid, build steps            |
| Icon        | `web/assets/icon.png`, `favicon.png`, `apple-touch-icon.png` | Renders of `Resources/AppIcon.icon` (`scripts/app-icon.swift`) |
| Screenshots | `web/assets/*.webp`                                 | Used by both the README and the website                       |
| Social card | `scripts/og-image.html` → `web/assets/og-image.jpg` | Icon, headline, intro text and the hero screenshot            |
| Intro video | not yet (TASK-40, after vector support)             |                                                               |

The website deploys to https://itsjavi.com/lamina/ on every push to `main` that touches `web/`
(`.github/workflows/pages.yml`, GitHub Pages built from Actions).

## What to update

| Change                                   | README          | Website                     | Screenshots                          |
| ---------------------------------------- | --------------- | --------------------------- | ------------------------------------ |
| New user-facing feature                  | feature bullet  | feature row or details card | add one if it is visible and notable |
| Substantial UI change (layout, toolbar…) | if text changed | if text changed             | recapture affected shots             |
| Feature removed or renamed               | remove / rename | remove / rename             | recapture                            |
| Hero screenshot or tagline changed       | –               | hero                        | `screenshot.webp`; also the social card |

Never leave published copy, screenshots or the social card showing UI that no longer exists. If a change needs none of
this, say why in the task notes.

## Screenshots

Captured from the agents' Dev build (never the user's app), in the background, from a demo project a script writes,
so they are reproducible:

```bash
make dev
swift scripts/demo-project.swift "/private/tmp/lamina-demo/Golden Hour.lam"
P=~/Library/Containers/com.itsjavi.lamina.dev/Data/Library/Preferences/com.itsjavi.lamina.dev.plist
defaults read "$P"                                    # note what you change, to put it back afterwards
defaults write "$P" "NSWindow Frame editor" "6 89 1500 860 0 75 1512 874 "  # window size (DESIGN.md's target)
defaults write "$P" tool.grid -bool false             # no layout grid over the canvas
defaults write "$P" appearance dark                   # or light; delete the key afterwards
open -g -n -a "$PWD/build/Lamina Dev.app" "/private/tmp/lamina-demo/Golden Hour.lam"
PID=$(pgrep -nf "$PWD/build/Lamina Dev.app")
swift scripts/window-screenshot.swift "Lamina Dev" /private/tmp/shot --pid $PID           # the document window
swift scripts/window-screenshot.swift "Lamina Dev" /private/tmp/shot --panels --pid $PID  # with its floating panels
kill $PID
```

Current shots (window 1500×860 points, rulers on, grid off):

| File              | Setup                                                                       |
| ----------------- | --------------------------------------------------------------------------- |
| `screenshot.webp` | Dark. The demo as it opens: the "Golden hour" title selected with the Move tool, Properties showing the Type Layer |
| `camera-raw.webp` | Dark. Sky layer selected, Filter › Camera Raw Filter…, `--panels`           |
| `curves.webp`     | Light. Warm grade selected, so Properties shows its Curves                  |
| `oil-painting.webp` | Dark. `scripts/oil-painting-project.swift`'s seascape as it opens, 2400 wide. Showcases agent painting (strokes are generated outside the app until the agent painting milestone lands) |

One shot is light and the rest dark, so the pages show both appearances without a pair of every image. Select layers
with `lamina --pid $PID select-layer --document <id> --layer <id>` (ids from `lamina --pid $PID list-documents`), and
choose menu commands with `swift scripts/menu-command.swift $PID Filter "Camera Raw Filter…"` (Accessibility's press
action on the item, so the calling app needs Privacy & Security › Accessibility); neither sends mouse or key events.
Convert and size them like the existing files:

```bash
cwebp -q 86 -m 6 -resize 2400 0 shot.png -o web/assets/screenshot.webp   # hero: 2400 wide
cwebp -q 86 -m 6 -resize 1600 0 shot.png -o web/assets/camera-raw.webp   # others: 1600 wide
```

Gotchas:

- The window frame default is shared by every copy of the Dev build; set it before launching and restore it (and any
  other default you changed) when done.
- The last four numbers of the window frame are the screen's visible frame; a window taller than it is shortened.
- Floating panels hide while the app is in the background. `--panels` still captures them, but nothing can close them
  without a key press: quit the Dev build (`kill $PID`) and launch it again for the next shot.
- Background windows are never key, so traffic lights look inactive. Acceptable.
- The appearance default is read at launch; quit and launch again after changing it.

## Numbers on the website

The cards under the hero state the app's size, how fast it opens and its memory with a fresh canvas (decision-7 keeps
the size under 50 MB, which the hero badge promises). Keep them true, and watch them, with two commands:

```bash
make metrics       # build, measure, record in brand/metrics.json, compare with the record before
make metrics-web   # write the latest record into the cards and the "Measured on" note, then review, commit, push
```

`make metrics` (`scripts/metrics.swift`, about two minutes) builds the release app for its size and launches a
release-optimized Dev build in the background, so it never takes focus or touches the release app's data: ten launches
with a fresh canvas and eight with the Golden Hour demo, leaving out each first, cold one. It records the medians with
the commit, version and machine, and prints the change from the record before, marking anything that got worse past
its tolerance (5% for size, 15% for opening a project, 10% for the rest). Run it after big features and before
publishing new numbers; compare only records from the same machine (the comparison warns when they differ).

| Card            | From the record                                   | Shown as             |
| --------------- | ------------------------------------------------- | -------------------- |
| Tiny download   | `appSizeMB` (`du` of `build/Lamina.app`)          | whole MB             |
| Opens instantly | `windowSeconds`: launch to a full-size window     | tenths of a second   |
| Light on memory | `idleMemoryMB`: footprint 3 s after the window    | whole MB             |

The record also keeps `finishedLaunchingSeconds`, `projectOpenSeconds` and `projectMemoryMB` (the demo project open),
which the website doesn't show but are worth watching.

## Social card

Edit `scripts/og-image.html` and re-render with the command in its header comment (headless Chrome at 2x, then JPEG).

## Checking the website

Headless Chrome renders it without opening a window. It won't go narrower than a 500 px viewport, so check phone width
inside an iframe:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --hide-scrollbars --blink-settings=preferredColorScheme=1 --window-size=1440,2600 \
  --screenshot=/tmp/site.png "file://$PWD/web/index.html"   # preferredColorScheme=0 for dark
echo "<iframe src=\"file://$PWD/web/index.html\" style=\"width:390px;height:2400px;border:0\"></iframe>" > /tmp/phone.html
"$CHROME" --headless=new --hide-scrollbars --allow-file-access-from-files --window-size=500,2400 \
  --screenshot=/tmp/phone.png "file:///tmp/phone.html"
```
