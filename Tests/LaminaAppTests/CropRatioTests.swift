import AppKit
import Testing
@testable import LaminaApp

@MainActor
struct CropRatioTests {
    /// Kept in a throwaway defaults suite, never the person's own.
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "CropRatioTests-\(UUID().uuidString)")!
    }

    @Test func ratiosAreWrittenAndReadAsWidthToHeight() throws {
        #expect(CropRatio.text(width: 9, height: 20) == "9:20")
        #expect(CropRatio.text(width: 2.394, height: 1) == "2.39:1")
        #expect(CropRatio.text(width: 1.5, height: 1.0) == "1.5:1")
        #expect(CropRatio.text(width: 0, height: 4) == nil)
        #expect(CropRatio.text(width: 4, height: -3) == nil)
        #expect(CropRatio.text(width: .infinity, height: 1) == nil)
        #expect(CropRatio.text(width: 20_000, height: 1) == nil)
        #expect(abs(try #require(CropRatio.value("9:20")) - 0.45) < 1e-9)
        #expect(abs(try #require(CropRatio.value("16:9")) - 16.0 / 9.0) < 1e-9)
        #expect(CropRatio.value("Free") == nil && CropRatio.value("Original") == nil)
        #expect(CropRatio.value("0:3") == nil && CropRatio.value("3:") == nil)
    }

    @Test func typedRatiosAreRememberedNewestFirst() {
        let defaults = defaults()
        let ratios = CustomCropRatios(defaults: defaults)
        #expect(ratios.ratios.isEmpty)
        #expect(ratios.add(width: 7, height: 5) == "7:5")
        #expect(ratios.add(width: 5, height: 4) == "5:4")
        #expect(ratios.add(width: 4, height: 3) == "4:3", "a built-in ratio is chosen, not added")
        #expect(ratios.add(width: 9, height: 20) == "9:20", "9:20 is built in too")
        #expect(ratios.add(width: 7, height: 5) == "7:5", "typing one again brings it to the top")
        #expect(ratios.add(width: 0, height: 1) == nil)
        #expect(ratios.ratios == ["7:5", "5:4"])
        #expect(CustomCropRatios(defaults: defaults).ratios == ["7:5", "5:4"], "and after a relaunch")
        for side in 1...CustomCropRatios.limit { ratios.add(width: Double(side), height: 7) }
        #expect(ratios.ratios.count == CustomCropRatios.limit && ratios.ratios.first == "\(CustomCropRatios.limit):7")
    }

    @Test func aTypedRatioIsChosenAndShapesTheFrame() throws {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        session.selectTool(.crop)
        let ratios = CustomCropRatios(defaults: defaults())
        session.useCustomCropRatio(width: 9, height: 21, remembering: ratios)
        #expect(session.cropRatioChoice == "9:21" && ratios.ratios == ["9:21"])
        let rect = try #require(session.cropRect)
        #expect(abs(rect.width / rect.height - 9.0 / 21) < 0.01)
        session.useCustomCropRatio(width: -1, height: 2, remembering: ratios)
        #expect(session.cropRatioChoice == "9:21", "nothing changes for something that isn't a ratio")
    }

    /// The bar's Cancel ⊘ and Commit ✓ are Escape and Return on the canvas, which still end a pending crop.
    @Test func escapeCancelsAndReturnCommitsAPendingCrop() async throws {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        session.selectTool(.crop)
        let canvas = CanvasView(session: session)
        func press(_ characters: String, code: UInt16) {
            canvas.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code)!)
        }
        session.cropRect = CGRect(x: 10, y: 10, width: 200, height: 100)
        press("\u{1b}", code: 53)
        #expect(session.cropRect == nil && session.document?.width == 400)
        session.cropRect = CGRect(x: 10, y: 10, width: 200, height: 100)
        press("\r", code: 36)
        for _ in 0..<100 where session.document?.width != 200 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(session.document?.width == 200 && session.document?.height == 100 && session.cropRect == nil)
    }

    /// The Ratio pop-up names its choices as familiar editors do, and its W and H show the ratio's sides, which ⇄
    /// swaps and Clear empties.
    @Test func ratiosHaveFamiliarNamesAndSidesThatSwapAndClear() throws {
        #expect(CropRatio.builtIn.map(CropRatio.title) == ["Ratio", "Original Ratio", "1:1 (Square)", "4:3", "3:4", "16:9",
                                                         "9:16", "9:20", "2.39:1"])
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        session.selectTool(.crop)
        let ratios = CustomCropRatios(defaults: defaults())
        #expect(session.cropRatioSides == nil, "Ratio is free: W and H are empty")
        session.cropRatioChoice = "Original"
        #expect(session.cropRatioSides?.width == 400 && session.cropRatioSides?.height == 300)
        session.cropRatioChoice = "16:9"
        session.swapCropRatio(remembering: ratios)
        #expect(session.cropRatioChoice == "9:16" && ratios.ratios.isEmpty, "a built-in ratio turned on its side")
        session.cropRatioChoice = "2.39:1"
        #expect(session.cropRatioSides?.width == 2.39 && session.cropRatioSides?.height == 1)
        session.swapCropRatio(remembering: ratios)
        #expect(session.cropRatioChoice == "1:2.39" && ratios.ratios == ["1:2.39"])
        let rect = try #require(session.cropRect)
        #expect(abs(rect.width / rect.height - 1 / 2.39) < 0.01)
        session.clearCropRatio()
        #expect(session.cropRatioChoice == "Free" && session.cropRatioSides == nil)
        session.swapCropRatio(remembering: ratios)
        #expect(session.cropRatioChoice == "Free", "nothing to swap")
    }
}
