# Compositor

Adobe Photoshop costs too much and tools like GIMP don’t feel familiar enough for me to stay in flow. That’s why I built Compositor.

The goal was to create a full-featured image editor that is completely free and open source. I used to use Photoshop for compositing and post-processing, so Compositor is built around that workflow - with the tools needed to create a pixel-perfect final image.

Because it’s open source, you can download the source and add, remove, or modify any feature to fit your workflow.

> This is a fork of [robbietilton/Compositor](https://github.com/robbietilton/Compositor), built as a Swift package
> (no Xcode project). Its builds have their own identity (`com.itsjavi.compositor`) and update feed
> (`downloads.itsjavi.com/compositor`), so they install and update apart from upstream's app.

## Installation

### Download
The upstream app: get Compositor from [robbietilton.com/compositor](https://robbietilton.com/compositor), or download the latest release directly from [GitHub Releases](https://github.com/robbietilton/Compositor/releases/latest).

### Homebrew

```sh
brew install --cask robbietilton-compositor
```

## Features

### Layers
- Layers and folders, with opacity and Photoshop's full set of blend modes in its order — a folder's opacity dims everything inside it
- Layer masks: paint, fill, invert, blur and feather them anywhere on the canvas, past the layer's own pixels; link or unlink them to transform a mask on its own
- Clipping masks and folder masks
- Adjustment layers: Hue/Saturation, Levels, Curves, Exposure, Gradient Map, Grain, Black & White, Color Balance, Invert, Gaussian Blur, Motion Blur and Noise
- Layer effects: Stroke, Drop Shadow, Color Overlay, Inner Shadow, Outer Glow and Inner Glow, rendered on the GPU and editable at any time
- Merge Down, Merge Layers and Merge Group (⌘E), Merge Visible and Flatten Image
- Apply Layer Mask, Copy and Paste Layer Style, and Show/Hide All Other Layers
- Duplicate, rename inline, reorder and nest by drag and drop; Option-drag to duplicate; a right-click menu in the Layers panel
- Copy and paste whole layers and folders (⌘C/⌘V with no selection), within a project or between projects, or drag them between projects

### Transform
- Non-destructive move, scale, rotate and flip — images keep their full resolution however small you make them
- Free distort (⌘-drag a handle), with Shift to lock to an axis
- Transform several layers, or a whole folder, together
- Snapping to canvas and layer edges and centers, with guides
- Exact values for position, size, scale and angle, stepped with the arrow keys
- Flip Layer and Flip Canvas, horizontal and vertical
- Align and Distribute layers by the pixels they show, to each other, the selection or the canvas, from the Move tool's bar or the Layer menu

### Selections
- Rectangle and Ellipse Marquee, Freehand and Polygonal Lasso, and the Magic tool — Wand selects by color, Object traces whatever you click (Tab switches)
- Select Subject, and Expand, Contract and Feather on any selection
- Add to and subtract from selections, move the outline, or move and duplicate the pixels inside
- Edit › Stroke: a line along the selection's outline, inside, centered or outside, in the foreground or background color, on pixels or masks
- Load a layer's pixels or a mask as a selection, or add it to, subtract it from or intersect it with the selection
- Content-Aware Fill, which can also extend an image past its edges

### Painting and retouching
- Brush with size, hardness, opacity and smoothing, in Paint or Erase mode (B and E), and Shift for straight lines
- Spot Healing Brush (content-aware)
- Clone Stamp, aligned or not, sampling one layer or all of them
- Blur tool, on pixels or masks
- Gradient tool and Shape tool (rectangles, rounded rectangles, ellipses and lines), which stay editable rather than being rasterized
- Type tool (T): inline multiline editing in draggable, resizable paragraph boxes; font, size, color, alignment and spacing in the tool header; transform text and use it as a clipping mask
- Eyedropper and a full color picker

### Adjustments and filters
- Camera Raw filter: light, color, curves, color mixer, color grading, detail, optics and geometry, in a panel beside the canvas; each section resets to its defaults from its header, and settings can be saved as named presets
- Levels (with Auto), Curves, Hue/Saturation, Exposure, Gradient Map, Grain, Black & White, Color Balance and Invert
- Gaussian Blur and Motion Blur that spread past a layer's edges
- Add Noise, Vignette, Bloom / Glow, Tonal Contrast, Lens Correction and Remove Background
- Unsharp Mask (Amount, Radius, Threshold) and High Pass
- Live previews, limited to the selection when there is one
- Last Filter (⌘F) runs the last filter again with the same settings

### Canvas and files
- Multiple projects in tabs
- File > New from Clipboard (⌥⌘N) opens the copied image, or image files copied in Finder, as a new project
- Rulers (⌘R), guides dragged from them, a layout grid with adjustable spacing and subdivisions, and Snap To for guides, grid, layers and document bounds
- Crop with snapping, ratios including 3:4, 9:16 and any you type in (they are remembered), and Option for symmetric cropping; with a selection, the crop starts at it
- Canvas Size, Image Size and Trim; Image Rotation (90° either way and 180°), which turns layer pixels losslessly
- Sharp high-quality downsampling when zoomed out, and a pixel grid when zoomed in
- Import JPEG, PNG, HEIC, WebP, TIFF, SVG, camera RAW (with a develop step first) and Photoshop PSD and PSB (8-bit RGB; not CMYK). Photoshop folders, masks, blend modes, fill rectangles/ellipses, and simple horizontal text stay editable; other vectors and vertical text become pixels. A conversion report is shown before anything is applied.
- Large documents: the memory budget scales with your Mac, and a Photoshop file too big to open has its layers cropped to the canvas instead
- Export JPEG with a live preview (⇧⌥⌘S), or PNG, JPEG, HEIC, AVIF, WebP, TIFF or PDF with File > Export As… (quality for the lossy formats; only the formats your Mac can write are listed); Copy Merged
- Keep working while a project saves
- A History panel beside Layers lists every undo step by name; click one to go back or forward to it
- Photoshop-style keyboard shortcuts throughout, remappable or removable in Edit > Keyboard Shortcuts, where any menu command can also be given one
- Drag a number's label to scrub its value, as in Photoshop
- Automatic updates, signed and notarized

### Works with AI agents
- AI agents and scripts can build and edit projects directly: a `.comp` is a folder of PNG layers and a manifest, and an open project updates live as it's written. See [Writing Compositor projects](docs/writing-comp-files.md)

## Requirements

- macOS 26.0 or later on a Mac with Apple silicon
- Xcode 26 or later (to build from source: Swift 6.2, and actool for the icon)

## Building

```bash
make app        # build/Compositor.app (release, with the updater)
make dev        # build/Compositor Dev.app (debug, its own id, sandbox container and prefs, no updater)
make install    # copy the release app to /Applications
make test       # unit tests (swift test)
```

The app is App Sandboxed: its preferences and recent projects live in `~/Library/Containers/com.itsjavi.compositor`
(`….dev` for the Dev build).

## Releasing

Files go to the `compositor/` folder of the downloads bucket (downloads.itsjavi.com), like the other apps.

```bash
make release                  # build/release: Compositor.app, zip, DMG, SHA256SUMS
make appcast                  # signs the zip, writes build/appcast/appcast.xml
make bump V=patch PUSH=1      # bump VERSION, tag vX.Y.Z on main, push → release workflow
```

`make release` signs and notarizes when `DEVELOPER_ID` and `NOTARY_PROFILE` are set (see `scripts/release.sh`);
otherwise it builds ad-hoc and lists what's missing.

Sparkle's private EdDSA key lives in the login Keychain under the account `compositor` (never in the repo); the public
key is `Resources/SparklePublicKey.txt`. Create them once with:

```bash
swift package resolve && .build/artifacts/sparkle/Sparkle/bin/generate_keys --account compositor
```

and save the printed public key to `Resources/SparklePublicKey.txt`. Back the private key up (and export it for CI)
with `generate_keys --account compositor -x compositor-sparkle.key`. Losing it means installed copies can't accept
updates signed with a new key. `make appcast` refuses a key that doesn't match the app's public key. Upload the zip
first, then `appcast.xml`.

CI (`.github/workflows/`): `ci.yml` runs the tests; `release.yml` runs on `vX.Y.Z` tags and uses these optional secrets
in a `release` environment: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`,
`APPLE_TEAM_ID`, `SPARKLE_PRIVATE_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`.

## License

MIT — see [LICENSE](LICENSE).
