import AppKit
import Foundation
import Testing
import LaminaCore
@testable import LaminaApp

/// The Adjustments panel: what it lists, in which order, and what a click does. The dock layout gets its own defaults
/// suite, so nothing touches the person's settings.
@MainActor struct AdjustmentsPanelTests {
    private let layout: DockLayout
    init() {
        let suite = "AdjustmentsPanelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        layout = DockLayout(defaults: defaults)
    }

    @Test func listsEveryKindOnceInTheSpecsOrder() {
        #expect(AdjustmentsPanel.adjustments.map(\.rawValue) == ["Grain", "Levels", "Curves", "Exposure", "Hue/Saturation",
                                                                 "Color Balance", "Black & White", "Invert", "Gradient Map"])
        #expect(AdjustmentsPanel.filterLayers.map(\.rawValue) == ["Gaussian Blur", "Motion Blur", "Add Noise"])
        let listed = AdjustmentsPanel.adjustments + AdjustmentsPanel.filterLayers
        #expect(Set(listed) == Set(AdjustmentKind.allCases) && listed.count == AdjustmentKind.allCases.count)
    }

    @Test func everySymbolExistsAndIsItsOwn() {
        let symbols = AdjustmentKind.allCases.map(\.panelSymbol)
        #expect(Set(symbols).count == symbols.count)
        for symbol in symbols { #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)") }
    }

    @Test func clickAddsAboveTheActiveLayerAsOneUndoStepAndShowsProperties() throws {
        let session = EditorSession(); session.createDocument(width: 2, height: 2)
        session.addBlankLayer(); session.addBlankLayer()
        let layers = try #require(session.document?.layers)
        let active = layers[0].id
        session.selectLayer(active)
        layout.show(.adjustments)

        AdjustmentsPanel.add(.curves, session: session, layout: layout)
        let after = try #require(session.document?.layers)
        #expect(after.count == layers.count + 1)
        #expect(after[1].adjustment?.kind == .curves && after[1].name == "Curves")
        #expect(session.activeLayerID == after[1].id)
        #expect(layout.isVisible(.properties))

        session.adjustmentEditingID = nil
        session.undo()
        #expect(session.document?.layers.map(\.id) == layers.map(\.id))
    }

    @Test func disabledWithoutADocumentOrWhileLayersAreBusy() throws {
        let empty = EditorSession()
        #expect(!AdjustmentsPanel.canAdd(empty))
        AdjustmentsPanel.add(.levels, session: empty, layout: layout)
        #expect(empty.document == nil && !layout.isVisible(.adjustments) && layout.isVisible(.properties))

        let session = EditorSession(); session.createDocument(width: 2, height: 2)
        #expect(AdjustmentsPanel.canAdd(session))
        session.addAdjustment(.levels)
        // Its settings are open, so the session refuses layer edits, as the menu does.
        #expect(session.adjustmentEditingID != nil && !AdjustmentsPanel.canAdd(session))
        let count = session.document?.layers.count
        layout.show(.adjustments)
        AdjustmentsPanel.add(.grain, session: session, layout: layout)
        #expect(session.document?.layers.count == count && layout.isVisible(.adjustments))
    }
}
