import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The brush tips, Dodge or Burn, and colors a document hands on to the next one.
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
        let soft = Tip(diameter: 40, hardness: 0, opacity: 1), hard = Tip(diameter: 40, hardness: 1, opacity: 1)
        session.selectTool(.brush)
        session.brushSettings.diameter = 12
        session.brushSettings.opacity = 0.5
        session.selectTool(.cloneStamp)
        #expect(session.brushDefaults.tips == [Tip(diameter: 12, hardness: 1, opacity: 0.5), soft, soft, hard, hard, soft])
        session.brushSettings.diameter = 80
        session.brushSettings.hardness = 0.3
        session.selectTool(.blur)
        session.brushSettings.diameter = 5
        session.selectTool(.eraser)
        session.brushSettings.diameter = 7
        session.selectTool(.burn)
        session.brushSettings.diameter = 9
        session.selectTool(.liquify)
        session.brushSettings.diameter = 300
        session.selectTool(.spotHealing)
        #expect(session.brushSettings.diameter == 12)
        #expect(session.brushDefaults.tips == [Tip(diameter: 12, hardness: 1, opacity: 0.5), Tip(diameter: 80, hardness: 0.3, opacity: 1),
                                               Tip(diameter: 5, hardness: 0, opacity: 1), Tip(diameter: 7, hardness: 1, opacity: 1),
                                               Tip(diameter: 9, hardness: 1, opacity: 1), Tip(diameter: 300, hardness: 0, opacity: 1)])
        // Tools that share a slot share a tip, and a tool that paints no tip leaves the Brush's in place.
        session.selectTool(.smudge)
        #expect(session.brushSettings.diameter == 5)
        session.selectTool(.dodge)
        #expect(session.brushSettings.diameter == 9)
        session.selectTool(.move)
        #expect(session.brushSettings.diameter == 12)
    }

    /// ⌘T goes to the Move tool directly; the next tool still finds the tip of the tool before it parked.
    @Test func aTransformFromAnotherBrushStillSwapsTheTipBack() throws {
        let session = EditorSession()
        session.createDocument(width: 40, height: 40)
        let image = try #require(try BrushRaster.context(width: 40, height: 40, mask: false).makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Layer"))
        session.selectTool(.cloneStamp)
        session.brushSettings.diameter = 90
        session.beginTransform()
        #expect(session.tool == .move)
        session.selectTool(.brush)
        #expect(session.brushSettings.diameter == 40)
        session.selectTool(.cloneStamp)
        #expect(session.brushSettings.diameter == 90)
    }

    @Test func dodgeOrBurnSmoothingAndColorsAreRecorded() {
        let session = EditorSession()
        session.selectTool(.burn)
        session.brushSettings.smoothing = 30
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        session.backgroundColor = PaletteColor(red: 0, green: 0, blue: 1)
        let defaults = session.brushDefaults
        #expect(defaults.burns && defaults.smoothing == 30)
        #expect(defaults.foreground == PaletteColor(red: 1, green: 0, blue: 0))
        #expect(defaults.background == PaletteColor(red: 0, green: 0, blue: 1))
    }

    @Test func aNewDocumentTakesOnWhatTheLastOneLeft() {
        var saved = BrushDefaults()
        saved.tips = [Tip(diameter: 3, hardness: 1, opacity: 0.8), Tip(diameter: 90, hardness: 0.2, opacity: 0.6),
                      Tip(diameter: 25, hardness: 0.5, opacity: 0.4), Tip(diameter: 14, hardness: 0.9, opacity: 1),
                      Tip(diameter: 60, hardness: 0.1, opacity: 0.3), Tip(diameter: 500, hardness: 0.4, opacity: 0.7)]
        saved.smoothing = 45
        saved.burns = true
        saved.foreground = PaletteColor(red: 0.2, green: 0.4, blue: 0.6)
        saved.background = PaletteColor(red: 1, green: 1, blue: 0)
        let session = EditorSession()
        session.apply(saved)
        #expect(session.brushDefaults == saved)
        #expect(session.brushSettings.diameter == 3 && session.brushSettings.opacity == 0.8 && session.brushSettings.smoothing == 45)
        #expect(session.tool(in: .dodge) == .burn && session.backgroundColor == saved.background)
        session.selectTool(.cloneStamp)
        #expect(session.brushSettings.diameter == 90 && session.brushSettings.hardness == 0.2 && session.brushSettings.opacity == 0.6)
        session.selectTool(.blur)
        #expect(session.brushSettings.diameter == 25 && session.brushSettings.hardness == 0.5)
        session.selectTool(.eraser)
        #expect(session.brushSettings.diameter == 14)
        session.pressToolKey("o")
        #expect(session.tool == .burn && session.brushSettings.diameter == 60)
        session.selectTool(.liquify)
        #expect(session.brushSettings.diameter == 500)
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
        first.toneRange = .highlights
        first.toneExposure = 0.8
        first.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        first.backgroundColor = PaletteColor(red: 0, green: 0, blue: 1)
        first.selectTool(.cloneStamp)
        first.brushSettings.diameter = 150
        first.selectTool(.burn)
        first.brushSettings.diameter = 33
        first.brushDefaults.save(since: BrushDefaults(), to: store)

        let loaded = BrushDefaults.load(from: store)
        #expect(loaded == first.brushDefaults)
        let next = EditorSession()
        next.apply(loaded)
        #expect(next.brushDefaults == first.brushDefaults)
        next.selectTool(.brush)
        #expect(next.brushSettings.diameter == 64 && next.brushSettings.hardness == 0.25 && next.brushSettings.opacity == 0.7)
        #expect(next.tool(in: .dodge) == .burn && next.foregroundColor == PaletteColor(red: 1, green: 0, blue: 0))
        next.selectTool(.eraser)
        #expect(next.brushSettings.diameter == 40, "the Eraser was never changed: its own default, not the Brush's tip")
    }

    /// Only what changed is written: a document doesn't overwrite what another one set since.
    @Test func onlyChangesAreWrittenAndBadValuesFallBack() {
        let store = Store()
        var old = BrushDefaults(), new = BrushDefaults()
        new.smoothing = 30
        new.save(since: old, to: store)
        #expect(store.object(forKey: "tool.brushSmoothing") as? Double == 30)
        #expect(store.object(forKey: "tool.brushSize") == nil && store.object(forKey: "tool.toneTool") == nil)
        old = new
        new[family: .clone].diameter = 99
        new.save(since: old, to: store)
        #expect(store.object(forKey: "tool.cloneSize") as? Double == 99 && store.object(forKey: "tool.brushSize") == nil)

        store.values["tool.brushSize"] = -5.0
        store.values["tool.brushHardness"] = Double.nan
        store.values["tool.toneTool"] = "Sideways"
        store.values["tool.foregroundColor"] = "not a color"
        let loaded = BrushDefaults.load(from: store)
        #expect(loaded[family: .brush] == Tip(diameter: 1, hardness: 1, opacity: 1))
        #expect(!loaded.burns && loaded.foreground == .black && loaded[family: .clone].diameter == 99)
    }

    /// Settings an earlier version saved, when Eraser, Dodge and Burn were the Brush's modes and Liquify a mode of
    /// Smear: those tools start with the tip they shared, a saved Burn mode puts Burn in the Dodge slot, and
    /// nothing else is lost.
    @Test func settingsSavedBeforeTheToolsSplitCarryOver() {
        func earlier(mode: String) -> Store {
            let store = Store()
            store.values = ["tool.brushSize": 12.0, "tool.brushHardness": 0.4, "tool.brushOpacity": 0.6,
                            "tool.cloneSize": 90.0, "tool.smearSize": 25.0, "tool.smearHardness": 0.3,
                            "tool.brushSmoothing": 30.0, "tool.brushFlow": 0.5, "tool.brushPressureSize": true,
                            "tool.brushMode": mode, "tool.toneRange": "Shadows", "tool.toneExposure": 0.2,
                            "tool.foregroundColor": "FF0000", "tool.backgroundColor": "0000FF"]
            return store
        }
        let store = earlier(mode: "Burn")
        let loaded = BrushDefaults.load(from: store)
        let brush = Tip(diameter: 12, hardness: 0.4, opacity: 0.6), smear = Tip(diameter: 25, hardness: 0.3, opacity: 1)
        #expect(loaded.tips == [brush, Tip(diameter: 90, hardness: 0, opacity: 1), smear, brush, brush, smear])
        #expect(loaded.burns && loaded.toneRange == .shadows && loaded.toneExposure == 0.2)
        #expect(loaded.smoothing == 30 && loaded.flow == 0.5 && loaded.pressureSize)
        #expect(loaded.foreground == PaletteColor(red: 1, green: 0, blue: 0) && loaded.background == PaletteColor(red: 0, green: 0, blue: 1))
        for mode in ["Paint", "Erase", "Dodge"] { #expect(!BrushDefaults.load(from: earlier(mode: mode)).burns, "\(mode)") }

        // The first save writes the inherited tips out; from then on each tool keeps its own, whatever the Brush does.
        loaded.save(since: BrushDefaults(), to: store)
        var changed = loaded
        changed[family: .brush].diameter = 200
        changed.save(since: loaded, to: store)
        let later = BrushDefaults.load(from: store)
        #expect(later[family: .brush].diameter == 200 && later[family: .eraser] == brush && later[family: .tone] == brush)
        #expect(later.burns)
    }
}
