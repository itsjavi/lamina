import CoreGraphics
import Foundation

package enum LayerSampling: String, CaseIterable, Codable, Sendable {
    case nearest = "Nearest"
    case smooth = "Smooth"
    case high = "High quality"
}

/// Unrotated bounds in document pixels; rotation is clockwise around their center.
package struct LayerTransform: Equatable, Codable, Sendable {
    package var origin: CGPoint
    package var size: CGSize
    package var rotation: CGFloat = 0
    package var flipX = false
    package var flipY = false
    package var sampling: LayerSampling = .high

    package init(origin: CGPoint, size: CGSize, rotation: CGFloat = 0, flipX: Bool = false, flipY: Bool = false,
                 sampling: LayerSampling = .high) {
        self.origin = origin
        self.size = size
        self.rotation = rotation
        self.flipX = flipX
        self.flipY = flipY
        self.sampling = sampling
    }

    package var center: CGPoint { CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2) }
    package var radians: CGFloat { rotation.truncatingRemainder(dividingBy: 360) * .pi / 180 }
    package var isValid: Bool {
        [origin.x, origin.y, size.width, size.height, rotation].allSatisfy(\.isFinite)
            && (1...300_000).contains(size.width) && (1...300_000).contains(size.height)
            && abs(origin.x) <= 1_000_000 && abs(origin.y) <= 1_000_000
    }
    package func point(_ unit: CGPoint) -> CGPoint {
        let x = (unit.x - 0.5) * size.width, y = (unit.y - 0.5) * size.height
        return CGPoint(x: center.x + x * cos(radians) - y * sin(radians),
                       y: center.y + x * sin(radians) + y * cos(radians))
    }
    package func contains(_ point: CGPoint) -> Bool {
        let x = point.x - center.x, y = point.y - center.y
        return abs(x * cos(radians) + y * sin(radians)) <= size.width / 2
            && abs(-x * sin(radians) + y * cos(radians)) <= size.height / 2
    }
    /// Width as a percentage of the `pixelSize` it places (100% draws them 1:1).
    package func scalePercent(pixelSize: CGSize) -> CGFloat { size.width / max(1, pixelSize.width) * 100 }
    /// Both sides set to `percent` of `pixelSize`, keeping the center (and rotation and flips).
    package func scaled(toPercent percent: CGFloat, pixelSize: CGSize) -> LayerTransform {
        var result = self
        result.size = CGSize(width: pixelSize.width * percent / 100, height: pixelSize.height * percent / 100)
        result.origin = CGPoint(x: center.x - result.size.width / 2, y: center.y - result.size.height / 2)
        return result
    }
    /// Whole pixels and whole degrees: what dragging, scaling and rotating leave behind. Typed values are used
    /// as they are, so a fraction can still be asked for by hand.
    package func rounded() -> LayerTransform {
        var result = self
        result.origin = CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
        result.size = CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
        result.rotation = rotation.rounded()
        return result
    }
    /// A `width` × `height` pixel grid (y down) mapped where this transform places it on the document: flipped, then
    /// turned clockwise about its center.
    package func pixelToDocument(width: Int, height: Int) -> CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: radians)
            .scaledBy(x: size.width / CGFloat(width) * (flipX ? -1 : 1),
                      y: size.height / CGFloat(height) * (flipY ? -1 : 1))
            .translatedBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
    }
    /// The unit square (0…1, y down) mapped where this transform places a layer on the document.
    package var unitToDocument: CGAffineTransform { pixelToDocument(width: 1, height: 1) }
    /// A transform placing the unit square as `map` does — a rotated, maybe flipped rectangle (shear, which only
    /// uneven scaling of something rotated adds, is dropped). Keeps this transform's sampling.
    package func placing(_ map: CGAffineTransform) -> LayerTransform {
        // Kept horizontal flip and the rotation nearest this one's, so the numbers stay familiar.
        let sign: CGFloat = flipX ? -1 : 1
        let angle = atan2(map.b * sign, map.a * sign)
        let along = -map.c * sin(angle) + map.d * cos(angle)
        let middle = CGPoint(x: 0.5, y: 0.5).applying(map)
        var result = self
        result.size = CGSize(width: hypot(map.a, map.b), height: abs(along))
        let degrees = angle * 180 / .pi
        result.rotation = degrees + ((rotation - degrees) / 360).rounded() * 360
        result.flipY = along < 0
        result.origin = CGPoint(x: middle.x - result.size.width / 2, y: middle.y - result.size.height / 2)
        return result
    }
    /// This placement carried along as a layer moves from `old` to `new`.
    package func following(from old: LayerTransform, to new: LayerTransform) -> LayerTransform {
        guard old != new else { return self }
        // A plain move carries exactly.
        if old.size == new.size, old.rotation == new.rotation, old.flipX == new.flipX, old.flipY == new.flipY {
            var moved = self
            moved.origin.x += new.origin.x - old.origin.x
            moved.origin.y += new.origin.y - old.origin.y
            return moved
        }
        return placing(unitToDocument.concatenating(old.unitToDocument.inverted()).concatenating(new.unitToDocument))
    }
    /// The same place on the document, whatever the sampling.
    package func samePlacement(as other: LayerTransform) -> Bool {
        var copy = self
        copy.sampling = other.sampling
        return copy == other
    }
    package static let handles = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0),
                                  CGPoint(x: 1, y: 0.5), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 1),
                                  CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 0.5)]
}
