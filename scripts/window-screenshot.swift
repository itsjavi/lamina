// Captures the windows of a running app without activating it (the agents' Dev build), for the README and website
// screenshots (brand/README.md). By default one PNG per document window; with --panels, the document window with its
// floating panels (Camera Raw, filter and adjustment dialogs, Layer Style…) drawn over it where they sit, as one PNG. A
// panel of an app in the background is off screen but can still be captured. --pid picks one copy when several run.
//   swift scripts/window-screenshot.swift "Lamina Dev" /private/tmp/shot [title-substring] [--panels] [--pid <pid>]
import AppKit

var args = Array(CommandLine.arguments.dropFirst())
let withPanels = args.contains("--panels")
args.removeAll { $0 == "--panels" }
var pid: Int?
if let index = args.firstIndex(of: "--pid"), index + 1 < args.count {
    pid = Int(args[index + 1])
    args.removeSubrange(index...index + 1)
}
guard args.count >= 2 else {
    print("usage: window-screenshot <owner> <out-prefix> [title] [--panels] [--pid <pid>]")
    exit(64)
}
let owner = args[0], prefix = args[1], titleFilter = args.count > 2 ? args[2] : nil

struct Window { let id: Int; let title: String; let bounds: CGRect; let layer: Int }
let windows: [Window] = (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []).compactMap { info in
    guard info[kCGWindowOwnerName as String] as? String == owner,
          pid.map({ info[kCGWindowOwnerPID as String] as? Int == $0 }) ?? true, let id = info[kCGWindowNumber as String] as? Int,
          let raw = info[kCGWindowBounds as String] as? [String: Double] else { return nil }
    let bounds = CGRect(x: raw["X"] ?? 0, y: raw["Y"] ?? 0, width: raw["Width"] ?? 0, height: raw["Height"] ?? 0)
    return Window(id: id, title: info[kCGWindowName as String] as? String ?? "", bounds: bounds, layer: info[kCGWindowLayer as String] as? Int ?? 0)
}

func capture(_ window: Window, to path: String) throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-l", String(window.id), "-o", "-x", path]
    try task.run()
    task.waitUntilExit()
}
func image(_ path: String) -> CGImage? {
    CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
}

let documents = windows.filter { window in
    window.layer == 0 && window.bounds.width > 200 && !window.title.isEmpty
        && (titleFilter.map { window.title.contains($0) } ?? true)
}
guard !documents.isEmpty else { print("no windows for \(owner)"); exit(1) }
for (index, document) in documents.enumerated() {
    let out = index == 0 ? "\(prefix).png" : "\(prefix)-\(index).png"
    try capture(document, to: out)
    let panels = withPanels ? windows.filter { $0.layer > 0 && $0.bounds.width > 100 && $0.bounds.intersects(document.bounds) } : []
    if !panels.isEmpty, let base = image(out) {
        let scale = CGFloat(base.width) / document.bounds.width
        let context = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        for panel in panels {
            let path = NSTemporaryDirectory() + "panel-\(panel.id).png"
            try capture(panel, to: path)
            guard let picture = image(path) else { continue }
            // Screen points from the top-left → this image's pixels from the bottom-left.
            let frame = CGRect(x: (panel.bounds.minX - document.bounds.minX) * scale,
                               y: CGFloat(base.height) - (panel.bounds.maxY - document.bounds.minY) * scale,
                               width: CGFloat(picture.width), height: CGFloat(picture.height))
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 40 * scale, color: CGColor(gray: 0, alpha: 0.5))
            context.draw(picture, in: frame)
            context.restoreGState()
        }
        let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
    }
    print("\(out)\t\(document.title)\t\(Int(document.bounds.width))x\(Int(document.bounds.height))\t\(panels.map(\.title))")
}
