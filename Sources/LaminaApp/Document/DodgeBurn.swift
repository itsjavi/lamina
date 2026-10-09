import CoreGraphics
import Foundation

/// Which tones Dodge and Burn work on. The weight falls off smoothly either side, so there's no hard edge.
nonisolated enum ToneRange: String, CaseIterable, Sendable {
    case shadows = "Shadows", midtones = "Midtones", highlights = "Highlights"
    /// As `brush_tone` numbers them.
    var code: Int32 {
        switch self {
        case .shadows: return 0
        case .midtones: return 1
        case .highlights: return 2
        }
    }
}

/// Dodge and Burn: the stroke lightens or darkens the layer's own pixels rather than painting a color, as
/// Photoshop's Dodge and Burn tools do. Exposure is 0–1.
nonisolated struct BrushToning: Equatable, Sendable {
    var lightens: Bool
    var range: ToneRange = .midtones
    var exposure: CGFloat = 0.5
}
