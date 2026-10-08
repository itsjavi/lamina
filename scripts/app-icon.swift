#!/usr/bin/env swift
// Draws the app icon's layers (Resources/AppIcon.icon/Assets/*.png): three stacked sheets and a pencil.
//   swift scripts/app-icon.swift [Resources/AppIcon.icon]
// Each layer is a flat shape on a transparent 1024 pt canvas. icon.json (the warm gradient fill, glass,
// shadow and the dark appearance) lists them by file name; edit it by hand or in Icon Composer, since
// this script only rewrites Assets/. macOS adds the Liquid Glass, highlights and shadows when it renders.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icon"
let canvas: CGFloat = 1024

// Layout, in canvas points (AppKit: origin bottom-left). The artwork spans about the middle two thirds
// (17–84%), so the system mask, glass and shadow keep their margin. The stack sits left of center to
// balance the pencil, which rises to the upper right from the top sheet.
let sheetHalfWidth: CGFloat = 300
let sheetHalfHeight: CGFloat = 172  // an isometric-looking rhombus
let sheetStep: CGFloat = 84         // vertical offset between stacked sheets
let sheetCorner: CGFloat = 40
let topSheet = NSPoint(x: 487, y: 512)  // center of the top sheet
let pencilTip = NSPoint(x: 507, y: 522)
let pencilLength: CGFloat = 400
let pencilWidth: CGFloat = 144
let pencilAngle: CGFloat = 45       // degrees; the pencil points down-left at the top sheet

func color(_ hex: String) -> NSColor {
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

/// One layer on a transparent canvas. Draw flat shapes only: the system adds glass, highlights and shadows.
func layer(_ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// A closed polygon with every corner rounded to `radius`.
func roundedPolygon(_ points: [NSPoint], radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let last = points[points.count - 1]
    path.move(to: NSPoint(x: (last.x + points[0].x) / 2, y: (last.y + points[0].y) / 2))
    for (i, point) in points.enumerated() {
        path.appendArc(from: point, to: points[(i + 1) % points.count], radius: radius)
    }
    path.close()
    return path
}

/// A sheet of the stack: a rhombus with rounded corners, filled with a gentle top-to-bottom gradient.
func sheet(centerY: CGFloat, _ top: String, _ bottom: String) -> NSBitmapImageRep {
    layer {
        let c = NSPoint(x: topSheet.x, y: centerY)
        let path = roundedPolygon([
            NSPoint(x: c.x - sheetHalfWidth, y: c.y), NSPoint(x: c.x, y: c.y + sheetHalfHeight),
            NSPoint(x: c.x + sheetHalfWidth, y: c.y), NSPoint(x: c.x, y: c.y - sheetHalfHeight),
        ], radius: sheetCorner)
        NSGradient(colors: [color(top), color(bottom)])!.draw(in: path, angle: -90)
    }
}

/// The pencil, drawn along +x from its tip at the origin and then rotated into place: graphite point,
/// wooden cone, a two-tone body (its lower facet a shade darker) and an eraser end.
let pencil = layer {
    let w = pencilWidth, length = pencilLength, cone = w * 1.15, point = cone * 0.4, eraser = w * 0.62
    let transform = NSAffineTransform()
    transform.translateX(by: pencilTip.x, yBy: pencilTip.y)
    transform.rotate(byDegrees: pencilAngle)
    transform.concat()

    let outline = roundedPolygon([
        NSPoint(x: 0, y: 0), NSPoint(x: cone, y: w / 2), NSPoint(x: length, y: w / 2),
        NSPoint(x: length, y: -w / 2), NSPoint(x: cone, y: -w / 2),
    ], radius: w * 0.16)
    outline.addClip()
    color("#FFE6CC").setFill()  // bare wood
    NSRect(x: -w, y: -w, width: cone + w, height: 2 * w).fill()
    color("#4A3029").setFill()  // graphite
    NSRect(x: -w, y: -w, width: point + w, height: 2 * w).fill()
    color("#F2512E").setFill()  // body
    NSRect(x: cone, y: -w / 2, width: length - cone, height: w).fill()
    color("#D63D22").setFill()  // body's lower facet
    NSRect(x: cone, y: -w / 2, width: length - cone, height: w / 3).fill()
    color("#E8606E").setFill()  // eraser: a deep rose, so the pencil keeps its length on the fill at 32 pt
    NSRect(x: length - eraser, y: -w / 2, width: eraser, height: w).fill()
}

// icon.json lists these front to back: the pencil first, the bottom sheet last.
let layers: [(String, NSBitmapImageRep)] = [
    ("pencil", pencil),
    ("sheet-top", sheet(centerY: topSheet.y, "#FFFFFF", "#FFF3E8")),
    ("sheet-middle", sheet(centerY: topSheet.y - sheetStep, "#FFF1E3", "#FFE6D2")),
    ("sheet-bottom", sheet(centerY: topSheet.y - 2 * sheetStep, "#FFE3CC", "#FFD6B8")),
]

let assets = URL(fileURLWithPath: output).appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: assets)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
for (name, rep) in layers {
    try rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("\(name).png"))
}
print("Wrote \(layers.count) layers to \(assets.path)")
