import CoreGraphics

/// A straight sRGB color, 0–1 per channel.
package struct PaletteColor: Equatable, Sendable {
    package var red: CGFloat
    package var green: CGFloat
    package var blue: CGFloat
    package static let black = PaletteColor(red: 0, green: 0, blue: 0)
    package static let white = PaletteColor(red: 1, green: 1, blue: 1)
    package init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red; self.green = green; self.blue = blue
    }
}
