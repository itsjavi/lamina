import Foundation

/// What a layer is locked against, as Photoshop's Lock buttons in the Layers panel (format version 12). A group's
/// locks hold for everything inside it. Photoshop's Lock transparent pixels isn't here yet: it is in progress.
package struct LayerLocks: Codable, Equatable, Hashable, Sendable {
    /// No changes to the layer's own pixels; its mask stays editable.
    package var imagePixels = false
    /// The layer can't be moved, transformed, aligned or nudged.
    package var position = false
    /// Everything: pixels, mask, position, opacity, blend mode and layer effects.
    package var all = false

    package init(imagePixels: Bool = false, position: Bool = false, all: Bool = false) {
        self.imagePixels = imagePixels
        self.position = position
        self.all = all
    }

    package var isEmpty: Bool { !imagePixels && !position && !all }
    /// Whether the layer's pixels (or, with `mask`, its mask) can't be changed.
    package func locksPixels(mask: Bool = false) -> Bool { all || (!mask && imagePixels) }
    package var locksPosition: Bool { all || position }
    /// These and `other`'s together, as a group's locks hold for what's inside it.
    package func union(_ other: LayerLocks) -> LayerLocks {
        LayerLocks(imagePixels: imagePixels || other.imagePixels, position: position || other.position, all: all || other.all)
    }

    private enum CodingKeys: String, CodingKey { case imagePixels, position, all }
    // Written by people and agents too: a missing key is unlocked, and only the locks that are on are written.
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imagePixels = try container.decodeIfPresent(Bool.self, forKey: .imagePixels) ?? false
        position = try container.decodeIfPresent(Bool.self, forKey: .position) ?? false
        all = try container.decodeIfPresent(Bool.self, forKey: .all) ?? false
    }
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if imagePixels { try container.encode(true, forKey: .imagePixels) }
        if position { try container.encode(true, forKey: .position) }
        if all { try container.encode(true, forKey: .all) }
    }
}
