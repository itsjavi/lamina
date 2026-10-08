import CoreGraphics
import Foundation
import LaminaCore
import Testing

/// The manifest's value types on their own: versions, the folder hierarchy, document limits and adjustment settings.
struct ProjectModelTests {
    /// Saving writes `ProjectManifest.current` and `load` rejects anything outside
    /// `ProjectManifest.supported`, so the two have to agree or the app cannot reopen its own
    /// documents. This checks that directly, without touching the disk.
    @Test func theCurrentFormatVersionIsOneTheReaderAccepts() {
        #expect(ProjectManifest.supported.contains(ProjectManifest.current))
    }

    @Test func malformedParentLinksAndCyclesAreRejected() throws {
        let id = UUID(), child = UUID()
        let transform = LayerTransform(origin: .zero, size: CGSize(width: 10, height: 10))
        let group = ProjectLayerRecord(id: id, name: "Group", isVisible: true, transform: transform, imageFile: nil, parentID: child, isGroup: true)
        let nested = ProjectLayerRecord(id: child, name: "Nested", isVisible: true, transform: transform, imageFile: nil, parentID: id, isGroup: true)
        #expect(throws: ProjectError.self) { try LayerHierarchy.validate([group, nested]) }
        #expect(throws: ProjectError.self) { try LayerHierarchy.validate([group]) }
        var rasterParent = group
        rasterParent.parentID = nil
        rasterParent.isGroup = false
        #expect(throws: ProjectError.self) { try LayerHierarchy.validate([rasterParent, nested]) }
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

    @Test func bandWeightsRampThroughFalloffAndWrapAround() {
        let reds = ColorRange.reds.defaultBand // 315 / 345 / 15 / 45, wrapping past 0.
        #expect(reds.weight(of: 0) == 1 && reds.weight(of: 345) == 1 && reds.weight(of: 15) == 1)
        #expect(abs(reds.weight(of: 330) - 0.5) < 0.001)   // Halfway up the shoulder.
        #expect(abs(reds.weight(of: 30) - 0.5) < 0.001)    // Halfway down the far shoulder.
        #expect(reds.weight(of: 315) == 0 && reds.weight(of: 45) == 0 && reds.weight(of: 180) == 0)
        #expect(ColorRange.master.defaultBand.weight(of: 123) == 1)
        // Handles keep their order: crossing moves are refused.
        var band = ColorRange.greens.defaultBand
        band.setHandle(1, to: 200) // rangeStart past rangeEnd.
        #expect(band == ColorRange.greens.defaultBand)
        band.setHandle(1, to: 110)
        #expect(band.rangeStart == 110)
    }

    @Test func settingsSaveAndOlderAdjustmentsStillOpen() throws {
        let levels = LayerAdjustment(kind: .levels)
        let data = try JSONEncoder().encode(levels)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("exposureSettings"), "an existing kind saves exactly as before")
        #expect(!json.contains("gradientMapSettings"))
        #expect(!json.contains("grainSettings"))
        #expect(try JSONDecoder().decode(LayerAdjustment.self, from: data) == levels)
        var grain = LayerAdjustment(kind: .grain)
        grain.grain = GrainSettings(amount: 40, size: 3, roughness: 10, seed: 9)
        let decoded = try JSONDecoder().decode(LayerAdjustment.self, from: JSONEncoder().encode(grain))
        #expect(decoded == grain)
        #expect(decoded.isValid)
        var broken = LayerAdjustment(kind: .exposure)
        broken.exposure.gamma = 0
        #expect(!broken.isValid)
    }
}
