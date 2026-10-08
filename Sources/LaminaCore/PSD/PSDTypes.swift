import CoreGraphics
import Foundation

package enum PSDError: LocalizedError, Equatable {
    case truncated, unsupportedVersion, unsupportedColorMode, unsupportedDepth, unsupportedCompression
    package var errorDescription: String? {
        switch self {
        case .truncated: "The Photoshop file could not be read. It may be damaged or incomplete."
        case .unsupportedVersion: "This Photoshop file uses a format version Lamina can’t read."
        case .unsupportedColorMode: "Only 8-bit RGB Photoshop files can be imported."
        case .unsupportedDepth: "Only 8-bit RGB Photoshop files can be imported."
        case .unsupportedCompression: "This Photoshop file uses a layer compression method that isn’t supported."
        }
    }
}

package struct PSDDocument: @unchecked Sendable {
    package var width: Int
    package var height: Int
    package var resolution: Double
    /// Bottom to top, including folders. Hidden section dividers are not stored.
    package var layers: [PSDRecord]

    package init(width: Int, height: Int, resolution: Double, layers: [PSDRecord]) {
        self.width = width
        self.height = height
        self.resolution = resolution
        self.layers = layers
    }
}

package struct PSDRecord: @unchecked Sendable {
    package var id: UUID
    package var parentID: UUID?
    package var name: String
    package var isGroup = false
    package var isVisible = true
    package var opacity: Double = 1
    package var blendKey = "norm"
    package var clipping = false
    package var croppedToCanvas = false
    package var bounds = CGRect.zero
    package var image: CGImage?
    package var mask: CGImage?
    /// Where `mask` sits on the document, and the value everywhere outside it: Photoshop stores only the part of a
    /// mask that isn't that default.
    package var maskBounds = CGRect.zero
    package var maskDefault: UInt8 = 255
    package var maskEnabled = true
    package var maskLinked = true
    package var adjustment: LayerAdjustment?
    package var kind = PSDLayerKind.raster
    package var shape: LayerShapeStyle?
    package var shapeNotes: [String] = []
    /// Parsed Photoshop type, when the `TySh` block maps onto an editable text layer.
    package var text: PSDText.Source?

    package init(id: UUID, parentID: UUID? = nil, name: String, isGroup: Bool = false, isVisible: Bool = true,
                 opacity: Double = 1, blendKey: String = "norm", clipping: Bool = false, croppedToCanvas: Bool = false,
                 bounds: CGRect = .zero, image: CGImage? = nil, mask: CGImage? = nil,
                 maskBounds: CGRect = .zero, maskDefault: UInt8 = 255, maskEnabled: Bool = true,
                 maskLinked: Bool = true, adjustment: LayerAdjustment? = nil, kind: PSDLayerKind = .raster,
                 shape: LayerShapeStyle? = nil, shapeNotes: [String] = [], text: PSDText.Source? = nil) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.isGroup = isGroup
        self.isVisible = isVisible
        self.opacity = opacity
        self.blendKey = blendKey
        self.clipping = clipping
        self.croppedToCanvas = croppedToCanvas
        self.bounds = bounds
        self.image = image
        self.mask = mask
        self.maskBounds = maskBounds
        self.maskDefault = maskDefault
        self.maskEnabled = maskEnabled
        self.maskLinked = maskLinked
        self.adjustment = adjustment
        self.kind = kind
        self.shape = shape
        self.shapeNotes = shapeNotes
        self.text = text
    }
}

package enum PSDLayerKind: Equatable, Sendable {
    case raster, group, adjustment, text, smartObject, effects, vector, other
}

/// A layer's vector shape drawn into pixels, placed on the document. `style` is set when the shape maps onto an
/// editable shape layer; otherwise it's only these pixels.
package struct PSDShapePixels: @unchecked Sendable {
    package var image: CGImage
    package var bounds: CGRect
    package var style: LayerShapeStyle?
    package var notes: [String]

    package init(image: CGImage, bounds: CGRect, style: LayerShapeStyle? = nil, notes: [String] = []) {
        self.image = image
        self.bounds = bounds
        self.style = style
        self.notes = notes
    }
}

/// Draws a layer's vector shape from its additional layer information (`vmsk`, `vogk`, `SoCo`, `vstk`), given
/// whether Photoshop stored pixels for the layer, the canvas size and the pixels left in the budget; nil leaves the
/// layer as it is. Drawing is the app's (`PSDVector`), so `PSDReader.read` takes it from the caller.
package typealias PSDShapeRenderer = (_ extra: [String: Data], _ hasPixels: Bool, _ canvas: CGSize,
                                      _ remainingPixels: Int) throws -> PSDShapePixels?

extension LayerBlendMode {
    package static func fromPSD(_ key: String) -> LayerBlendMode? {
        switch key {
        case "norm": .normal
        case "mul ": .multiply
        case "scrn": .screen
        case "over": .overlay
        case "sLit": .softLight
        case "dark": .darken
        case "lite": .lighten
        case "diff": .difference
        case "div ": .colorDodge
        case "idiv": .colorBurn
        case "hue ": .hue
        case "sat ": .saturation
        case "colr": .color
        case "lum ": .luminosity
        case "lbrn": .linearBurn
        case "lddg": .linearDodge
        case "hLit": .hardLight
        case "vLit": .vividLight
        case "lLit": .linearLight
        case "pLit": .pinLight
        case "hMix": .hardMix
        case "smud": .exclusion
        case "fsub": .subtract
        case "fdiv": .divide
        // Dissolve, Darker Color and Lighter Color are deliberately absent: Lamina has no
        // equivalent, so they fall through to Normal and say so in the conversion report.
        default: nil
        }
    }
}

extension PSDRecord {
    package var blendMode: LayerBlendMode? { LayerBlendMode.fromPSD(blendKey) }
}
