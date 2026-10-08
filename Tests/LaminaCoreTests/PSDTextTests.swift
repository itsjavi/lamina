import CoreGraphics
import Foundation
import LaminaCore
import PSDFixtures
import Testing

/// Photoshop type layers (`TySh`) read into a text style and where it sits. Drawing them is the app's.
struct PSDTextTests {
    @Test func photoshopTextSizeUsesMatrixScaleNotDocumentResolution() {
        // Identity scale keeps the engine size whether the document is 72 or 300 PPI.
        #expect(PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello")])?.style.fontSize == 24)
        #expect(PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", xx: 2, yy: 2)])?.style.fontSize == 48)
        // Non-1 scale and a non-72 document resolution still multiply by the matrix only.
        #expect(PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", fontSize: 25, xx: 2, yy: 2)])?.style.fontSize == 50)
    }

    @Test func photoshopTextKeepsTheFirstStyleAndReportsTheRest() {
        let parsed = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", red: 1, green: 0, blue: 0, justification: 2, tracking: 1000, leading: 30, secondSize: 48)])
        #expect(parsed?.style.content == "Hello")
        #expect(parsed?.style.alignment == .center)
        #expect(parsed?.style.tracking == 24)
        #expect(parsed?.style.leading == 30)
        #expect(parsed?.style.red == 1)
        #expect(parsed?.style.fontSize == 24)
        #expect(parsed?.notes.contains(PSDText.firstStyleNote) == true)
    }

    @Test func photoshopTextReportsLeadingOnlyStyleDifferences() {
        let byLeading = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", leading: 30, secondLeading: 48)])
        #expect(byLeading?.style.leading == 30)
        #expect(byLeading?.notes.contains(PSDText.firstStyleNote) == true)
        let byScale = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", secondHorizontalScale: 1.2)])
        #expect(byScale?.notes.contains(PSDText.firstStyleNote) == true)
    }

    @Test func photoshopParagraphTextKeepsItsBox() {
        let parsed = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", tx: 10, ty: 30, bounds: (0, 0, 200, 80), glyphBounds: (0, -10, 40, 10))])
        #expect(parsed?.anchorIsFrame == true)
        #expect(parsed?.style.boxSize?.width == 224)
        #expect(parsed?.style.boxSize?.height == 104)
        #expect(parsed?.documentAnchor == CGPoint(x: 10, y: 30))
    }

    @Test func warpedPhotoshopTextStaysEditableAndSaysSo() {
        let parsed = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", fauxBold: true, warp: true)])
        #expect(parsed?.style.content == "Hello")
        #expect(parsed?.notes.contains(PSDText.warpNote) == true)
        #expect(parsed?.notes.contains(PSDText.fauxNote) == true)
    }

    @Test func rotatedPhotoshopTextKeepsItsAngle() {
        let parsed = PSDText.parse(extra: ["TySh": PSDFixture.tySh(text: "Hello", xx: 0, xy: -1, yx: 1, yy: 0)])
        #expect(abs((parsed?.rotation ?? 0) - 90) < 0.01)
        #expect(parsed?.flipY == false)
    }
}
