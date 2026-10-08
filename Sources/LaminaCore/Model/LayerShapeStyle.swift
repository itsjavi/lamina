import CoreGraphics

package enum ShapeKind: String, CaseIterable, Codable, Sendable {
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    /// The shape filling `rect`. A rectangle's corners round by `cornerRadius`, at most half its shorter
    /// side (so a large radius makes a pill); ellipses ignore it. A line runs corner to corner and is stroked,
    /// not filled (see `linePath`).
    package func path(in rect: CGRect, cornerRadius: CGFloat = 0) -> CGPath {
        if self == .ellipse { return CGPath(ellipseIn: rect, transform: nil) }
        let radius = min(max(0, cornerRadius), rect.width / 2, rect.height / 2)
        guard radius > 0 else { return CGPath(rect: rect, transform: nil) }
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}

/// What a shape layer draws, kept so the shape can be drawn again at a new size.
package struct LayerShapeStyle: Codable, Equatable, Sendable {
    package var kind: ShapeKind
    package var red: CGFloat
    package var green: CGFloat
    package var blue: CGFloat
    /// Document pixels, whatever size the shape is scaled to.
    package var cornerRadius: CGFloat
    /// A line's thickness, and its two ends as fractions of the layer's box (0–1), so the line lands on exactly the
    /// points it was dragged between and still redraws correctly at another size. Nil on other shapes.
    package var lineWidth: CGFloat? = nil
    package var start: CGPoint? = nil
    package var end: CGPoint? = nil
    package var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }

    package init(kind: ShapeKind, red: CGFloat, green: CGFloat, blue: CGFloat, cornerRadius: CGFloat,
                 lineWidth: CGFloat? = nil, start: CGPoint? = nil, end: CGPoint? = nil) {
        self.kind = kind
        self.red = red
        self.green = green
        self.blue = blue
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.start = start
        self.end = end
    }
}
