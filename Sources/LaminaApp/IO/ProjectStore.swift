import Foundation
import CoreGraphics
import LaminaCore
import UniformTypeIdentifiers

extension UTType {
    /// Lamina's projects (`.lam`).
    static let laminaProject = UTType(exportedAs: "com.itsjavi.lamina.project", conformingTo: .package)
    /// Upstream Compositor's projects (`.comp`), which open as an import.
    static let compositorProject = UTType(importedAs: "com.compositor.project", conformingTo: .package)
    nonisolated static let photoshopImage = UTType(importedAs: "com.adobe.photoshop-image")
    nonisolated static let photoshopLargeImage = UTType(importedAs: "com.adobe.photoshop-large-image")
    static let importableImages: [UTType] = [.jpeg, .png, .heic, .webP, .tiff, .photoshopImage, .photoshopLargeImage, .rawImage, .svg]
}

nonisolated struct ProjectSnapshot: @unchecked Sendable {
    let manifest: ProjectManifest
    let images: [UUID: ImportedImage]
    var masks: [UUID: ImportedImage] = [:]
}

nonisolated extension ProjectSnapshot {
    /// The package that saving writes: the same manifest and pixels, without the paint tiles the editor keeps.
    var projectPackage: ProjectPackage {
        ProjectPackage(manifest: manifest,
                       images: images.mapValues { ProjectImage(image: $0.image, thumbnail: $0.thumbnail) },
                       masks: masks.mapValues { ProjectImage(image: $0.image, thumbnail: $0.thumbnail) })
    }

    /// A package read from disk, each image and mask named after its layer.
    init(_ package: ProjectPackage) {
        let names = Dictionary(package.manifest.layers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        func imported(_ images: [UUID: ProjectImage]) -> [UUID: ImportedImage] {
            images.reduce(into: [:]) { result, entry in
                result[entry.key] = ImportedImage(image: entry.value.image, thumbnail: entry.value.thumbnail,
                                                  name: names[entry.key] ?? "")
            }
        }
        self.init(manifest: package.manifest, images: imported(package.images), masks: imported(package.masks))
    }
}

/// Saves and opens projects off the main actor. The format itself — validating, writing and reading packages — is
/// `ProjectPackage` in LaminaCore; this converts between its images and the editor's.
actor ProjectStore {
    static let shared = ProjectStore()

    func save(_ snapshot: ProjectSnapshot, to url: URL, quickLook: QuickLookImages? = nil) throws {
        try snapshot.projectPackage.write(to: url, quickLookPreview: quickLook?.preview)
    }

    func load(from url: URL) throws -> ProjectSnapshot {
        ProjectSnapshot(try ProjectPackage.read(from: url))
    }
}
