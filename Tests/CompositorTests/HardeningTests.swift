import AppKit
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import Compositor

/// Paste and Duplicate are held to the limits import and save use, before they change anything.
@MainActor
struct DocumentAdmissionTests {
    private func png(width: Int, height: Int) throws -> Data {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    private func pasteboard(_ data: Data, type: NSPasteboard.PasteboardType = .png) -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
        return pasteboard
    }

    /// A document holding `count` layers that share one 1 × 1 image.
    private func session(layers count: Int) throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 100, height: 100)
        let context = try BrushRaster.context(width: 1, height: 1, mask: false)
        let image = try #require(context.makeImage())
        let asset = ImportedImage(image: image, thumbnail: image, name: "Pixel")
        session.document?.layers = (0..<count).map { _ in ImageLayer(asset: asset, origin: .zero) }
        session.activeLayerID = session.document?.layers.last?.id
        return session
    }

    @Test func admissionChecksSidesLayersAndBothBudgets() throws {
        func added(_ width: Int, _ height: Int, mask: Bool = false) -> DocumentLimits.Footprint {
            var footprint = DocumentLimits.Footprint()
            let size = CGSize(width: width, height: height)
            footprint.add(image: mask ? nil : size, mask: mask ? size : nil)
            return footprint
        }
        let budget = DocumentLimits.documentPixelBudget
        #expect(throws: DocumentLimitError.sideTooLong) {
            try DocumentLimits.admit(added(DocumentLimits.maxSide + 1, 1), to: DocumentLimits.Footprint())
        }
        #expect(throws: DocumentLimitError.tooManyLayers) {
            try DocumentLimits.admit(added(1, 1), to: DocumentLimits.Footprint(layers: DocumentLimits.maxLayers))
        }
        try DocumentLimits.admit(added(1, 1), to: DocumentLimits.Footprint(layers: DocumentLimits.maxLayers - 1))
        #expect(throws: DocumentLimitError.overBudget) {
            try DocumentLimits.admit(added(10, 10), to: DocumentLimits.Footprint(pixels: budget - 99))
        }
        try DocumentLimits.admit(added(9, 11), to: DocumentLimits.Footprint(pixels: budget - 99))
        // Masks have a budget of their own, as saving counts them.
        try DocumentLimits.admit(added(10, 10, mask: true), to: DocumentLimits.Footprint(pixels: budget))
        #expect(throws: DocumentLimitError.overBudget) {
            try DocumentLimits.admit(added(10, 10, mask: true), to: DocumentLimits.Footprint(maskPixels: budget - 99))
        }
    }

    @Test func aPasteTooLargeIsRefusedWithAMessage() throws {
        let session = try session(layers: 1)
        let board = pasteboard(try png(width: DocumentLimits.maxSide + 1, height: 1))
        defer { board.releaseGlobally() }
        let undo = session.history.undoCount
        session.paste(from: board)
        #expect(session.document?.layers.count == 1)
        #expect(session.history.undoCount == undo)
        #expect(session.brushError == DocumentLimitError.sideTooLong.localizedDescription)
    }

    @Test func aPasteIsAdmittedBeforeItIsDecoded() throws {
        let board = pasteboard(try png(width: 4, height: 3))
        defer { board.releaseGlobally() }
        let budget = DocumentLimits.documentPixelBudget
        #expect(throws: DocumentLimitError.overBudget) {
            try EditorSession.pastedImage(from: board, joining: DocumentLimits.Footprint(pixels: budget - 11))
        }
        let image = try #require(try EditorSession.pastedImage(from: board, joining: DocumentLimits.Footprint(pixels: budget - 12)))
        #expect(image.width == 4 && image.height == 3)
    }

    @Test func pastedPixelsAreTurnedUpright() throws {
        let context = try BrushRaster.context(width: 2, height: 3, mask: false)
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let board = pasteboard(data as Data, type: .tiff)
        defer { board.releaseGlobally() }
        let image = try #require(try EditorSession.pastedImage(from: board, joining: DocumentLimits.Footprint()))
        #expect(image.width == 3 && image.height == 2)
    }

    /// PDF and other vector data still paste through NSImage, drawn at their size.
    @Test func vectorPasteStillWorks() throws {
        let session = try session(layers: 1)
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 40, height: 30)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let pdf = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        pdf.beginPDFPage(nil)
        pdf.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        pdf.fill(CGRect(x: 5, y: 5, width: 30, height: 20))
        pdf.endPDFPage()
        pdf.closePDF()
        let board = pasteboard(data as Data, type: .pdf)
        defer { board.releaseGlobally() }
        session.paste(from: board)
        #expect(session.brushError == nil)
        #expect(session.history.undoName == "Paste")
        let pasted = try #require(session.activeLayer?.asset?.image)
        #expect(pasted.width >= 40 && pasted.height >= 30)
    }

    /// Layer via Copy, a new shape and new text add their pixels through the same check.
    @Test func addingPixelsPastTheLayerLimitIsRefused() throws {
        let session = try session(layers: DocumentLimits.maxLayers)
        let image = try #require(try BrushRaster.context(width: 2, height: 2, mask: false).makeImage())
        let undo = session.history.undoCount
        session.addPixelLayer(image, at: .zero, name: "Refused", editName: "Paste")
        #expect(session.document?.layers.count == DocumentLimits.maxLayers)
        #expect(session.history.undoCount == undo)
        #expect(session.brushError == DocumentLimitError.tooManyLayers.localizedDescription)
    }

    @Test func duplicatingIsRefusedWhenTheCopiesDoNotFit() throws {
        let session = try session(layers: DocumentLimits.maxLayers - 3)
        session.addGroup()
        let folder = try #require(session.activeLayerID)
        session.addBlankLayer()
        let child = try #require(session.activeLayerID)
        try #require(session.document?.layers.first { $0.id == child }?.parentID == folder)
        #expect(session.document?.layers.count == DocumentLimits.maxLayers - 1)
        // The folder and its layer would make 10,001.
        session.selectLayer(folder)
        let undo = session.history.undoCount
        session.duplicateActiveLayer()
        #expect(session.document?.layers.count == DocumentLimits.maxLayers - 1)
        #expect(session.history.undoCount == undo)
        #expect(session.brushError == DocumentLimitError.tooManyLayers.localizedDescription)
        // One layer still fits.
        session.brushError = nil
        session.selectLayer(child)
        session.duplicateActiveLayer()
        #expect(session.document?.layers.count == DocumentLimits.maxLayers)
        #expect(session.brushError == nil)
    }

    /// Duplicating counts each copy's pixels, as saving writes each to its own file.
    @Test func duplicatingIsRefusedPastThePixelBudget() throws {
        let side = 4000
        let context = try BrushRaster.context(width: side, height: side, mask: false)
        let image = try #require(context.makeImage())
        let asset = ImportedImage(image: image, thumbnail: image, name: "Big")
        let session = EditorSession()
        session.createDocument(width: 100, height: 100)
        let fitting = DocumentLimits.documentPixelBudget / (side * side)
        session.document?.layers = (0..<fitting).map { _ in ImageLayer(asset: asset, origin: .zero) }
        session.activeLayerID = session.document?.layers.last?.id
        session.duplicateActiveLayer()
        #expect(session.document?.layers.count == fitting)
        #expect(session.brushError == DocumentLimitError.overBudget.localizedDescription)
    }
}

/// Angles from a project are brought within one turn on load, and the inspectors label any value without trapping.
@MainActor
struct AngleLoadTests {
    @Test func loadingBringsRotationsAndHueBandsWithinOneTurn() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CompositorAngleTests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let session = EditorSession()
        session.createDocument(width: 100, height: 100, emptyLayer: true)
        let layer = try #require(session.activeLayerID)
        session.addAdjustment(.hsv)
        let adjustment = try #require(session.activeLayerID)
        var snapshot = try #require(session.projectSnapshot())
        var manifest = snapshot.manifest
        let rotations: [CGFloat] = [1e20, -725]
        for (index, id) in [layer, adjustment].enumerated() {
            let at = try #require(manifest.layers.firstIndex { $0.id == id })
            manifest.layers[at].transform.rotation = rotations[index]
        }
        let at = try #require(manifest.layers.firstIndex { $0.id == adjustment })
        var hsv = HueSaturationSettings()
        hsv.bands[.reds] = HueBand(falloffStart: -1e18, rangeStart: -15, rangeEnd: 375, falloffEnd: 360)
        manifest.layers[at].adjustment?.hsvSettings = hsv
        snapshot = ProjectSnapshot(manifest: manifest, images: snapshot.images, masks: snapshot.masks)
        let url = folder.appendingPathComponent("Angles.comp")
        try await ProjectStore.shared.save(snapshot, to: url)
        let loaded = try await ProjectStore.shared.load(from: url).manifest
        let pixels = try #require(loaded.layers.first { $0.id == layer }?.transform.rotation)
        #expect(abs(pixels) <= 360 && pixels == CGFloat(1e20).truncatingRemainder(dividingBy: 360))
        #expect(loaded.layers.first { $0.id == adjustment }?.transform.rotation == -5)
        let band = try #require(loaded.layers.first { $0.id == adjustment }?.adjustment?.hsvSettings?.bands[.reds])
        #expect(band.handles.allSatisfy { (0...360).contains($0) })
        #expect(band.rangeStart == 345 && band.rangeEnd == 15 && band.falloffEnd == 360)
        #expect(band.falloffStart == (-1e18).truncatingRemainder(dividingBy: 360) + 360)
    }

    @Test(arguments: [1e20, -1e20, Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, Double(Int.max)])
    func inspectorLabelsAnyFiniteValue(_ value: Double) {
        #expect(!NumberLabel.whole(value).isEmpty)
        #expect(!NumberLabel.upToTwoDecimals(value).isEmpty)
    }

    @Test func ordinaryLabelsAreUnchanged() {
        #expect(NumberLabel.upToTwoDecimals(720) == "720")
        #expect(NumberLabel.upToTwoDecimals(-42.25) == "-42.25")
        #expect(NumberLabel.upToTwoDecimals(12.001) == "12")
        #expect(NumberLabel.whole(359.6) == "360")
        #expect(NumberLabel.whole(.infinity) == "—")
        #expect(NumberLabel.upToTwoDecimals(.nan) == "—")
        #expect(HueBand(falloffStart: 0, rangeStart: 0, rangeEnd: 360, falloffEnd: 360).withinOneTurn.handles == [0, 0, 360, 360])
    }
}

/// Making a selection from a mask or a layer goes through the Magic Wand's capped native tracer.
@MainActor
struct MaskSelectionTracingTests {
    /// Every other pixel opaque: an outline of over eight million edges, which the tracer refuses.
    private func checkerboard(side: Int) throws -> CGImage {
        let context = try BrushRaster.context(width: side, height: side, mask: false)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        for y in 0..<side {
            for x in 0..<side where (x + y).isMultiple(of: 2) {
                let p = y * context.bytesPerRow + x * 4
                bytes[p] = 255; bytes[p + 3] = 255
            }
        }
        return try #require(context.makeImage())
    }

    @Test func aNoisyLayerIsRefusedInsteadOfHanging() throws {
        let side = 2048
        let session = EditorSession()
        session.createDocument(width: side, height: side)
        let image = try checkerboard(side: side)
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Noise"))
        let id = try #require(session.activeLayerID)
        session.applySelection(CGPath(rect: CGRect(x: 1, y: 1, width: 2, height: 2), transform: nil), mode: .replace, name: "Prior")
        let selection = session.selection
        let undo = session.history.undoCount
        session.loadLayerSelection(layerID: id)
        #expect(session.brushError == MaskTracing.Failure.tooDetailed.localizedDescription)
        #expect(session.selection == selection && session.history.undoCount == undo)
    }

    @Test func aNoisyMaskIsRefusedInsteadOfHanging() throws {
        let side = 2048
        let session = EditorSession()
        session.createDocument(width: side, height: side, emptyLayer: true)
        let id = try #require(session.activeLayerID)
        let gray = try #require(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        let bytes = try #require(gray.data).assumingMemoryBound(to: UInt8.self)
        for y in 0..<side { for x in 0..<side where (x + y).isMultiple(of: 2) { bytes[y * side + x] = 255 } }
        session.addLayerMask(revealing: true)
        let index = try #require(session.document?.layers.firstIndex { $0.id == id })
        session.document?.layers[index].mask = LayerMask(asset: try LayerMask.asset(from: try #require(gray.makeImage())))
        let undo = session.history.undoCount
        session.loadMaskSelection(layerID: id)
        #expect(session.brushError == MaskTracing.Failure.tooDetailed.localizedDescription)
        #expect(session.selection == nil && session.history.undoCount == undo)
    }

    @Test func tracedOutlinesKeepTheirHoles() throws {
        let context = try BrushRaster.context(width: 3, height: 3, mask: false)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 3))
        context.clear(CGRect(x: 1, y: 1, width: 1, height: 1))
        let image = try #require(context.makeImage())
        let path = try #require(try MaskTracing.opaquePixels(in: image))
        #expect(path.contains(CGPoint(x: 0.5, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 1.5, y: 1.5)))
        #expect(!path.contains(CGPoint(x: 3.5, y: 3.5)))
    }
}
