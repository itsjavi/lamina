import AppKit
import CoreGraphics
import Foundation
import LaminaCore

/// Draws Photoshop type that `PSDText.parse` read (in LaminaCore) as an editable text layer, placed where Photoshop
/// had it: laying the text out needs AppKit, so it lives here.
nonisolated extension PSDText {
    static let rasterizedNote = "Editable Photoshop text becomes pixels and can’t be retyped."

    static func missingFontNote(_ name: String) -> String? {
        guard NSFont(name: name, size: 12) == nil else { return nil }
        return "The font “\(name)” isn’t installed, so the text was drawn with the system font."
    }

    @MainActor
    static func render(_ source: Source) throws -> (image: CGImage, transform: LayerTransform) {
        let image = try EditorSession.textImage(source.style)
        let size = CGSize(width: image.width, height: image.height)
        let anchor = source.anchorIsFrame
            ? CGPoint(x: LayerTextStyle.padding, y: LayerTextStyle.padding)
            : CGPoint(x: horizontalAnchor(source.style, width: size.width), y: baseline(source.style, image: size))
        let transform = layerTransform(image: size, imageAnchor: anchor, documentAnchor: source.documentAnchor,
                                       rotation: source.rotation, flipY: source.flipY)
        guard transform.isValid else { throw ProjectError.tooLarge }
        return (image, transform)
    }

    private static func horizontalAnchor(_ style: LayerTextStyle, width: CGFloat) -> CGFloat {
        switch style.alignment {
        case .left: LayerTextStyle.padding
        case .center: width / 2
        case .right: width - LayerTextStyle.padding
        }
    }

    private static func baseline(_ style: LayerTextStyle, image: CGSize) -> CGFloat {
        let padding = LayerTextStyle.padding
        let sample = style.content.isEmpty ? " " : style.content
        let storage = NSTextStorage(attributedString: NSAttributedString(string: sample, attributes: EditorSession.textAttributes(style)))
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: max(1, image.width - 2 * padding), height: max(1, image.height - 2 * padding)))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let glyphs = layout.glyphRange(for: container)
        guard glyphs.length > 0 else { return padding + style.fontSize * 0.8 }
        let fragment = layout.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        let location = layout.location(forGlyphAt: glyphs.location)
        return padding + fragment.minY + location.y
    }

    /// Matches `BrushRaster.pixelToDocument`: flip, then clockwise rotation about the center.
    private static func layerTransform(image: CGSize, imageAnchor: CGPoint, documentAnchor: CGPoint, rotation: CGFloat, flipY: Bool) -> LayerTransform {
        var local = CGPoint(x: imageAnchor.x - image.width / 2, y: imageAnchor.y - image.height / 2)
        if flipY { local.y = -local.y }
        let radians = rotation * .pi / 180
        let rotated = CGPoint(x: local.x * cos(radians) - local.y * sin(radians),
                              y: local.x * sin(radians) + local.y * cos(radians))
        let center = CGPoint(x: documentAnchor.x - rotated.x, y: documentAnchor.y - rotated.y)
        return LayerTransform(origin: CGPoint(x: center.x - image.width / 2, y: center.y - image.height / 2),
                              size: image, rotation: rotation, flipY: flipY)
    }
}
