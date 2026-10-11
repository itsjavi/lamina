import AppKit
import Testing
@testable import LaminaApp

@MainActor
struct CheckerboardTests {
    /// The tile's pixels: the lighter square top-left and bottom-right, as the canvas has it.
    @Test func theTileMatchesTheCanvasCheckerboard() throws {
        var rect = NSRect(x: 0, y: 0, width: 20, height: 20)
        let image = try #require(Checkerboard.tile.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let rep = NSBitmapImageRep(cgImage: image)
        // NSBitmapImageRep's rows run from the top; a quarter and three quarters across are the squares' middles.
        func white(_ x: Double, _ y: Double) -> CGFloat {
            let color = rep.colorAt(x: Int(x * Double(rep.pixelsWide)), y: Int(y * Double(rep.pixelsHigh)))!
            return color.usingColorSpace(.genericGray)!.whiteComponent
        }
        #expect(abs(white(0.25, 0.25) - 0.35) < 0.01)
        #expect(abs(white(0.75, 0.75) - 0.35) < 0.01)
        #expect(abs(white(0.75, 0.25) - 0.30) < 0.01)
        #expect(abs(white(0.25, 0.75) - 0.30) < 0.01)
    }
}
