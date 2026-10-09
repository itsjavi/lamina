import Foundation
import CoreGraphics
import Testing
import LaminaCore
@testable import LaminaApp

/// New Canvas takes its size in pixels or a print unit at a resolution, with Image Size's conversions.
@MainActor
struct NewCanvasTests {
    @Test func unitsConvertAtAResolution() {
        #expect(SizeUnit.inches.pixels(8.5, resolution: 300) == 2550)
        #expect(SizeUnit.centimeters.pixels(2.54, resolution: 300) == 300)
        #expect(SizeUnit.millimeters.pixels(25.4, resolution: 72) == 72)
        #expect(SizeUnit.percent.pixels(50, resolution: 72, original: 1920) == 960)
        #expect(SizeUnit.pixels.pixels(1234, resolution: 300) == 1234)
        #expect(SizeUnit.inches.value(ofPixels: 2550, resolution: 300) == 8.5)
        #expect(abs(SizeUnit.millimeters.value(ofPixels: 2480, resolution: 300) - 209.97) < 0.01)
        #expect(SizeUnit.percent.value(ofPixels: 960, resolution: 72, original: 1920) == 50)
        // Image Size without resampling: the resolution that prints these pixels this long.
        #expect(SizeUnit.inches.resolution(printing: 3000, at: 10) == 300)
        #expect(SizeUnit.centimeters.resolution(printing: 300, at: 2.54) == 300)
        #expect(!SizeUnit.pixels.isPrint && !SizeUnit.percent.isPrint && SizeUnit.millimeters.isPrint)
    }

    @Test func printSizesBecomePixels() {
        var letter = NewCanvasSize(width: "8.5", height: "11", unit: .inches, resolution: "300")
        #expect(letter.pixelWidth == 2550 && letter.pixelHeight == 3300)
        letter.resolution = "72"
        #expect(letter.pixelWidth == 612 && letter.pixelHeight == 792)
        let a4 = NewCanvasSize(width: "210", height: "297", unit: .millimeters, resolution: "300")
        #expect(a4.pixelWidth == 2480 && a4.pixelHeight == 3508)
        let decimalComma = NewCanvasSize(width: "21,0", height: "29,7", unit: .centimeters, resolution: "300")
        #expect(decimalComma.pixelWidth == 2480 && decimalComma.pixelHeight == 3508)
    }

    @Test func sizesOutsideTheLimitsAreRefused() {
        #expect(NewCanvasSize(width: "1920.5", height: "1080").pixelWidth == nil) // Pixels are whole.
        #expect(NewCanvasSize(width: "200", height: "1", unit: .inches, resolution: "300").pixelWidth == nil) // 60,000 px.
        #expect(NewCanvasSize(width: "0", height: "1", unit: .inches).pixelWidth == nil)
        for resolution in ["0", "9601", "", "abc"] {
            #expect(!NewCanvasSize(resolution: resolution).isValid)
        }
        #expect(NewCanvasSize().isValid)
    }

    @Test func changingUnitsKeepsTheSize() {
        var size = NewCanvasSize(width: "1920", height: "1080", unit: .pixels, resolution: "96")
        size.convert(to: .inches)
        #expect(size.unit == .inches && NewCanvasSize.number(size.width) == 20 && NewCanvasSize.number(size.height) == 11.25)
        size.convert(to: .millimeters)
        #expect(NewCanvasSize.number(size.width) == 508 && NewCanvasSize.number(size.height) == 285.75)
        #expect(size.pixelWidth == 1920 && size.pixelHeight == 1080)
        size.convert(to: .pixels)
        #expect(size.width == "1920" && size.height == "1080")
    }

    @Test func theNewDocumentKeepsItsResolution() {
        let session = EditorSession()
        session.createNewProject(width: 2550, height: 3300, resolution: 300)
        #expect(session.document?.width == 2550 && session.document?.resolution == 300)
        #expect(session.projectSnapshot()?.manifest.resolution == 300)
    }

    /// Pixels/Centimeter and back keeps the resolution exact, and print sizes follow it.
    @Test func resolutionTakesEitherUnit() {
        var size = NewCanvasSize(width: "8.5", height: "11", unit: .inches, resolution: "300")
        size.convert(to: ResolutionUnit.perCentimeter)
        #expect(size.resolution == "118.11" && size.pixelsPerInch == 300)
        #expect(size.pixelWidth == 2550 && size.pixelHeight == 3300)
        size.convert(to: ResolutionUnit.perInch)
        #expect(size.resolution == "300" && size.pixelsPerInch == 300)
        // Typed in pixels per centimeter: 100 of them are 254 per inch.
        size.resolutionUnit = .perCentimeter
        size.resolution = "100"
        #expect(size.pixelsPerInch == 254)
        size.resolution = "4000"
        #expect(size.pixelsPerInch == nil && !size.isValid)
    }

    @Test func orientationSwapsTheSides() {
        var size = NewCanvasSize(width: "1920", height: "1080")
        #expect(size.isPortrait == false)
        size.setOrientation(portrait: true)
        #expect(size.width == "1080" && size.height == "1920" && size.isPortrait == true)
        size.setOrientation(portrait: true)
        #expect(size.width == "1080", "already portrait")
        var square = NewCanvasSize(width: "800", height: "800")
        square.setOrientation(portrait: false)
        #expect(square.isPortrait == nil && square.width == "800")
    }

    /// A card fills the details in its own unit and stays chosen either way up; other sizes choose none.
    @Test func presetsFillTheDetails() throws {
        let letter = try #require(DocumentPresetCategory.print.presets.first { $0.title == "Letter" })
        #expect(letter.pixelWidth == 2550 && letter.pixelHeight == 3300 && letter.sizeLabel == "8.5 × 11 in" && letter.fullLabel == "8.5 × 11 in · 300 ppi")
        var size = NewCanvasSize()
        size.apply(letter)
        #expect(size.unit == .inches && size.width == "8.5" && size.height == "11" && size.pixelsPerInch == 300)
        #expect(size.matches(letter))
        size.setOrientation(portrait: false)
        #expect(size.matches(letter))
        size.resolution = "72"
        #expect(!size.matches(letter), "a print size at another resolution is another size")
        // Pixel sizes match whatever the resolution.
        let hd = try #require(DocumentPresetCategory.film.presets.first { $0.title == "HDTV 1080p" })
        size.apply(hd)
        size.resolution = "300"
        #expect(size.matches(hd) && size.unit == .pixels && size.width == "1920")
        // Pixels per centimeter stay chosen when a card is applied.
        size.convert(to: ResolutionUnit.perCentimeter)
        size.apply(letter)
        #expect(size.resolutionUnit == .perCentimeter && size.pixelsPerInch == 300 && size.pixelWidth == 2550)
        // Every tab but Recent has cards, each a size a document can be.
        for category in DocumentPresetCategory.allCases where category != .recent {
            #expect(!category.presets.isEmpty, "\(category.rawValue)")
            for preset in category.presets {
                #expect((1...DocumentLimits.maxSide).contains(preset.pixelWidth) && (1...DocumentLimits.maxSide).contains(preset.pixelHeight))
            }
        }
    }

    /// Recent lists the clipboard's image, then what was last created, newest first and once each, then the default.
    @Test func recentListsTheLastSizes() throws {
        final class Store: ToolDefaultsStore {
            var values: [String: Any] = [:]
            func object(forKey defaultName: String) -> Any? { values[defaultName] }
            func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
        }
        let store = Store()
        #expect(RecentDocumentSizes.cards(clipboard: nil, from: store) == [.defaultSize])
        let a4 = DocumentPreset(title: "A4", width: 210, height: 297, unit: .millimeters, resolution: 300)
        RecentDocumentSizes.record(a4, in: store)
        RecentDocumentSizes.record(DocumentPreset(title: "Custom", width: 640, height: 480), in: store)
        RecentDocumentSizes.record(a4, in: store)
        let clipboard = DocumentPreset(title: "Clipboard", width: 64, height: 32)
        #expect(RecentDocumentSizes.cards(clipboard: clipboard, from: store).map(\.title) == ["Clipboard", "A4", "Custom", "Default Lamina Size"])
        RecentDocumentSizes.record(DocumentPreset(title: "HDTV 1080p", width: 1920, height: 1080), in: store)
        #expect(!RecentDocumentSizes.cards(clipboard: nil, from: store).contains(.defaultSize), "1920 × 1080 is the default size")
        for number in 0..<12 { RecentDocumentSizes.record(DocumentPreset(title: "Custom", width: Double(100 + number), height: 100), in: store) }
        #expect(RecentDocumentSizes.load(from: store).count == RecentDocumentSizes.limit)
        #expect(RecentDocumentSizes.load(from: nil).isEmpty, "tests never read the app's defaults")
    }

    /// Background Contents: Transparent is just the blank Layer 1; the others put a filled Background under it, all
    /// one step, named as New Document's Name says.
    @Test(arguments: BackgroundContents.allCases)
    func backgroundContentsMakeTheBottomLayer(contents: BackgroundContents) throws {
        let session = EditorSession()
        session.backgroundColor = PaletteColor(red: 0.2, green: 0.4, blue: 0.6)
        let color = contents.color(background: session.backgroundColor)
        session.createNewProject(width: 40, height: 30, resolution: 150, background: color, name: "  Poster  ")
        let document = try #require(session.document)
        #expect(document.width == 40 && document.height == 30 && document.resolution == 150)
        #expect(session.documentName == "Poster")
        #expect(session.activeLayer?.name == "Layer 1" && session.activeLayer?.asset == nil)
        #expect(session.history.undoCount <= 1)
        guard let color else {
            #expect(document.layers.map(\.name) == ["Layer 1"])
            return
        }
        #expect(document.layers.map(\.name) == ["Background", "Layer 1"])
        let image = try #require(document.layers[0].asset?.image)
        #expect(image.width == 40 && image.height == 30)
        let context = try BrushRaster.copy(image)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        for (index, component) in [color.red, color.green, color.blue, 1].enumerated() {
            #expect(abs(Int(bytes[(15 * 40 + 20) * 4 + index]) - Int((component * 255).rounded())) <= 1, "\(contents.rawValue)")
        }
        // It saves as an ordinary layer.
        #expect(session.projectSnapshot()?.manifest.layers.first?.imageFile != nil)
    }

    /// A filled background is one surface, so it's held to a surface's size; Transparent isn't.
    @Test func aFilledBackgroundKeepsToOneSurface() {
        let session = EditorSession()
        session.createNewProject(width: 20_000, height: 20_000, background: .white)
        #expect(session.document == nil)
        session.createNewProject(width: 20_000, height: 20_000)
        #expect(session.document?.layers.count == 1)
    }

    /// The name New Document gave names the tab until the document is saved somewhere.
    @Test func theChosenNameNamesTheTab() {
        let tab = ProjectTab(name: "Untitled 3")
        #expect(tab.title == "Untitled 3")
        tab.session.createNewProject(width: 10, height: 10, name: "Cover")
        #expect(tab.title == "Cover" && tab.session.documentName == "Cover")
        tab.session.createNewProject(width: 10, height: 10, name: " ")
        #expect(tab.title == "Untitled 3" && tab.session.documentName == "Untitled")
        tab.session.createNewProject(width: 10, height: 10, name: "Cover")
        tab.session.clearProject()
        #expect(tab.title == "Untitled 3")
    }
}
