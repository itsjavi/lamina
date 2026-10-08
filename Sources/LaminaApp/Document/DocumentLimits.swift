import CoreGraphics
import Foundation

/// The size and memory ceilings a document is held to, in one place.
///
/// These were repeated as literals in the editor, the renderer, the importers and the exporters,
/// so they could not be reasoned about or changed together. Two separate ideas had also collapsed
/// onto the same number: how large a *single* surface may be, and how much raster a *whole
/// document* may hold across all of its layers. Those are not the same budget. A 58-megapixel
/// print banner carrying 29 layers is an ordinary Photoshop document, and it needs far more than
/// one surface's worth of allowance even though no single surface in it is unusual.
///
/// Both pixel ceilings stay below `maxSide * maxSide`, so a square at `maxSide` is still rejected
/// as oversized. Several tests express "too large" that way, and it is the largest area the side
/// limit can describe.
nonisolated enum DocumentLimits {
    /// Longest side, in pixels, of any canvas, layer, mask or generated surface.
    static let maxSide = 30_000

    /// `maxSide` for the paths that measure in CGFloat.
    static let maxSideExtent = CGFloat(maxSide)

    /// Largest single surface: a canvas, an export, a filter target, an adjustment or mask render.
    /// At RGBA8 one allocation is at most 800 MB, and a filter holds a few of them at once.
    static let maxSurfacePixels = 200_000_000

    /// `maxSurfacePixels` for the paths that measure in CGFloat.
    static let maxSurfaceExtent = CGFloat(maxSurfacePixels)

    /// Total imported raster one document may hold, summed across every layer and mask. Only
    /// documents that genuinely contain this much ever reach it, so the ceiling costs nothing to
    /// the small documents that never approach it.
    ///
    /// Scaled to the Mac: a quarter of its memory at 4 bytes a pixel (about 537 MP on 8 GB), never less than
    /// one surface and never more than 800 MP (3.2 GB of layers), which a 16 GB Mac already reaches.
    static let documentPixelBudget = min(800_000_000,
        max(maxSurfacePixels, Int(clamping: ProcessInfo.processInfo.physicalMemory / 16)))

    /// Most layers, folders and adjustments included, one document may hold.
    static let maxLayers = 10_000

    /// The two ceilings as megapixels, for the messages that quote them back to the reader.
    static var maxSurfaceMegapixels: Int { maxSurfacePixels / 1_000_000 }
    static var documentBudgetMegapixels: Int { documentPixelBudget / 1_000_000 }

    /// What a document's layers hold, counted the way saving counts it: every layer's own image and mask, even
    /// when layers share one, since each is written to its own file.
    struct Footprint: Equatable, Sendable {
        var layers = 0
        var pixels = 0
        var maskPixels = 0
        /// The longest side of any image or mask.
        var longestSide = 0

        /// Counts one layer with an image and a mask of these sizes (nil when it has none).
        mutating func add(image: CGSize?, mask: CGSize?) {
            layers += 1
            for (size, isMask) in [(image, false), (mask, true)] {
                guard let size else { continue }
                let width = Int(size.width), height = Int(size.height)
                if isMask { maskPixels += width * height } else { pixels += width * height }
                longestSide = max(longestSide, width, height)
            }
        }
    }

    /// Throws unless a document holding `current` can take `added` as well and still be saved, which is what
    /// importing asks too: at most `maxLayers` layers, no image or mask longer than `maxSide`, and the images, like
    /// the masks, within `documentPixelBudget`. Paste and Duplicate go through this before they change anything.
    static func admit(_ added: Footprint, to current: Footprint) throws {
        guard added.longestSide <= maxSide else { throw DocumentLimitError.sideTooLong }
        guard current.layers <= maxLayers - added.layers else { throw DocumentLimitError.tooManyLayers }
        guard current.pixels <= documentPixelBudget - added.pixels,
              current.maskPixels <= documentPixelBudget - added.maskPixels else { throw DocumentLimitError.overBudget }
    }
}

/// Why pixels were refused before they entered a document: with them, it could no longer be saved.
nonisolated enum DocumentLimitError: LocalizedError, Equatable {
    case sideTooLong, tooManyLayers, overBudget
    var errorDescription: String? {
        switch self {
        case .sideTooLong:
            "That image is longer than \(DocumentLimits.maxSide.formatted()) pixels on a side, the most a layer can be."
        case .tooManyLayers:
            "A document can hold up to \(DocumentLimits.maxLayers.formatted()) layers."
        case .overBudget:
            "That would take this document past its \(DocumentLimits.documentBudgetMegapixels)-megapixel limit, so it couldn’t be saved."
        }
    }
}
