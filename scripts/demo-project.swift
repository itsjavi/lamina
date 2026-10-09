// Writes the demo project the README and website screenshots are taken from: a sunset built from ordinary layers (a
// gradient sky, a sun with an outer glow, two hill silhouettes, a lake faded by a mask, a live text title in a group
// and a Curves grade), so the Layers panel shows most of what a project can hold. It writes the package by hand, as
// docs/writing-lamina-projects.md describes, so it also checks that guide.
//   swift scripts/demo-project.swift "/private/tmp/lamina-demo/Golden Hour.lam"
import AppKit
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 2 else { print("usage: demo-project.swift <out.lam>"); exit(64) }
let package = URL(fileURLWithPath: arguments[1])
let images = package.appendingPathComponent("images")
try? FileManager.default.removeItem(at: package)
try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

let width = 2400, height = 1500
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
/// An RGBA (or, for masks, gray) bitmap drawn top-left first, written as `<id>.png` or `<id>.mask.png`.
func png(_ id: UUID, _ w: Int, _ h: Int, mask: Bool = false, _ draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: mask ? CGColorSpaceCreateDeviceGray() : srgb,
                            bitmapInfo: mask ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(h))
    context.scaleBy(x: 1, y: -1)
    draw(context)
    let url = images.appendingPathComponent(id.uuidString + (mask ? ".mask.png" : ".png"))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
func gradient(_ context: CGContext, _ stops: [(CGFloat, CGColor)], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: srgb, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
/// A ridge line across the full width, filled down to the bottom of its box.
func hills(_ context: CGContext, w: Int, h: Int, peaks: [(CGFloat, CGFloat)], fill: CGColor) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: CGFloat(h)))
    path.addLine(to: CGPoint(x: 0, y: peaks[0].1))
    for index in 1..<peaks.count {
        let (x0, y0) = peaks[index - 1], (x1, y1) = peaks[index]
        path.addCurve(to: CGPoint(x: x1, y: y1), control1: CGPoint(x: (x0 + x1) / 2, y: y0), control2: CGPoint(x: (x0 + x1) / 2, y: y1))
    }
    path.addLine(to: CGPoint(x: CGFloat(w), y: CGFloat(h)))
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(fill)
    context.fillPath()
}
func transform(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> [String: Any] {
    ["origin": [x, y], "size": [w, h], "rotation": 0, "flipX": false, "flipY": false, "sampling": "High quality"]
}
func layer(_ id: UUID, _ name: String, _ frame: [String: Any], image: Bool = true, extra: [String: Any] = [:]) -> [String: Any] {
    var record: [String: Any] = ["id": id.uuidString, "name": name, "isVisible": true, "isGroup": false, "opacity": 1,
                                 "blendMode": "Normal", "transform": frame]
    if image { record["imageFile"] = id.uuidString + ".png" }
    return record.merging(extra) { $1 }
}

let sky = UUID(), sun = UUID(), farHills = UUID(), nearHills = UUID(), lake = UUID(), group = UUID(), title = UUID(), grade = UUID()

try png(sky, width, height) { gradient($0, [(0, color(0x1F2556)), (0.45, color(0x8C3F6E)), (0.75, color(0xF0865A)), (1, color(0xFFC77D))],
                                      from: .zero, to: CGPoint(x: 0, y: 1080)) }
let sunSide = 420
try png(sun, sunSide, sunSide) { context in
    let gradient = CGGradient(colorsSpace: srgb, colors: [color(0xFFF4C2), color(0xFFD27A), color(0xFFB14E)] as CFArray, locations: [0, 0.6, 1])!
    let center = CGPoint(x: sunSide / 2, y: sunSide / 2)
    context.addEllipse(in: CGRect(x: 0, y: 0, width: sunSide, height: sunSide))
    context.clip()
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: CGFloat(sunSide) / 2, options: [])
}
try png(farHills, width, 620) { hills($0, w: width, h: 620, peaks: [(0, 300), (420, 140), (900, 330), (1400, 120), (1900, 290), (2400, 170)],
                                       fill: color(0x7B3D66)) }
try png(nearHills, width, 560) { hills($0, w: width, h: 560, peaks: [(0, 210), (600, 380), (1150, 160), (1750, 400), (2400, 230)],
                                        fill: color(0x351C3B)) }
try png(lake, width, 420) { gradient($0, [(0, color(0xFFB06A)), (0.35, color(0xC2566E)), (1, color(0x24163A))], from: .zero, to: CGPoint(x: 0, y: 420))
    // Glints on the water.
    for row in 0..<14 {
        let y = CGFloat(30 + row * 26), spread = CGFloat(220 - row * 12)
        $0.setFillColor(color(0xFFE3A3, 0.55 - CGFloat(row) * 0.035))
        $0.fill(CGRect(x: 1450 - spread / 2, y: y, width: spread, height: 5))
    }
}
// The mask fades the water in from nothing, so the hills meet it without an edge.
try png(lake, width, 420, mask: true) { gradient($0, [(0, color(0x000000)), (0.3, color(0xFFFFFF)), (1, color(0xFFFFFF))], from: .zero, to: CGPoint(x: 0, y: 420)) }

// The title is live text: its PNG is what the text draws, at the size the style gives it.
let style: [String: Any] = ["content": "Golden hour", "fontName": "AvenirNext-DemiBold", "fontSize": 190, "red": 1, "green": 0.97, "blue": 0.9,
                            "alignment": "Left", "tracking": 2, "leading": 0]
let font = NSFont(name: "AvenirNext-DemiBold", size: 190) ?? .boldSystemFont(ofSize: 190)
let text = NSAttributedString(string: "Golden hour", attributes: [.font: font, .kern: 2,
                                                                 .foregroundColor: NSColor(srgbRed: 1, green: 0.97, blue: 0.9, alpha: 1)])
let padding = 12.0, textSize = text.size()
let titleWidth = Int((textSize.width + padding * 2).rounded(.up)), titleHeight = Int((190 * 1.2 + padding * 2).rounded(.up))
try png(title, titleWidth, titleHeight) { context in
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    text.draw(at: CGPoint(x: padding, y: padding))
    NSGraphicsContext.restoreGraphicsState()
}

let identity = ["black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255]
let curves: [String: Any] = [
    "kind": "Curves", "hue": 0, "saturation": 0, "lightness": 0, "colorize": false,
    "levels": ["channel": "RGB", "ranges": Array(repeating: identity, count: 4)],
    "curves": ["channel": "RGB", "channels": [
        [["x": 0, "y": 0], ["x": 128, "y": 140], ["x": 255, "y": 255]],
        [["x": 0, "y": 0], ["x": 120, "y": 138], ["x": 255, "y": 255]],
        [["x": 0, "y": 0], ["x": 255, "y": 255]],
        [["x": 0, "y": 0], ["x": 120, "y": 104], ["x": 255, "y": 240]]]],
]
let canvas = transform(0, 0, width, height)
let manifest: [String: Any] = [
    "format": "com.itsjavi.lamina.project", "version": 11, "colorSpace": "sRGB", "resolution": 144,
    "documentID": UUID().uuidString, "width": width, "height": height, "activeLayerID": title.uuidString,
    "layers": [
        layer(sky, "Sky", canvas),
        layer(sun, "Sun", transform(1240, 600, sunSide, sunSide),
              extra: ["effects": ["outerGlow": ["size": 160, "red": 1, "green": 0.8, "blue": 0.45, "opacity": 0.85]]]),
        layer(farHills, "Far hills", transform(0, 700, width, 620), extra: ["opacity": 0.9]),
        layer(nearHills, "Near hills", transform(0, 780, width, 560)),
        layer(lake, "Lake", transform(0, 1080, width, 420), extra: ["maskFile": lake.uuidString + ".mask.png", "maskEnabled": true]),
        layer(group, "Title", canvas, image: false, extra: ["isGroup": true]),
        layer(title, "Golden hour", transform(180, 170, titleWidth, titleHeight), extra: [
            "parentID": group.uuidString, "text": style,
            "effects": ["shadow": ["angle": 90, "distance": 10, "blur": 30, "red": 0.12, "green": 0.04, "blue": 0.15, "opacity": 0.55]]]),
        layer(grade, "Warm grade", canvas, image: false, extra: ["adjustment": curves, "opacity": 0.8]),
    ],
]
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: package.appendingPathComponent("manifest.json"))
print(package.path)
