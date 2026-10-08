#!/usr/bin/env swift
// Draws the app icon's layers (Resources/AppIcon.icon/Assets/*.png): three stacked sheets, a red doodle
// painted on the top one, and the brush that painted it.
//   swift scripts/app-icon.swift [Resources/AppIcon.icon]
// Each layer is a flat shape on a transparent 1024 pt canvas. icon.json (the warm gradient fill, glass,
// shadow and the dark appearance) lists them by file name; edit it by hand or in Icon Composer, since
// this script only rewrites Assets/. macOS adds the Liquid Glass, highlights and shadows when it renders.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icon"
let canvas: CGFloat = 1024

// Layout, in canvas points (AppKit: origin bottom-left). The artwork spans about the middle two thirds
// (17–84%), so the system mask, glass and shadow keep their margin. The stack sits left of center to
// balance the brush, which rises to the upper right from the top sheet.
let sheetHalfWidth: CGFloat = 300
let sheetHalfHeight: CGFloat = 172  // an isometric-looking rhombus
let sheetStep: CGFloat = 84         // vertical offset between stacked sheets
let sheetCorner: CGFloat = 40
let topSheet = NSPoint(x: 487, y: 512)  // center of the top sheet

// The doodle follows a smooth curve through these points, given in the top sheet's own plane (centered
// on it, before the isometric squash; the sheet is the diamond |x| + |y| < 300 there), so it lies flat on
// the sheet. It starts in a thin tail and ends, at full width, under the bristles.
let doodle: [NSPoint] = [
    NSPoint(x: -235, y: -20), NSPoint(x: -150, y: 80), NSPoint(x: -40, y: -60), NSPoint(x: 75, y: 0),
]
let doodleWidth: CGFloat = 72
let paint = "#F2512E"            // the doodle and the paint on the bristles
let brushLength: CGFloat = 410
let brushWidth: CGFloat = 110    // the ferrule's; the bristles bulge a little wider, the handle tapers
let brushAngle: CGFloat = 50     // degrees; the brush points down-left at the end of the doodle

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

/// A point in the top sheet's plane, on the canvas.
func onSheet(_ p: NSPoint) -> NSPoint {
    NSPoint(x: topSheet.x + p.x, y: topSheet.y + p.y * sheetHalfHeight / sheetHalfWidth)
}

/// The point at `t` (0 at the first point, 1 at the last) on the Catmull-Rom curve through `points`.
func curve(_ points: [NSPoint], _ t: CGFloat) -> NSPoint {
    let n = points.count - 1
    let s = min(t * CGFloat(n), CGFloat(n) - 0.0001)
    let i = Int(s), u = s - CGFloat(i)
    let p0 = points[max(i - 1, 0)], p1 = points[i], p2 = points[i + 1], p3 = points[min(i + 2, n)]
    func blend(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
        b + 0.5 * u * ((c - a) + u * ((2 * a - 5 * b + 4 * c - d) + u * (3 * b - a - 3 * c + d)))
    }
    return NSPoint(x: blend(p0.x, p1.x, p2.x, p3.x), y: blend(p0.y, p1.y, p2.y, p3.y))
}

// The bristles' tip rests on the wet paint a little before the doodle's end, which hides under the bristles.
let doodleEnd = onSheet(doodle[doodle.count - 1]), tipInset = doodleWidth * 0.4
let brushTip = NSPoint(x: doodleEnd.x - tipInset * cos(brushAngle * .pi / 180),
                       y: doodleEnd.y - tipInset * sin(brushAngle * .pi / 180))

/// The doodle, stamped as round dabs along its curve and filled as one shape: a tail that swells over
/// the first 30% of the stroke, then full width up to the brush.
func drawDoodle() {
    let dabs = NSBezierPath()
    for i in 0...800 {
        let t = CGFloat(i) / 800
        let c = onSheet(curve(doodle, t)), r = doodleWidth / 2 * pow(min(1, t / 0.3), 0.7)
        dabs.appendOval(in: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    color(paint).setFill()
    dabs.fill()
}

/// A sheet of the stack: a rhombus with rounded corners, filled with a gentle top-to-bottom gradient.
func sheet(centerY: CGFloat, _ top: String, _ bottom: String, detail: () -> Void = {}) -> NSBitmapImageRep {
    layer {
        let c = NSPoint(x: topSheet.x, y: centerY)
        let path = roundedPolygon([
            NSPoint(x: c.x - sheetHalfWidth, y: c.y), NSPoint(x: c.x, y: c.y + sheetHalfHeight),
            NSPoint(x: c.x + sheetHalfWidth, y: c.y), NSPoint(x: c.x, y: c.y - sheetHalfHeight),
        ], radius: sheetCorner)
        NSGradient(colors: [color(top), color(bottom)])!.draw(in: path, angle: -90)
        detail()
    }
}

/// The brush, drawn along +x from its tip at the origin and then rotated into place: bristles dipped in
/// the doodle's red, a metal ferrule and a round handle tapering to a rounded end. Like a cylinder lit
/// from above, each part's lower facet is a shade darker.
let brush = layer {
    let w = brushWidth, bristles = w * 1.3, ferrule = w * 0.75, handleEnd = w * 0.3
    let transform = NSAffineTransform()
    transform.translateX(by: brushTip.x, yBy: brushTip.y)
    transform.rotate(byDegrees: brushAngle)
    transform.concat()

    func fill(_ path: NSBezierPath, _ light: String, _ dark: String) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        color(light).setFill()
        path.fill()
        color(dark).setFill()
        NSRect(x: -w, y: -w, width: brushLength + 2 * w, height: w * 0.83).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: bristles + ferrule - 4, y: w * 0.42))
    handle.line(to: NSPoint(x: brushLength - handleEnd, y: handleEnd))
    handle.appendArc(withCenter: NSPoint(x: brushLength - handleEnd, y: 0), radius: handleEnd,
                     startAngle: 90, endAngle: -90, clockwise: true)
    handle.line(to: NSPoint(x: bristles + ferrule - 4, y: -w * 0.42))
    handle.close()
    fill(handle, "#A8683F", "#8C5233")  // wood

    // Bristles: a flame from the ferrule to a soft point, the front half wet with paint.
    let hair = NSBezierPath()
    hair.move(to: NSPoint(x: bristles + 4, y: w * 0.46))
    hair.curve(to: .zero, controlPoint1: NSPoint(x: bristles * 0.4, y: w * 0.64),
               controlPoint2: NSPoint(x: bristles * 0.1, y: w * 0.26))
    hair.curve(to: NSPoint(x: bristles + 4, y: -w * 0.46), controlPoint1: NSPoint(x: bristles * 0.1, y: -w * 0.26),
               controlPoint2: NSPoint(x: bristles * 0.4, y: -w * 0.64))
    hair.close()
    fill(hair, "#E9C89C", "#D4AD7E")
    NSGraphicsContext.saveGraphicsState()
    hair.addClip()
    fill(NSBezierPath(ovalIn: NSRect(x: -bristles * 0.6, y: -w, width: bristles * 1.25, height: 2 * w)),
         paint, "#D63D22")
    NSGraphicsContext.restoreGraphicsState()

    let collar = NSBezierPath(roundedRect: NSRect(x: bristles, y: -w / 2, width: ferrule, height: w),
                              xRadius: w * 0.1, yRadius: w * 0.1)
    fill(collar, "#EFE9E3", "#C9BDB2")  // the ferrule, in warm silver
}

// icon.json lists these front to back: the brush first, the bottom sheet last.
let layers: [(String, NSBitmapImageRep)] = [
    ("brush", brush),
    ("sheet-top", sheet(centerY: topSheet.y, "#FFFFFF", "#FFF3E8", detail: drawDoodle)),
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
