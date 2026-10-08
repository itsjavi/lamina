import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The brush tips, mode and colors a document hands on to the next one.
@MainActor
struct BrushDefaultsTests {
    private typealias Tip = BrushDefaults.Tip

    /// A store of the test's own, in memory, standing in for the app's defaults, which tests never touch.
    private final class Store: ToolDefaultsStore {
        var values: [String: Any] = [:]
        func object(forKey defaultName: String) -> Any? { values[defaultName] }
        func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    }

    @Test func aNewDocumentStartsFromTheCompiledDefaults() {
        #expect(EditorSession().brushDefaults == BrushDefaults())
        #expect(BrushDefaults.load() == BrushDefaults(), "tests never read the app's defaults")
        #expect(ProjectTab(name: "Untitled").session.brushDefaults == BrushDefaults())
    }

    /// Switching tools swaps the tip in `brushSettings` before the tool changes; each tip must still be
    /// recorded as its own family's, never the one being switched to.
    @Test func eachToolFamilyKeepsItsOwnTip() {
        let session = EditorSession()
        session.selectTool(.brush)
        session.brushSettings.diameter = 12
        session.brushSettings.opacity = 0.5
        session.selectTool(.cloneStamp)
        #expect(session.brushDefaults.tips == [Tip(diameter: 12, hardness: 1, opacity: 0.5),
                                               Tip(diameter: 40, hardness: 0, opacity: 1), Tip(diameter: 40, hardness: 0, opacity: 1)])
        session.brushSettings.diameter = 80
        session.brushSettings.hardness = 0.3
        session.selectTool(.blur)
        session.brushSettings.diameter = 5
        session.selectTool(.spotHealing)
        #expect(session.brushSettings.diameter == 12)
        #expect(session.brushDefaults.tips == [Tip(diameter: 12, hardness: 1, opacity: 0.5),
                                               Tip(diameter: 80, hardness: 0.3, opacity: 1), Tip(diameter: 5, hardness: 0, opacity: 1)])
    }

    @Test func modeSmoothingAndColorsAreRecorded() {
        let session = EditorSession()
        session.brushMode = .erase
        session.brushSettings.smoothing = 30
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        session.backgroundColor = PaletteColor(red: 0, green: 0, blue: 1)
        let defaults = session.brushDefaults
        #expect(defaults.mode == .erase && defaults.smoothing == 30)
        #expect(defaults.foreground == PaletteColor(red: 1, green: 0, blue: 0))
        #expect(defaults.background == PaletteColor(red: 0, green: 0, blue: 1))
    }

    @Test func aNewDocumentTakesOnWhatTheLastOneLeft() {
        var saved = BrushDefaults()
        saved.tips = [Tip(diameter: 3, hardness: 1, opacity: 0.8), Tip(diameter: 90, hardness: 0.2, opacity: 0.6),
                      Tip(diameter: 25, hardness: 0.5, opacity: 0.4)]
        saved.smoothing = 45
        saved.mode = .erase
        saved.foreground = PaletteColor(red: 0.2, green: 0.4, blue: 0.6)
        saved.background = PaletteColor(red: 1, green: 1, blue: 0)
        let session = EditorSession()
        session.apply(saved)
        #expect(session.brushDefaults == saved)
        #expect(session.brushSettings.diameter == 3 && session.brushSettings.opacity == 0.8 && session.brushSettings.smoothing == 45)
        #expect(session.brushMode == .erase && session.backgroundColor == saved.background)
        session.selectTool(.cloneStamp)
        #expect(session.brushSettings.diameter == 90 && session.brushSettings.hardness == 0.2 && session.brushSettings.opacity == 0.6)
        session.selectTool(.blur)
        #expect(session.brushSettings.diameter == 25 && session.brushSettings.hardness == 0.5)
    }

    /// What one document leaves is written out and read back as a later launch reads it, into a document of its own.
    @Test func whatIsSavedIsReadBackOnTheNextLaunch() {
        let store = Store()
        #expect(BrushDefaults.load(from: store) == BrushDefaults(), "nothing saved yet: the compiled defaults")
        let first = EditorSession()
        first.selectTool(.brush)
        first.brushSettings.diameter = 64
        first.brushSettings.hardness = 0.25
        first.brushSettings.opacity = 0.7
        first.brushSettings.smoothing = 20
        first.brushSettings.flow = 0.35
        first.brushSettings.pressureSize = true
        first.brushMode = .erase
        first.toneRange = .highlights
        first.toneExposure = 0.8
        first.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        first.backgroundColor = PaletteColor(red: 0, green: 0, blue: 1)
        first.selectTool(.cloneStamp)
        first.brushSettings.diameter = 150
        first.brushDefaults.save(since: BrushDefaults(), to: store)

        let loaded = BrushDefaults.load(from: store)
        #expect(loaded == first.brushDefaults)
        let next = EditorSession()
        next.apply(loaded)
        #expect(next.brushDefaults == first.brushDefaults)
        next.selectTool(.brush)
        #expect(next.brushSettings.diameter == 64 && next.brushSettings.hardness == 0.25 && next.brushSettings.opacity == 0.7)
        #expect(next.brushMode == .erase && next.foregroundColor == PaletteColor(red: 1, green: 0, blue: 0))
    }

    /// Only what changed is written: a document doesn't overwrite what another one set since.
    @Test func onlyChangesAreWrittenAndBadValuesFallBack() {
        let store = Store()
        var old = BrushDefaults(), new = BrushDefaults()
        new.smoothing = 30
        new.save(since: old, to: store)
        #expect(store.object(forKey: "tool.brushSmoothing") as? Double == 30)
        #expect(store.object(forKey: "tool.brushSize") == nil && store.object(forKey: "tool.brushMode") == nil)
        old = new
        new.tips[1].diameter = 99
        new.save(since: old, to: store)
        #expect(store.object(forKey: "tool.cloneSize") as? Double == 99 && store.object(forKey: "tool.brushSize") == nil)

        store.values["tool.brushSize"] = -5.0
        store.values["tool.brushHardness"] = Double.nan
        store.values["tool.brushMode"] = "Sideways"
        store.values["tool.foregroundColor"] = "not a color"
        let loaded = BrushDefaults.load(from: store)
        #expect(loaded.tips[0] == Tip(diameter: 1, hardness: 1, opacity: 1))
        #expect(loaded.mode == .paint && loaded.foreground == .black && loaded.tips[1].diameter == 99)
    }
}
