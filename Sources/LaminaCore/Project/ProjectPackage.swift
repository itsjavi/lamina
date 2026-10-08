import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A layer's image or mask as a project holds it: the full pixels, and a thumbnail at most 96 pixels across.
package struct ProjectImage: @unchecked Sendable {
    // Immutable CGImages can be shared across threads.
    package let image: CGImage
    package let thumbnail: CGImage

    package init(image: CGImage, thumbnail: CGImage) {
        self.image = image
        self.thumbnail = thumbnail
    }

    /// Whether `image` is stored as a mask is: 8-bit gray with no alpha, white revealing and black hiding.
    package static func isMask(_ image: CGImage) -> Bool {
        !image.isMask && image.colorSpace?.model == .monochrome
            && image.bitsPerComponent == 8 && image.alphaInfo == .none
    }
}

/// A project package (`.lam`, or upstream Compositor's `.comp` to import) in memory: its manifest, and the image and
/// mask of each layer that has them, by layer id. On disk that is a folder holding `manifest.json`, an `images` folder
/// of PNGs named in the manifest, and a Quick Look preview, which loading ignores.
package struct ProjectPackage: @unchecked Sendable {
    package var manifest: ProjectManifest
    package var images: [UUID: ProjectImage]
    package var masks: [UUID: ProjectImage]

    package init(manifest: ProjectManifest, images: [UUID: ProjectImage], masks: [UUID: ProjectImage] = [:]) {
        self.manifest = manifest
        self.images = images
        self.masks = masks
    }

    private struct Header: Decodable {
        let format: String
        let version: Int
    }

    /// Writes the package to `url`, replacing what's there only once all of it is written: the manifest is validated
    /// and every image encoded first, so a failure leaves the previous package as it was. `quickLookPreview` is a JPEG
    /// that Quick Look's Space-bar preview shows.
    package func write(to url: URL, quickLookPreview: Data? = nil) throws {
        try manifest.validate()
        var images: [String: FileWrapper] = [:]
        var pixels = 0, maskPixels = 0
        for layer in manifest.layers {
          for isMask in [false, true] {
            guard let filename = isMask ? layer.maskFile : layer.imageFile else { continue }
            guard let asset = (isMask ? masks : self.images)[layer.id] else { throw ProjectError.missingImage }
            if isMask {
                guard ProjectImage.isMask(asset.image) else { throw ProjectError.invalid }
                try Self.checkSize(width: asset.image.width, height: asset.image.height, used: &maskPixels)
            } else { try Self.checkSize(width: asset.image.width, height: asset.image.height, used: &pixels) }
            let data = try autoreleasepool {
                let data = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
                    throw ProjectError.encode
                }
                CGImageDestinationAddImage(destination, asset.image, nil)
                guard CGImageDestinationFinalize(destination) else { throw ProjectError.encode }
                return data as Data
            }
            images[filename] = FileWrapper(regularFileWithContents: data)
          }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = try encoder.encode(manifest)
        guard metadata.count <= 4 * 1024 * 1024 else { throw ProjectError.tooLarge }
        var contents = [
            "manifest.json": FileWrapper(regularFileWithContents: metadata),
            "images": FileWrapper(directoryWithFileWrappers: images)
        ]
        // Quick Look's Space-bar preview reads this by name; loading ignores it.
        if let quickLookPreview {
            contents["QuickLook"] = FileWrapper(directoryWithFileWrappers: [
                "Preview.jpg": FileWrapper(regularFileWithContents: quickLookPreview),
            ])
        }
        let package = FileWrapper(directoryWithFileWrappers: contents)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
            do {
                // Foundation stages a sibling package and atomically replaces the
                // destination only once the complete package has been written.
                try package.write(to: destination, options: .atomic, originalContentsURL: nil)
            } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
    }

    /// Reads the package at `url`, coordinated with anything writing it. Throws unless the whole package is valid:
    /// a format and version this reads, a manifest that passes `ProjectManifest.validate`, and every image it names
    /// inside the package, a PNG within the size limits (masks 8-bit gray). Rotations come back within one turn.
    package static func read(from url: URL) throws -> ProjectPackage {
        var coordinationError: NSError?
        var result: Result<ProjectPackage, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { source in
            result = Result { try readPackage(source) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ProjectError.invalid }
        return try result.get()
    }

    private static func readPackage(_ url: URL) throws -> ProjectPackage {
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw ProjectError.invalid }
        let metadataURL = url.appendingPathComponent("manifest.json")
        try checkFile(metadataURL, inside: url, maximumBytes: 4 * 1024 * 1024)
        var manifest: ProjectManifest
        let metadata = try Data(contentsOf: metadataURL)
        let header: Header
        do { header = try JSONDecoder().decode(Header.self, from: metadata) }
        catch { throw ProjectError.invalid }
        guard let versions = ProjectManifest.supportedVersions(for: header.format) else { throw ProjectError.invalid }
        guard versions.contains(header.version) else { throw ProjectError.version(header.version) }
        do { manifest = try JSONDecoder().decode(ProjectManifest.self, from: metadata) }
        catch { throw ProjectError.invalid }
        try manifest.validate()
        manifest = manifest.anglesWithinOneTurn
        var images: [UUID: ProjectImage] = [:]
        var masks: [UUID: ProjectImage] = [:]
        var pixels = 0, maskPixels = 0
        for layer in manifest.layers {
          for isMask in [false, true] {
            guard let filename = isMask ? layer.maskFile : layer.imageFile else { continue }
            let file = url.appendingPathComponent("images").appendingPathComponent(filename)
            try checkFile(file, inside: url, maximumBytes: 512 * 1024 * 1024)
            let asset = try autoreleasepool {
                // Decoded from the file's bytes in memory, not from the file: an image made from a file source stays tied
                // to it, and the next save replaces that file (ImageIO: "mmapped file changed"), so an image kept for undo
                // could later read someone else's pixels.
                let bytes = try Data(contentsOf: file)
                guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                      CGImageSourceGetType(source) as String? == UTType.png.identifier,
                      CGImageSourceGetCount(source) == 1,
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight] as? Int,
                      (properties[kCGImagePropertyDepth] as? Int ?? 8) <= 8 else { throw ProjectError.missingImage }
                if isMask { try checkSize(width: width, height: height, used: &maskPixels) }
                else { try checkSize(width: width, height: height, used: &pixels) }
                guard let image = CGImageSourceCreateImageAtIndex(source, 0,
                    [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 96,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { throw ProjectError.missingImage }
                if isMask, !ProjectImage.isMask(image) { throw ProjectError.invalid }
                return ProjectImage(image: image, thumbnail: thumbnail)
            }
            if isMask { masks[layer.id] = asset } else { images[layer.id] = asset }
          }
        }
        return ProjectPackage(manifest: manifest, images: images, masks: masks)
    }

    private static func checkSize(width: Int, height: Int, used: inout Int) throws {
        guard (1...DocumentLimits.maxSide).contains(width), (1...DocumentLimits.maxSide).contains(height), width * height <= DocumentLimits.documentPixelBudget - used else {
            throw ProjectError.tooLarge
        }
        used += width * height
    }

    private static func checkFile(_ file: URL, inside package: URL, maximumBytes: Int) throws {
        let root = package.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard file.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root) else { throw ProjectError.invalid }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= maximumBytes else { throw ProjectError.tooLarge }
    }
}
