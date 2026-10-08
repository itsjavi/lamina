<p align="center">
  <img src="web/assets/icon.png" width="128" height="128" alt="Lamina app icon">
</p>

<h1 align="center">Lamina</h1>

<p align="center">
  <strong>A simpler Photoshop and Affinity alternative for the Mac.</strong><br>
  Photo editing and compositing without the bloat, the subscription or the sign-up. Open source, ready for agents,
  and under 50 MB.
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#works-with-ai-agents">AI agents</a> ·
  <a href="#building">Building</a> ·
  <a href="LICENSE">MIT License</a>
</p>

<img src="web/assets/screenshot.webp" alt="The Lamina window: a sunset composition on the canvas, its text title selected with transform handles, and the Layers panel with a Curves adjustment, a folder holding a text layer with a drop shadow, a masked lake, hill layers and a sun with an outer glow.">

## Why Lamina

Most image work comes down to the same handful of things: retouch a photo, cut something out, put a few layers
together, add some text, export.

Lamina is built for exactly that: the tools you reach for every day, with the Photoshop shortcuts and layer model you
already know, in a native Mac app under 50 MB, with no subscription and no account. Projects are plain folders of PNG
layers and a manifest, so nothing is locked in, and AI agents can work on them too: through the `lamina` command-line
tool, as an MCP server, or by writing a project while you watch it update. Vector layers are next.

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
- Brush with size, hardness, opacity, flow and smoothing, in Paint, Erase (B and E), Dodge or Burn mode, and Shift for straight lines
- Dodge and Burn lighten or darken the shadows, midtones or highlights by an exposure
- Pen pressure for the Brush's size and opacity, on a graphics tablet
- Brush settings and colors carry over to new documents and later launches
- Spot Healing Brush (content-aware)
- Clone Stamp, aligned or not, sampling one layer or all of them
- Blur tool, on pixels or masks
- Gradient tool and Shape tool (rectangles, rounded rectangles, ellipses and lines), which stay editable rather than being rasterized
- Paint Bucket (Shift-G from the Gradient): fills similar colors by tolerance, contiguous or not, from one layer or all of them, anti-aliased, on pixels or masks
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
- Automatic updates for signed releases

### Works with AI agents
- AI agents and scripts can build and edit projects directly: a `.lam` project is a folder of PNG layers and a manifest, and an open project updates live as it's written. See [Writing Lamina projects](docs/writing-lamina-projects.md)
- They can also drive the running app with the `lamina` command-line tool: list open projects and their layers, select layers, apply filters and adjustment layers with settings, undo, export and render previews. See [The lamina command-line tool](#the-lamina-command-line-tool)

<table>
  <tr>
    <td width="50%"><img src="web/assets/camera-raw.webp" alt="The Camera Raw filter docked beside the canvas, with its histogram, Light and Color sliders and color grading wheels."></td>
    <td width="50%"><img src="web/assets/curves.webp" alt="A Curves adjustment layer being edited in its floating panel over the canvas."></td>
  </tr>
  <tr>
    <td align="center">Camera Raw filter</td>
    <td align="center">Adjustment layers</td>
  </tr>
</table>

## The lamina command-line tool

The app ships `lamina` in its bundle. Put it on your PATH with a symlink:

```bash
ln -s /Applications/Lamina.app/Contents/Helpers/lamina ~/.local/bin/lamina   # any folder on your PATH
```

It controls the app while it's running (it never starts it):

```bash
lamina list-documents                                     # open projects and their layers, with short ids
lamina apply-filter --document 3f2a --layer 9c1b --kind gaussian-blur --settings radius=4
lamina add-adjustment-layer --document 3f2a --kind exposure --settings exposure=0.5,gamma=1.1
lamina export-document --document 3f2a --output ~/Desktop/poster.jpg --quality 0.9
lamina undo --document 3f2a
lamina --help                                             # every command; lamina help <command> for its options
```

Each edit is one undo step in the app, and edits are refused while you're in the middle of something there (typing
text, a transform, an open dialog). Output is text, or JSON with `--json`. `lamina` sends the app Apple Events, so the
first command asks whether the app you run it from (Terminal, your editor, an agent) may control Lamina; that
choice is in System Settings › Privacy & Security › Automation. Only your own processes on this Mac can send commands,
and the app's sandbox entitlements are unchanged: `lamina` itself writes the exported files. With the Dev build
running, use `lamina --dev …` (or the copy inside `build/Lamina Dev.app`).

### As an MCP server

`lamina mcp` offers the same commands as MCP tools over stdio, one tool per command. Register it with your MCP host:

```bash
claude mcp add lamina -- /Applications/Lamina.app/Contents/Helpers/lamina mcp    # Claude Code
codex mcp add lamina -- /Applications/Lamina.app/Contents/Helpers/lamina mcp     # Codex
```

For Claude's desktop app, add `"lamina": {"command": "/Applications/Lamina.app/Contents/Helpers/lamina", "args":
["mcp"]}` under `mcpServers` in its `claude_desktop_config.json`. Add `--dev` after `mcp` to drive the Dev build.

It speaks MCP 2026-07-28 (stateless, with `server/discover`) and, for hosts that still open with `initialize`,
2025-11-25 and earlier. Checked with Claude Code 2.1.288 (2025-11-25 by default, 2026-07-28 with
`MCP_PROTOCOL_NEGOTIATION=auto`) and Codex 0.160.0 (2025-11-25 by default, 2026-07-28 with `--enable mcp_2026_07_28`
and `CODEX_MCP_PROTOCOL_VERSION=2026-07-28` in the server's environment).

## Requirements

- macOS 26 or later on Apple silicon
- Xcode 26 or later to build (Swift 6.2, and actool for the icon)

## Building

There's no release yet; build it from source. Releases will be published on
[GitHub Releases](https://github.com/itsjavi/lamina/releases).

```bash
git clone https://github.com/itsjavi/lamina.git
cd lamina
make install  # builds build/Lamina.app and copies it to /Applications
```

Other targets: `make app` (release build only), `make dev` (a debug build with its own id, sandbox container and
preferences, and no updater), `make test` (unit tests; `make test-ui` also runs the ones that show windows).

The app is App Sandboxed: its preferences and recent projects live in `~/Library/Containers/com.itsjavi.lamina`
(`….dev` for the Dev build). See [AGENTS.md](AGENTS.md) for the project layout, build variants and tests, and
[docs/releasing.md](docs/releasing.md) for publishing a release.

## License

[MIT](LICENSE). Lamina began as a fork of Robbie Tilton's [Compositor](https://github.com/robbietilton/Compositor)
(MIT), and keeps its own project format, identity and update feed.
