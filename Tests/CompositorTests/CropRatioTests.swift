import AppKit
import SwiftUI
import Testing
@testable import Compositor

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
        #expect(CropRatio.value("Free") == nil && CropRatio.value("Original") == nil && CropRatio.value(CropRatio.customTag) == nil)
        #expect(CropRatio.value("0:3") == nil && CropRatio.value("3:") == nil)
    }

    @Test func typedRatiosAreRememberedNewestFirst() {
        let defaults = defaults()
        let ratios = CustomCropRatios(defaults: defaults)
        #expect(ratios.ratios.isEmpty)
        #expect(ratios.add(width: 9, height: 20) == "9:20")
        #expect(ratios.add(width: 5, height: 4) == "5:4")
        #expect(ratios.add(width: 4, height: 3) == "4:3", "a built-in ratio is chosen, not added")
        #expect(ratios.add(width: 9, height: 20) == "9:20", "typing one again brings it to the top")
        #expect(ratios.add(width: 0, height: 1) == nil)
        #expect(ratios.ratios == ["9:20", "5:4"])
        #expect(CustomCropRatios(defaults: defaults).ratios == ["9:20", "5:4"], "and after a relaunch")
        for side in 1...CustomCropRatios.limit { ratios.add(width: Double(side), height: 7) }
        #expect(ratios.ratios.count == CustomCropRatios.limit && ratios.ratios.first == "\(CustomCropRatios.limit):7")
    }

    @Test func aCustomRatioIsChosenAndShapesTheFrame() throws {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        session.selectTool(.crop)
        let ratios = CustomCropRatios(defaults: defaults())
        session.useCustomCropRatio(width: 9, height: 20, remembering: ratios)
        #expect(session.cropRatioChoice == "9:20" && ratios.ratios == ["9:20"])
        let rect = try #require(session.cropRect)
        #expect(abs(rect.width / rect.height - 0.45) < 0.01)
        session.useCustomCropRatio(width: -1, height: 2, remembering: ratios)
        #expect(session.cropRatioChoice == "9:20", "nothing changes for something that isn't a ratio")
    }

    /// Custom… in the picker asks for a ratio rather than being one: the frame keeps the ratio it had.
    @Test func choosingCustomKeepsTheRatioItHad() async throws {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300)
        session.selectTool(.crop)
        session.cropRatioChoice = "4:3"
        let window = NSWindow(contentRect: CGRect(x: -4000, y: -4000, width: 900, height: 60), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CropControls(session: session, ratios: CustomCropRatios(defaults: nil)))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(100))
        session.cropRatioChoice = CropRatio.customTag
        for _ in 0..<20 where session.cropRatioChoice == CropRatio.customTag { try await Task.sleep(for: .milliseconds(20)) }
        #expect(session.cropRatioChoice == "4:3")
    }
}
