import CoreGraphics
import Foundation
import LaminaCore
import PSDFixtures
import Testing

/// Photoshop files read into layer records, without the app: built with PSDFixture, as Photoshop lays them out.
struct PSDReaderTests {
    private func colorImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: alpha))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    private func grayImage(width: Int, height: Int, value: CGFloat) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: value, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test func readsLayersInOrderWithVisibilityOpacityAndBlend() throws {
        let red = try colorImage(width: 2, height: 2, red: 1, green: 0, blue: 0)
        let blue = try colorImage(width: 2, height: 2, red: 0, green: 0, blue: 1)
        let composite = try colorImage(width: 4, height: 4, red: 0, green: 0, blue: 0, alpha: 0)
        var bottom = PSDRecord(id: UUID(), name: "Red")
        bottom.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        bottom.image = red
        bottom.opacity = 0.5
        bottom.blendKey = "mul "
        var top = PSDRecord(id: UUID(), name: "Blue")
        top.bounds = CGRect(x: 2, y: 0, width: 2, height: 2)
        top.image = blue
        top.isVisible = false
        let data = try PSDFixture.data(PSDDocument(width: 4, height: 4, resolution: 144, layers: [bottom, top]), composite: composite)
        #expect(PSDReader.matches(data))
        let document = try PSDReader.read(data)
        #expect(document.width == 4 && document.height == 4)
        #expect(document.resolution == 144)
        #expect(document.layers.map(\.name) == ["Red", "Blue"])
        #expect(document.layers.map(\.isVisible) == [true, false])
        #expect(abs(document.layers[0].opacity - 0.5) < 0.01)
        #expect(document.layers[0].blendKey == "mul " && document.layers[0].blendMode == .multiply)
        #expect(document.layers[1].blendMode == .normal)
        #expect(document.layers[1].bounds == CGRect(x: 2, y: 0, width: 2, height: 2))
        #expect(document.layers.map(\.kind) == [.raster, .raster])
        #expect(document.layers[0].image?.width == 2 && document.layers[0].image?.height == 2)
    }

    @Test func readsFoldersMasksAndClipping() throws {
        let fill = try colorImage(width: 2, height: 2, red: 0, green: 1, blue: 0)
        let composite = try colorImage(width: 4, height: 4, red: 0, green: 0, blue: 0, alpha: 0)
        let groupID = UUID()
        var group = PSDRecord(id: groupID, name: "Stack")
        group.isGroup = true
        group.blendKey = "pass"
        var base = PSDRecord(id: UUID(), parentID: groupID, name: "Base")
        base.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        base.image = fill
        base.mask = try grayImage(width: 2, height: 2, value: 1)
        var child = PSDRecord(id: UUID(), parentID: groupID, name: "Clipped")
        child.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        child.image = fill
        child.clipping = true
        let data = try PSDFixture.data(PSDDocument(width: 4, height: 4, resolution: 72, layers: [group, base, child]), composite: composite)
        let layers = try PSDReader.read(data).layers
        // Bottom to top: the folder's children, then the folder, which a fresh id stands for.
        #expect(layers.map(\.name) == ["Base", "Clipped", "Stack"])
        let folder = try #require(layers.last)
        #expect(folder.isGroup && folder.kind == .group && folder.blendKey == "pass" && folder.image == nil)
        #expect(folder.bounds == CGRect(x: 0, y: 0, width: 4, height: 4))
        #expect(layers.dropLast().allSatisfy { $0.parentID == folder.id })
        let mask = try #require(layers[0].mask)
        #expect(mask.width == 2 && mask.height == 2 && layers[0].maskEnabled)
        #expect(!layers[0].clipping && layers[1].clipping)
    }

    @Test func typeLayersCarryTheirParsedText() throws {
        var record = PSDRecord(id: UUID(), name: "Greeting")
        record.image = try colorImage(width: 8, height: 8, red: 0, green: 0, blue: 0)
        record.bounds = CGRect(x: 1, y: 2, width: 8, height: 8)
        let file = try PSDFixture.data(PSDDocument(width: 32, height: 32, resolution: 72, layers: [record]),
                                       composite: try colorImage(width: 32, height: 32, red: 1, green: 1, blue: 1),
                                       extras: [record.id: ["TySh": PSDFixture.tySh(text: "Hello", tx: 40, ty: 50)]])
        let read = try #require(try PSDReader.read(file).layers.first)
        #expect(read.kind == .text)
        #expect(read.text?.style.content == "Hello" && read.text?.style.fontSize == 24)
        #expect(read.text?.documentAnchor == CGPoint(x: 40, y: 50))
        // Photoshop's own pixels stay, for when the text can't be drawn again.
        #expect(read.image?.width == 8)
    }

    /// Drawing a vector shape is the app's: the reader hands each layer's blocks to the renderer it's given, in order,
    /// with the pixels left in the budget, and puts what comes back in place of what Photoshop stored.
    @Test func vectorShapesAreDrawnByTheRendererTheyreGiven() throws {
        let fill = try colorImage(width: 2, height: 2, red: 1, green: 0, blue: 0)
        var painted = PSDRecord(id: UUID(), name: "Painted")
        painted.bounds = CGRect(x: 0, y: 0, width: 2, height: 2)
        painted.image = fill
        let empty = PSDRecord(id: UUID(), name: "Outline")
        let path = Data("path".utf8)
        let data = try PSDFixture.data(PSDDocument(width: 8, height: 8, resolution: 72, layers: [painted, empty]), composite: fill,
                                       extras: [painted.id: ["vmsk": path], empty.id: ["vmsk": path]])

        let stored = try PSDReader.read(data)
        #expect(stored.layers.map(\.kind) == [.vector, .vector])
        #expect(stored.layers[0].image?.width == 2 && stored.layers[1].image == nil && stored.layers[1].shape == nil)

        let drawn = try colorImage(width: 3, height: 1, red: 0, green: 0, blue: 1)
        let ellipse = LayerShapeStyle(kind: .ellipse, red: 0, green: 0, blue: 1, cornerRadius: 0)
        var calls: [(hasPixels: Bool, remaining: Int)] = []
        let document = try PSDReader.read(data, remainingPixels: 1_000) { extra, hasPixels, canvas, remaining in
            #expect(extra["vmsk"] == path && canvas == CGSize(width: 8, height: 8))
            calls.append((hasPixels, remaining))
            return PSDShapePixels(image: drawn, bounds: CGRect(x: 4, y: 5, width: 3, height: 1),
                                  style: hasPixels ? ellipse : nil, notes: hasPixels ? ["Redrawn."] : [])
        }
        // The 2 × 2 layer's pixels come off the budget first, then each shape drawn.
        #expect(calls.map(\.hasPixels) == [true, false])
        #expect(calls.map(\.remaining) == [996, 993])
        #expect(document.layers.allSatisfy { $0.kind == .vector && $0.image?.width == 3 })
        #expect(document.layers.allSatisfy { $0.bounds == CGRect(x: 4, y: 5, width: 3, height: 1) })
        #expect(document.layers[0].shape == ellipse && document.layers[0].shapeNotes == ["Redrawn."])
        #expect(document.layers[1].shape == nil && document.layers[1].shapeNotes.isEmpty)

        #expect(throws: ImageImportError.tooLarge) {
            try PSDReader.read(data) { _, _, _, _ in throw ImageImportError.tooLarge }
        }
    }

    @Test func oversizedLayerBoundsAreRejected() throws {
        #expect(throws: ImageImportError.tooLarge) {
            try PSDReader.read(oversizedLayerFile(width: 8, height: 8, layerWidth: 30_000, layerHeight: 30_000), remainingPixels: 50)
        }
        let fill = try colorImage(width: 20, height: 20, red: 1, green: 0, blue: 0)
        var layer = PSDRecord(id: UUID(), name: "Huge")
        layer.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
        layer.image = fill
        let data = try PSDFixture.data(PSDDocument(width: 20, height: 20, resolution: 72, layers: [layer]), composite: fill)
        #expect(throws: ImageImportError.tooLarge) {
            try PSDReader.read(data, remainingPixels: 50)
        }
    }

    @Test func unusedSpotChannelsAreSkippedBeforeDecode() throws {
        let pixels = Data(repeating: 255, count: 4)
        var channels: [(id: Int16, payload: Data)] = []
        for id: Int16 in [-1, 0, 1, 2] {
            channels.append((id, rawChannel(pixels)))
        }
        // Compression 99 would throw if these planes were unpacked. 52 extras fill the 56-channel cap.
        let bogus = Data([0, 99, 0, 0])
        for id in Int16(3)...Int16(54) {
            channels.append((id, bogus))
        }
        let document = try PSDReader.read(layerFile(layerWidth: 2, layerHeight: 2, channels: channels))
        #expect(document.layers.count == 1)
        #expect(document.layers[0].image?.width == 2)
        #expect(document.layers[0].image?.height == 2)
    }

    @Test func unsupportedCompressionOnColorChannelsIsStillRejected() {
        let pixels = Data(repeating: 255, count: 4)
        let channels: [(id: Int16, payload: Data)] = [
            (-1, rawChannel(pixels)),
            (0, Data([0, 99, 0, 0])),
            (1, rawChannel(pixels)),
            (2, rawChannel(pixels)),
        ]
        #expect(throws: PSDError.unsupportedCompression) {
            try PSDReader.read(layerFile(layerWidth: 2, layerHeight: 2, channels: channels))
        }
    }

    @Test func matchesRequiresPhotoshopMagic() throws {
        let jpeg = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).psd")
        try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: jpeg)
        defer { try? FileManager.default.removeItem(at: jpeg) }
        #expect(!PSDReader.matches(jpeg))
        let psd = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bin")
        try Data("8BPS".utf8).write(to: psd)
        defer { try? FileManager.default.removeItem(at: psd) }
        #expect(PSDReader.matches(psd))
    }

    @Test func unsupportedHeadersAreRejected() throws {
        #expect(throws: PSDError.unsupportedVersion) { try PSDReader.read(header(version: 3)) }
        #expect(throws: PSDError.unsupportedColorMode) { try PSDReader.read(header(mode: 4)) }
        #expect(throws: PSDError.unsupportedDepth) { try PSDReader.read(header(depth: 16)) }
        #expect(throws: ImageImportError.tooLarge) { try PSDReader.read(header(width: 30_001, height: 10)) }
    }

    private func shorts(_ values: [Int]) -> Data {
        values.reduce(into: Data()) { data, value in
            let bits = UInt16(bitPattern: Int16(value))
            data.append(contentsOf: [UInt8(bits >> 8), UInt8(bits & 0xFF)])
        }
    }

    @Test func levelsGammaIsInHundredths() throws {
        // RGB: input 2–254, gamma 1.00 (stored as 100); red, green and blue untouched; padded to Photoshop's 29 records.
        var data = shorts([2, 2, 254, 0, 255, 100] + Array(repeating: [0, 255, 0, 255, 100], count: 3).flatMap { $0 })
        data.append(Data(count: 292 - data.count))
        let levels = try #require(PSDAdjustments.levels(data)?.levels)
        #expect(levels.ranges[0] == LevelRange(black: 2, gamma: 1, white: 254, outputBlack: 0, outputWhite: 255))
        #expect(levels.ranges[1...3].allSatisfy { $0.gamma == 1 })
    }

    @Test func hueSaturationReadsMasterAndEachRange() throws {
        // Version 2, Colorize off; Colorize values (ignored), Master +5/+4/0; Reds' band and −30 saturation, +10 light.
        var data = shorts([2]) + Data([0, 0]) + shorts([23, 25, 0, 5, 4, 0, 315, 345, 15, 45, 0, -30, 10])
        data += shorts(Array(repeating: 0, count: 7 * 5))
        let settings = try #require(PSDAdjustments.hue(data)?.hsvSettings)
        #expect(!settings.colorize)
        #expect(settings.adjustments[.master] == RangeAdjustment(hue: 5, saturation: 4, lightness: 0))
        #expect(settings.adjustments[.reds] == RangeAdjustment(hue: 0, saturation: -30, lightness: 10))
        #expect(settings.bands[.reds] == HueBand(falloffStart: 315, rangeStart: 345, rangeEnd: 15, falloffEnd: 45))

        data[2] = 1  // Colorize on: its own values apply.
        let colorized = try #require(PSDAdjustments.hue(data)?.hsvSettings)
        #expect(colorized.colorize && colorized.adjustments[.master] == RangeAdjustment(hue: 23, saturation: 25, lightness: 0))
    }

    /// A 6 × 3 layer with a mask hanging two pixels off the left of a 4 × 4 canvas.
    private func overhangingDocument() throws -> (source: PSDDocument, composite: CGImage) {
        var pixels = [UInt8]()
        for y in 0..<3 {
            for x in 0..<6 { pixels += [UInt8(x * 30 + y), UInt8(y * 50), UInt8(255 - x * 20), 255] }
        }
        var layer = PSDRecord(id: UUID(), name: "Overhang")
        layer.bounds = CGRect(x: -2, y: 1, width: 6, height: 3)
        layer.image = try PSDChannelCoder.image(width: 6, height: 3, rgba: pixels)
        layer.mask = try PSDChannelCoder.maskImage(width: 6, height: 3, gray: (0..<18).map { UInt8($0 * 10) })
        return (PSDDocument(width: 4, height: 4, resolution: 72, layers: [layer]),
                try colorImage(width: 4, height: 4, red: 1, green: 1, blue: 1))
    }

    @Test func croppedDocumentStillOverBudgetIsRejected() throws {
        let fixture = try overhangingDocument()
        #expect(throws: ImageImportError.tooLarge) {
            try PSDReader.read(PSDFixture.data(fixture.source, composite: fixture.composite), remainingPixels: 11)
        }
    }

    @Test func channelCropsMatchFullDecodes() throws {
        let width = 5, height = 4
        let source = Data((0..<(width * height)).map { UInt8($0) })
        let crop = PSDCrop(x: 1, y: 1, width: 3, height: 2)
        let rawFull = try PSDChannelCoder.decode(compression: 0, width: width, height: height, data: source)
        #expect(try PSDChannelCoder.decode(compression: 0, width: width, height: height, data: source, crop: crop) == sliced(rawFull, width: width, crop: crop))
        for largeDocument in [false, true] {
            let packed = packBits(source, width: width, height: height, largeDocument: largeDocument)
            let full = try PSDChannelCoder.decode(compression: 1, width: width, height: height, data: packed, largeDocument: largeDocument)
            let cropped = try PSDChannelCoder.decode(compression: 1, width: width, height: height, data: packed,
                                                      largeDocument: largeDocument, crop: crop)
            #expect(cropped == sliced(full, width: width, crop: crop))
        }
    }

    private func sliced(_ plane: [UInt8], width: Int, crop: PSDCrop) -> [UInt8] {
        var result: [UInt8] = []
        for row in 0..<crop.height { result.append(contentsOf: plane[(crop.y + row) * width + crop.x..<(crop.y + row) * width + crop.x + crop.width]) }
        return result
    }

    private func packBits(_ plane: Data, width: Int, height: Int, largeDocument: Bool) -> Data {
        var counts = Data()
        var rows = Data()
        for row in 0..<height {
            let bytes = plane[row * width..<(row + 1) * width]
            var packed = Data([UInt8(width - 1)])
            packed.append(bytes)
            if largeDocument { counts.append(contentsOf: [0, 0]) }
            counts.append(UInt8(packed.count >> 8))
            counts.append(UInt8(packed.count))
            rows.append(packed)
        }
        return counts + rows
    }

    private func header(version: UInt16 = 1, width: UInt32 = 8, height: UInt32 = 8, depth: UInt16 = 8, mode: UInt16 = 3) -> Data {
        var data = Data("8BPS".utf8)
        func append(_ value: UInt16) {
            data.append(UInt8(truncatingIfNeeded: value >> 8))
            data.append(UInt8(truncatingIfNeeded: value))
        }
        func append32(_ value: UInt32) {
            data.append(UInt8(truncatingIfNeeded: value >> 24))
            data.append(UInt8(truncatingIfNeeded: value >> 16))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
            data.append(UInt8(truncatingIfNeeded: value))
        }
        append(version)
        data.append(Data(count: 6))
        append(3)
        append32(height)
        append32(width)
        append(depth)
        append(mode)
        return data
    }

    private func rawChannel(_ plane: Data) -> Data {
        var data = Data([0, 0])
        data.append(plane)
        return data
    }

    private func oversizedLayerFile(width: UInt32, height: UInt32, layerWidth: Int32, layerHeight: Int32) -> Data {
        layerFile(canvasWidth: width, canvasHeight: height, layerWidth: layerWidth, layerHeight: layerHeight, channels: [
            (-1, Data([0, 0])), (0, Data([0, 0])), (1, Data([0, 0])), (2, Data([0, 0])),
        ])
    }

    private func layerFile(
        canvasWidth: UInt32 = 8,
        canvasHeight: UInt32 = 8,
        layerWidth: Int32,
        layerHeight: Int32,
        channels: [(id: Int16, payload: Data)]
    ) -> Data {
        var data = header(width: canvasWidth, height: canvasHeight)
        func append32(_ value: UInt32) {
            data.append(UInt8(truncatingIfNeeded: value >> 24))
            data.append(UInt8(truncatingIfNeeded: value >> 16))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
            data.append(UInt8(truncatingIfNeeded: value))
        }
        append32(0)
        append32(0)
        var records = Data()
        func rec16(_ value: UInt16) {
            records.append(UInt8(truncatingIfNeeded: value >> 8))
            records.append(UInt8(truncatingIfNeeded: value))
        }
        func rec32(_ value: UInt32) {
            records.append(UInt8(truncatingIfNeeded: value >> 24))
            records.append(UInt8(truncatingIfNeeded: value >> 16))
            records.append(UInt8(truncatingIfNeeded: value >> 8))
            records.append(UInt8(truncatingIfNeeded: value))
        }
        func recI16(_ value: Int16) { rec16(UInt16(bitPattern: value)) }
        func recI32(_ value: Int32) { rec32(UInt32(bitPattern: value)) }
        recI16(1)
        recI32(0)
        recI32(0)
        recI32(layerHeight)
        recI32(layerWidth)
        rec16(UInt16(channels.count))
        var payloads = Data()
        for channel in channels {
            recI16(channel.id)
            rec32(UInt32(channel.payload.count))
            payloads.append(channel.payload)
        }
        records.append(contentsOf: Array("8BIMnorm".utf8))
        records.append(contentsOf: [255, 0, 0, 0])
        rec32(12)
        rec32(0)
        rec32(0)
        records.append(3)
        records.append(contentsOf: Array("Big".utf8))
        var info = Data()
        func info32(_ value: UInt32) {
            info.append(UInt8(truncatingIfNeeded: value >> 24))
            info.append(UInt8(truncatingIfNeeded: value >> 16))
            info.append(UInt8(truncatingIfNeeded: value >> 8))
            info.append(UInt8(truncatingIfNeeded: value))
        }
        info32(UInt32(records.count + payloads.count))
        info.append(records)
        info.append(payloads)
        info32(0)
        append32(UInt32(info.count))
        data.append(info)
        return data
    }
}
