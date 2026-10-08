import Foundation
import LaminaCore
import Testing

/// Per-letter colors and faces in a text layer's style, as typing and the Type bar change them.
struct LayerTextStyleTests {
    private let red = PaletteColor(red: 1, green: 0, blue: 0)

    @Test func colorAppliesToSelectionAndFollowsEdits() {
        var style = LayerTextStyle()
        style.content = "Hello world"
        style.setColor(red, in: NSRange(location: 6, length: 5))
        #expect(style.colorRuns == [LayerTextColorRun(location: 6, length: 5, red: 1, green: 0, blue: 0)])
        #expect(style.color(at: 5) == .black && style.color(at: 6) == red)
        // Painting next to a run in the same color joins it.
        style.setColor(red, in: NSRange(location: 5, length: 1))
        #expect(style.colorRuns?.count == 1 && style.colorRuns?.first?.location == 5)

        // Typed letters take the color of the one before them; deleted ones take their color away.
        style.replaceCharacters(in: NSRange(location: 11, length: 0), withLength: 1)
        style.content += "!"
        #expect(style.isValid && style.color(at: 11) == red)
        style.replaceCharacters(in: NSRange(location: 0, length: 2), withLength: 0)
        style.content.removeFirst(2)
        #expect(style.isValid && style.colorRuns?.first?.location == 3 && style.colorRuns?.first?.length == 7)

        // No selection, or all of it, recolors the whole text.
        style.setColor(red, in: NSRange(location: 4, length: 0))
        #expect(style.colorRuns == nil && style.red == 1)
    }

    @Test func invalidColorRunsAreRejected() {
        var style = LayerTextStyle()
        style.content = "Text"
        style.colorRuns = [LayerTextColorRun(location: 2, length: 3, red: 1, green: 0, blue: 0)]
        #expect(!style.isValid)
        style.colorRuns = [LayerTextColorRun(location: 0, length: 2, red: 1, green: 0, blue: 0),
                           LayerTextColorRun(location: 1, length: 2, red: 0, green: 1, blue: 0)]
        #expect(!style.isValid)
        style.colorRuns = [LayerTextColorRun(location: 0, length: 1, red: 2, green: 0, blue: 0)]
        #expect(!style.isValid)
    }

    @Test func fontAppliesToTheSelectionOnly() {
        var style = LayerTextStyle()
        style.content = "Hello"
        style.fontName = "Helvetica"
        style.setFont("Courier", in: NSRange(location: 0, length: 2))
        #expect(style.fontName == "Helvetica")
        #expect(style.fontRuns == [LayerTextFontRun(location: 0, length: 2, fontName: "Courier")])
        #expect(style.fontName(at: 0) == "Courier" && style.fontName(at: 2) == "Helvetica")
        #expect(style.uniformFontName(in: NSRange(location: 0, length: 2)) == "Courier")
        #expect(style.uniformFontName(in: NSRange(location: 0, length: 5)) == nil)
        style.setFont("Courier", in: NSRange(location: 0, length: 5))
        #expect(style.fontRuns == nil && style.fontName == "Courier")
        style.setFont("Helvetica", in: NSRange(location: 0, length: 2))
        #expect(style.fontRuns == [LayerTextFontRun(location: 0, length: 2, fontName: "Helvetica")])
        style.setFont("Courier", in: NSRange(location: 0, length: 0))
        #expect(style.fontRuns == nil && style.fontName == "Courier")
        style.setFont("Helvetica", in: NSRange(location: 1, length: 3))
        style.replaceCharacters(in: NSRange(location: 5, length: 0), withLength: 1)
        style.content += "!"
        #expect(style.isValid && style.fontName(at: 5) == "Courier")
    }
}
