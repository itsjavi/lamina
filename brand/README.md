# Public presentation: README and screenshots

Everything people see before installing Lamina. Keep it in sync with the app: when a feature ships or the UI changes
substantially, update the affected pieces in the same task.

| What        | Where                     | Shows                                                              |
| ----------- | ------------------------- | ------------------------------------------------------------------ |
| README      | `README.md`               | Pitch (decision-7), why, feature list, screenshot table, building |
| Icon        | `web/assets/icon.png`     | 512 px render of `Resources/AppIcon.icon` (`scripts/app-icon.swift`) |
| Screenshots | `web/assets/*.webp`       | Used by the README (and the website, TASK-39)                      |

## What to update

| Change                                   | README          | Screenshots                          |
| ---------------------------------------- | --------------- | ------------------------------------ |
| New user-facing feature                  | feature bullet  | add one if it is visible and notable |
| Substantial UI change (layout, toolbar…) | if text changed | recapture affected shots             |
| Feature removed or renamed               | remove / rename | recapture                            |

Never leave published copy or screenshots showing UI that no longer exists. If a change needs none of this, say why in
the task notes.

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
