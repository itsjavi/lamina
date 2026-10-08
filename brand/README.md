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
defaults write "$P" "NSWindow Frame editor" "36 25 1440 900 0 0 1512 949 "   # window size, before launching
open -g -n -a "$PWD/build/Lamina Dev.app" "/private/tmp/lamina-demo/Golden Hour.lam"
swift scripts/window-screenshot.swift "Lamina Dev" /private/tmp/shot           # the document window
swift scripts/window-screenshot.swift "Lamina Dev" /private/tmp/shot --panels  # with its floating panels over it
```

Current shots (window 1440×874 points):

| File              | Setup                                                                       |
| ----------------- | --------------------------------------------------------------------------- |
| `screenshot.webp` | The demo as it opens: the "Golden hour" title selected with the Move tool    |
| `camera-raw.webp` | Sky layer selected, Filter › Camera Raw Filter…, `--panels`                  |
| `curves.webp`     | Warm grade selected, Layer › Edit Adjustment…, `--panels`                    |
| `oil-painting.webp` | `scripts/oil-painting-project.swift`'s seascape as it opens, 2400 wide. Showcases agent painting (strokes are generated outside the app until the agent painting milestone lands) |

Selecting layers and choosing menu commands in the background takes an agent with background app control (clicks on
the Layers panel, menu commands by title). Convert and size them like the existing files:

```bash
cwebp -q 86 -m 6 -resize 2400 0 shot.png -o web/assets/screenshot.webp   # hero: 2400 wide
cwebp -q 86 -m 6 -resize 1600 0 shot.png -o web/assets/camera-raw.webp   # others: 1600 wide
```

Gotchas:

- The app is always dark, so there is no light variant.
- The last four numbers of the window frame are the screen's visible frame; a window taller than it is shortened.
- Floating panels hide while the app is in the background. `--panels` still captures them, but they can't be clicked:
  quit the Dev build (`pkill -TERM -f "Lamina Dev.app/Contents/MacOS/Lamina"`) and launch it again for the next shot.
- Background windows are never key, so traffic lights look inactive. Acceptable.
- Layer effects open only from the Layers panel's effects menu, which background control can't open; take that one by
  hand if it's wanted.

## Numbers on the website

The strip under the hero states the app's size and launch time; keep both true when the app changes (decision-7 keeps
the size under 50 MB, which the hero badge promises):

| Number          | Today   | How to measure                                                                      |
| --------------- | ------- | ----------------------------------------------------------------------------------- |
| App size        | 23 MB   | `make app && du -sh build/Lamina.app`                                                |
| Launch → window | 0.7 s   | `CONFIG=release scripts/build-app.sh dev && swift scripts/launch-time.swift "build/Lamina Dev.app" 8`: the median "window" time after the first run |

Measured 2026-10-09 on a MacBook Pro with M1 Max and 32 GB (macOS 27): finished launching in 0.25 s, first window
0.72 s (median of the seven runs after the first; the first, right after the build, took 1.07 s). The launches run in
the background and don't take focus. Update the figures and the note under the strip together.

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
