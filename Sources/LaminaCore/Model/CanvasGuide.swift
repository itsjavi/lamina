import CoreGraphics
import Foundation

/// A user-placed alignment line. Horizontal guides sit at a document Y; vertical at a document X.
package struct CanvasGuide: Codable, Equatable, Sendable, Hashable {
    package enum Axis: String, Codable, Sendable { case horizontal, vertical }
    package var id: UUID
    package var axis: Axis
    /// Document pixels: Y for a horizontal guide, X for a vertical one.
    package var position: Double

    package init(id: UUID, axis: Axis, position: Double) {
        self.id = id
        self.axis = axis
        self.position = position
    }

    package func offset(x: CGFloat, y: CGFloat) -> CanvasGuide {
        var guide = self
        guide.position += Double(axis == .vertical ? x : y)
        return guide
    }

    package func scaled(x: CGFloat, y: CGFloat) -> CanvasGuide {
        var guide = self
        guide.position *= Double(axis == .vertical ? x : y)
        return guide
    }

    /// Mirrors this guide when it runs perpendicular to the flip, so it stays on the same content.
    package func mirrored(horizontally: Bool, across center: CGFloat) -> CanvasGuide {
        var guide = self
        if (horizontally && axis == .vertical) || (!horizontally && axis == .horizontal) {
            guide.position = Double(2 * center) - guide.position
        }
        return guide
    }
}
