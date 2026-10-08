import CoreGraphics
import Foundation
import LaminaCore
import Testing

/// `.lam` packages written and read through LaminaCore alone: what goes to disk, what comes back, and what is refused.
struct ProjectPackageTests {
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LaminaCorePackageTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private func image(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    /// A mask as the format stores one: 8-bit gray, no alpha. The left half hides, the right half reveals.
    private func mask(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return try #require(context.makeImage())
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: try #require(context.data).assumingMemoryBound(to: UInt8.self),
                                         count: image.width * image.height * 4))
    }

    /// A folder holding a photo with a mask, a Levels layer above it, and a guide.
    private func samplePackage() throws -> ProjectPackage {
        let folder = UUID(), photo = UUID(), levels = UUID()
        let canvas = LayerTransform(origin: .zero, size: CGSize(width: 40, height: 30))
        var levelsAdjustment = LayerAdjustment(kind: .levels)
        levelsAdjustment.levels.ranges[0] = LevelRange(black: 10, gamma: 1.2, white: 240)
        let layers = [
            ProjectLayerRecord(id: folder, name: "Folder", isVisible: true, transform: canvas, imageFile: nil,
                               isGroup: true, opacity: 0.5),
            ProjectLayerRecord(id: photo, name: "Photo & sky 🌤", isVisible: false,
                               transform: LayerTransform(origin: CGPoint(x: -4.5, y: 3), size: CGSize(width: 20, height: 10),
                                                         rotation: 30, flipX: true, sampling: .nearest),
                               imageFile: "\(photo.uuidString).png", parentID: folder, blendMode: .multiply,
                               maskFile: "\(photo.uuidString).mask.png", maskEnabled: true),
            ProjectLayerRecord(id: levels, name: "Levels", isVisible: true, transform: canvas, imageFile: nil,
                               adjustment: levelsAdjustment),
        ]
        let manifest = ProjectManifest(resolution: 300, documentID: UUID(), width: 40, height: 30, activeLayerID: photo,
                                       layers: layers, guides: [CanvasGuide(id: UUID(), axis: .vertical, position: 12.5)])
        let pixels = try image(width: 20, height: 10, red: 1, green: 0, blue: 0)
        let gray = try mask(width: 20, height: 10)
        return ProjectPackage(manifest: manifest, images: [photo: ProjectImage(image: pixels, thumbnail: pixels)],
                              masks: [photo: ProjectImage(image: gray, thumbnail: gray)])
    }

    /// Writes `package` to `name` in `root`, then lets `change` edit its manifest's JSON.
    private func written(_ package: ProjectPackage, _ name: String, in root: URL,
                         change: ((inout [String: Any]) throws -> Void)? = nil) throws -> URL {
        let url = root.appendingPathComponent(name)
        try package.write(to: url)
        if let change {
            let manifest = url.appendingPathComponent("manifest.json")
            var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
            try change(&json)
            try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        }
        return url
    }

    @Test func aPackageRoundTripsThroughDisk() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try samplePackage()
        let url = try written(original, "Round Trip.lam", in: root)
        let photo = original.manifest.layers[1].id
        let files = try FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent("images").path).sorted()
        #expect(files == ["\(photo.uuidString).mask.png", "\(photo.uuidString).png"])
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url.appendingPathComponent("manifest.json"))) as? [String: Any])
        #expect(json["format"] as? String == "com.itsjavi.lamina.project")
        #expect(json["version"] as? Int == ProjectManifest.current)

        let read = try ProjectPackage.read(from: url)
        let manifest = read.manifest
        #expect(manifest.format == ProjectManifest.laminaFormat && manifest.version == ProjectManifest.current)
        #expect(manifest.documentID == original.manifest.documentID && manifest.activeLayerID == photo)
        #expect(manifest.width == 40 && manifest.height == 30 && manifest.resolution == 300)
        #expect(manifest.guides == original.manifest.guides)
        #expect(manifest.layers.map(\.id) == original.manifest.layers.map(\.id))
        #expect(manifest.layers.map(\.name) == ["Folder", "Photo & sky 🌤", "Levels"])
        #expect(manifest.layers.map(\.isVisible) == [true, false, true])
        #expect(manifest.layers.map(\.transform) == original.manifest.layers.map(\.transform))
        #expect(manifest.layers[0].isGroup == true && manifest.layers[0].opacity == 0.5)
        #expect(manifest.layers[1].parentID == manifest.layers[0].id && manifest.layers[1].blendMode == .multiply)
        #expect(manifest.layers[2].adjustment == original.manifest.layers[2].adjustment)

        #expect(read.images.keys.sorted { $0.uuidString < $1.uuidString } == [photo] && read.masks.keys.first == photo)
        let pixels = try #require(read.images[photo])
        #expect(try rgba(pixels.image) == rgba(try #require(original.images[photo]).image))
        #expect(pixels.thumbnail.width <= 96 && pixels.thumbnail.height <= 96)
        let mask = try #require(read.masks[photo]?.image)
        #expect(ProjectImage.isMask(mask) && mask.width == 20 && mask.height == 10)
        #expect(!ProjectImage.isMask(pixels.image))
    }

    @Test func theQuickLookPreviewIsWrittenAndReadingIgnoresIt() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Preview.lam")
        let preview = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try samplePackage().write(to: url, quickLookPreview: preview)
        #expect(try Data(contentsOf: url.appendingPathComponent("QuickLook/Preview.jpg")) == preview)
        #expect(try ProjectPackage.read(from: url).manifest.layers.count == 3)
    }

    @Test func unknownFormatsAndUnsupportedVersionsAreRefused() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try samplePackage()
        let other = try written(package, "Other.lam", in: root) { $0["format"] = "com.example.project" }
        #expect(throws: ProjectError.self) { try ProjectPackage.read(from: other) }
        for version in [0, ProjectManifest.current + 1, 42] {
            let url = try written(package, "Version \(version).lam", in: root) { $0["version"] = version }
            do {
                _ = try ProjectPackage.read(from: url)
                Issue.record("Version \(version) opened")
            } catch ProjectError.version(let refused) { #expect(refused == version) }
        }
        let notJSON = try written(package, "Damaged.lam", in: root)
        try Data("not json".utf8).write(to: notJSON.appendingPathComponent("manifest.json"))
        #expect(throws: ProjectError.self) { try ProjectPackage.read(from: notJSON) }
        let file = root.appendingPathComponent("File.lam")
        try Data("{}".utf8).write(to: file)
        #expect(throws: ProjectError.self) { try ProjectPackage.read(from: file) }
    }

    /// Upstream Compositor's versions 1–11 are Lamina's own, so those open (as an import); later ones aren't read yet.
    @Test func upstreamCompositorProjectsOpenUpToVersionEleven() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try samplePackage()
        let eleven = try written(package, "Upstream.comp", in: root) {
            $0["format"] = ProjectManifest.compositorFormat
            $0["version"] = 11
        }
        let read = try ProjectPackage.read(from: eleven)
        #expect(read.manifest.format == ProjectManifest.compositorFormat && read.manifest.version == 11)
        #expect(read.images.count == 1 && read.masks.count == 1)
        let twelve = try written(package, "Newer.comp", in: root) {
            $0["format"] = ProjectManifest.compositorFormat
            $0["version"] = 12
        }
        #expect(throws: ProjectError.self) { try ProjectPackage.read(from: twelve) }
        #expect(eleven.isProjectPackage && URL(fileURLWithPath: "/a/B.LAM").isProjectPackage)
        #expect(!URL(fileURLWithPath: "/a/b.png").isProjectPackage)
    }

    @Test func imagePathsThatLeaveThePackageAreRefused() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try samplePackage()
        let escaping = try written(package, "Escaping.lam", in: root) { json in
            var layers = try #require(json["layers"] as? [[String: Any]])
            layers[1]["imageFile"] = "../../outside.png"
            json["layers"] = layers
        }
        #expect(throws: ProjectError.self) { try ProjectPackage.read(from: escaping) }

        // The right name, but a link to a file outside the package.
        let outside = root.appendingPathComponent("outside.png")
        let linked = try written(package, "Linked.lam", in: root)
        let name = try #require(package.manifest.layers[1].imageFile)
        let inside = linked.appendingPathComponent("images").appendingPathComponent(name)
        try FileManager.default.moveItem(at: inside, to: outside)
        try FileManager.default.createSymbolicLink(at: inside, withDestinationURL: outside)
        #expect(throws: ProjectError.invalid) { try ProjectPackage.read(from: linked) }
    }

    @Test func missingAndDamagedImagesAreRefused() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try samplePackage()
        let name = try #require(package.manifest.layers[1].imageFile)
        let missing = try written(package, "Missing.lam", in: root)
        try FileManager.default.removeItem(at: missing.appendingPathComponent("images").appendingPathComponent(name))
        #expect(throws: (any Error).self) { try ProjectPackage.read(from: missing) }
        let damaged = try written(package, "Damaged.lam", in: root)
        try Data("not a png".utf8).write(to: damaged.appendingPathComponent("images").appendingPathComponent(name))
        #expect(throws: ProjectError.missingImage) { try ProjectPackage.read(from: damaged) }
    }

    @Test func writingRefusesWhatReadingWouldAndKeepsThePreviousPackage() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let package = try samplePackage()
        let url = try written(package, "Safe.lam", in: root)
        let saved = try Data(contentsOf: url.appendingPathComponent("manifest.json"))
        let photo = package.manifest.layers[1].id

        var noImage = package
        noImage.images = [:]
        #expect(throws: ProjectError.missingImage) { try noImage.write(to: url) }
        var colorMask = package
        colorMask.masks[photo] = package.images[photo]
        #expect(throws: ProjectError.invalid) { try colorMask.write(to: url) }
        var future = package
        future.manifest.version = 99
        #expect(throws: ProjectError.version(99)) { try future.write(to: url) }
        #expect(try Data(contentsOf: url.appendingPathComponent("manifest.json")) == saved)
        #expect(try ProjectPackage.read(from: url).manifest.layers.count == 3)
    }

    @Test func rotationsAndHueBandsComeBackWithinOneTurn() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        var package = try samplePackage()
        package.manifest.layers[1].transform.rotation = 725
        var hue = LayerAdjustment(kind: .hsv)
        hue.hsvSettings = HueSaturationSettings()
        hue.hsvSettings?.bands[.reds] = HueBand(falloffStart: -45, rangeStart: -15, rangeEnd: 15, falloffEnd: 405)
        package.manifest.layers[2].adjustment = hue
        let read = try ProjectPackage.read(from: try written(package, "Turns.lam", in: root))
        #expect(read.manifest.layers[1].transform.rotation == 5)
        #expect(read.manifest.layers[2].adjustment?.hsvSettings?.bands[.reds]
                == HueBand(falloffStart: 315, rangeStart: 345, rangeEnd: 15, falloffEnd: 45))
    }

    @Test func validationRefusesWhatEachVersionCantHold() throws {
        let manifest = try samplePackage().manifest
        try manifest.validate()

        var badSpace = manifest
        badSpace.colorSpace = "Display P3"
        #expect(throws: ProjectError.invalid) { try badSpace.validate() }
        var badActive = ProjectManifest(documentID: UUID(), width: 40, height: 30, activeLayerID: UUID(), layers: manifest.layers)
        #expect(throws: ProjectError.invalid) { try badActive.validate() }
        badActive = ProjectManifest(documentID: UUID(), width: 30_001, height: 30, activeLayerID: nil, layers: [])
        #expect(throws: ProjectError.tooLarge) { try badActive.validate() }
        var duplicate = manifest
        duplicate.layers.append(manifest.layers[2])
        #expect(throws: ProjectError.invalid) { try duplicate.validate() }
        var foreignFile = manifest
        foreignFile.layers[1] = ProjectLayerRecord(id: manifest.layers[1].id, name: "Photo", isVisible: true,
                                                   transform: manifest.layers[1].transform, imageFile: "\(UUID().uuidString).png")
        #expect(throws: ProjectError.invalid) { try foreignFile.validate() }

        // Folder opacity came in version 8, guides in 8, adjustment layers in 7, masks in 4.
        var older = manifest
        older.version = 7
        older.guides = nil
        #expect(throws: ProjectError.invalid) { try older.validate() }
        older.layers[0].opacity = nil
        try older.validate()
        older.guides = manifest.guides
        #expect(throws: ProjectError.invalid) { try older.validate() }
        older.guides = nil
        older.version = 6
        #expect(throws: ProjectError.invalid) { try older.validate() }
        older.layers.removeLast()
        try older.validate()
        older.version = 3
        #expect(throws: ProjectError.invalid) { try older.validate() }

        // Per-letter colors arrived in version 10.
        var text = LayerTextStyle(content: "Hi")
        text.colorRuns = [LayerTextColorRun(location: 0, length: 1, red: 1, green: 0, blue: 0)]
        var lettered = manifest
        lettered.layers[1].text = text
        try lettered.validate()
        lettered.version = 9
        #expect(throws: ProjectError.invalid) { try lettered.validate() }
    }
}
