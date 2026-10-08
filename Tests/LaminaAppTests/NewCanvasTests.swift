import Foundation
import Testing
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
}
