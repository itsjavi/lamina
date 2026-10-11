import AppKit
import SwiftUI

/// The canvas's transparency checkerboard for previews in dialogs (the filter preview, Export As): 10-point squares
/// of two fixed grays, the lighter one in the top-left corner, as `EditorCanvas` draws it. Fixed in both appearances
/// (DESIGN.md, Colors and surfaces). One 20-point tile, repeated, so it costs the same however far a preview zooms.
enum Checkerboard {
    static let square: CGFloat = 10
    static let light = NSColor(white: 0.35, alpha: 1)
    static let dark = NSColor(white: 0.30, alpha: 1)

    /// Two squares on a side, drawn at whatever resolution the screen needs.
    static let tile = NSImage(size: NSSize(width: 2 * square, height: 2 * square), flipped: true) { _ in
        dark.setFill()
        NSRect(x: 0, y: 0, width: 2 * square, height: 2 * square).fill()
        light.setFill()
        NSRect(x: 0, y: 0, width: square, height: square).fill()
        NSRect(x: square, y: square, width: square, height: square).fill()
        return true
    }

    static var image: Image { Image(nsImage: tile) }

    /// Fills `area` of a canvas with the checkerboard, its squares counted from `origin`.
    static func fill(_ area: CGRect, from origin: CGPoint, in context: inout GraphicsContext) {
        context.fill(Path(area), with: .tiledImage(image, origin: origin))
    }

    /// The checkerboard filling a view from its top-left corner, as a background behind an image.
    static var view: some View { image.resizable(resizingMode: .tile) }
}
