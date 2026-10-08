import Foundation

/// Why an image or a Photoshop file could not be brought into a document.
package enum ImageImportError: LocalizedError {
    case unreadable, unsupported, tooLarge
    package var errorDescription: String? {
        switch self {
        case .unreadable: "The image could not be read. It may be damaged or unavailable."
        case .unsupported: "Choose a JPEG, PNG, HEIC, WebP, TIFF, or Photoshop (PSD) file."
        case .tooLarge: "This import exceeds the current \(DocumentLimits.documentBudgetMegapixels)-megapixel document budget or \(DocumentLimits.maxSide.formatted())-pixel side limit."
        }
    }
}
