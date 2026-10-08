import Foundation

/// A project's `manifest.json`: the document and its layers, in the order they're drawn. The layers' pixels are PNG
/// files beside it (see `ProjectPackage`); docs/project-format.md describes every field.
package struct ProjectManifest: Codable, Sendable {
    /// The format version new saves write.
    package static let current = 11
    /// Every version `load` accepts. The package-header check, the manifest check and the error
    /// message all read this, so they cannot drift apart when `current` is bumped.
    package static let supported = 1...ProjectManifest.current
    package static let laminaFormat = "com.itsjavi.lamina.project"
    /// Upstream Compositor's format id. Its versions 1–11 are Lamina's own 1–11, so those open as an import; later
    /// upstream versions mean something else until they're ported.
    package static let compositorFormat = "com.compositor.project"
    package static let compositorSupported = 1...11

    /// The versions `load` accepts for a format id, nil for an id it doesn't read at all.
    package static func supportedVersions(for format: String) -> ClosedRange<Int>? {
        format == laminaFormat ? supported : format == compositorFormat ? compositorSupported : nil
    }

    package var format = ProjectManifest.laminaFormat
    package var version = ProjectManifest.current
    package var colorSpace = "sRGB"
    package var resolution: Double? = nil // Older version-1 projects default to 72 pixels/inch.
    package let documentID: UUID
    package let width: Int
    package let height: Int
    package let activeLayerID: UUID?
    package var layers: [ProjectLayerRecord]
    /// Alignment guides. Missing on versions 1–7.
    package var guides: [CanvasGuide]? = nil

    package init(format: String = ProjectManifest.laminaFormat, version: Int = ProjectManifest.current,
                 colorSpace: String = "sRGB", resolution: Double? = nil, documentID: UUID, width: Int, height: Int,
                 activeLayerID: UUID?, layers: [ProjectLayerRecord], guides: [CanvasGuide]? = nil) {
        self.format = format
        self.version = version
        self.colorSpace = colorSpace
        self.resolution = resolution
        self.documentID = documentID
        self.width = width
        self.height = height
        self.activeLayerID = activeLayerID
        self.layers = layers
        self.guides = guides
    }
}

extension URL {
    /// A project package by its extension: Lamina's `.lam`, or upstream Compositor's `.comp` to import.
    package var isProjectPackage: Bool { ["lam", "comp"].contains(pathExtension.lowercased()) }
}

package struct ProjectLayerRecord: Codable, Sendable {
    package let id: UUID
    package let name: String
    package var isVisible: Bool
    package var transform: LayerTransform
    package let imageFile: String?
    package var parentID: UUID? = nil
    package var isGroup: Bool? = nil
    package var opacity: Double? = nil
    package var blendMode: LayerBlendMode? = nil
    package var maskFile: String? = nil
    package var maskEnabled: Bool? = nil
    package var maskSourceID: UUID? = nil
    package var adjustment: LayerAdjustment? = nil
    /// A mask moved apart from its layer: where it sits on the document.
    package var maskPlacement: LayerTransform? = nil
    /// Nil (older projects) is linked.
    package var maskLinked: Bool? = nil
    /// A shape layer's shape, drawn again when the layer is scaled. Older versions ignore it and keep the pixels.
    package var shape: LayerShapeStyle? = nil
    /// The stroke and drop shadow drawn around the layer.
    package var effects: LayerEffects? = nil
    package var text: LayerTextStyle? = nil

    package init(id: UUID, name: String, isVisible: Bool, transform: LayerTransform, imageFile: String?,
                 parentID: UUID? = nil, isGroup: Bool? = nil, opacity: Double? = nil, blendMode: LayerBlendMode? = nil,
                 maskFile: String? = nil, maskEnabled: Bool? = nil, maskSourceID: UUID? = nil,
                 adjustment: LayerAdjustment? = nil, maskPlacement: LayerTransform? = nil, maskLinked: Bool? = nil,
                 shape: LayerShapeStyle? = nil, effects: LayerEffects? = nil, text: LayerTextStyle? = nil) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.transform = transform
        self.imageFile = imageFile
        self.parentID = parentID
        self.isGroup = isGroup
        self.opacity = opacity
        self.blendMode = blendMode
        self.maskFile = maskFile
        self.maskEnabled = maskEnabled
        self.maskSourceID = maskSourceID
        self.adjustment = adjustment
        self.maskPlacement = maskPlacement
        self.maskLinked = maskLinked
        self.shape = shape
        self.effects = effects
        self.text = text
    }
}

extension ProjectManifest {
    /// Layer and mask rotations, and the hue bands of Hue/Saturation layers, brought within one turn. A project
    /// written by hand or by an agent can hold any finite angle; whole extra turns change nothing that is drawn,
    /// only the number an inspector shows, and an angle far past a turn has lost the precision it needs.
    package var anglesWithinOneTurn: ProjectManifest {
        var result = self
        for index in result.layers.indices {
            result.layers[index].transform = result.layers[index].transform.withinOneTurn
            result.layers[index].maskPlacement = result.layers[index].maskPlacement?.withinOneTurn
            if let bands = result.layers[index].adjustment?.hsvSettings?.bands {
                result.layers[index].adjustment?.hsvSettings?.bands = bands.mapValues(\.withinOneTurn)
            }
        }
        return result
    }
}

extension LayerTransform {
    /// The same placement with its rotation within one turn either way.
    package var withinOneTurn: LayerTransform {
        var result = self
        if abs(rotation) > 360 { result.rotation = rotation.truncatingRemainder(dividingBy: 360) }
        return result
    }
}

extension HueBand {
    /// The same band with every handle in 0…360, where the panel draws and moves them.
    package var withinOneTurn: HueBand {
        func wrap(_ degrees: Double) -> Double {
            guard !(0...360).contains(degrees) else { return degrees }
            let remainder = degrees.truncatingRemainder(dividingBy: 360)
            return remainder < 0 ? remainder + 360 : remainder
        }
        return HueBand(falloffStart: wrap(falloffStart), rangeStart: wrap(rangeStart),
                       rangeEnd: wrap(rangeEnd), falloffEnd: wrap(falloffEnd))
    }
}

package enum ProjectError: LocalizedError, Equatable {
    case invalid, version(Int), missingImage, tooLarge, encode
    package var errorDescription: String? {
        switch self {
        case .invalid: "This is not a valid Lamina project, or its metadata is damaged."
        case .version(let version): "This project uses format version \(version). This app supports versions \(ProjectManifest.supported.lowerBound)–\(ProjectManifest.supported.upperBound)."
        case .missingImage: "An image inside the project is missing or damaged. The current document has not been replaced."
        case .tooLarge: "This project exceeds the supported canvas, layer, file-size, or \(DocumentLimits.documentBudgetMegapixels)-megapixel document limit."
        case .encode: "An image could not be saved. The previous project has not been replaced."
        }
    }
}
