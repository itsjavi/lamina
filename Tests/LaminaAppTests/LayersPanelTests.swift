import AppKit
import Testing
import LaminaCore
@testable import LaminaApp

/// The Layers panel's rows (docs/DESIGN.md, Dock and panels ▸ Layers): one line each, thumbnails that pick what edits
/// target, and styled layers' effect rows with their own eyes.
@MainActor
struct LayersPanelTests {
    /// A 100 × 100 document with a 40 × 40 red layer, "Square".
    private func sessionWithSquare() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 100, height: 100)
        let context = try BrushRaster.context(width: 40, height: 40, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Square"))
        return session
    }

    private func list(_ session: EditorSession) -> (LayerTableView, NativeLayerList.Coordinator, NSWindow) {
        let coordinator = NativeLayerList.Coordinator(session: session)
        let table = LayerTableView()
        table.session = session
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layer"))
        column.width = 292
        table.addTableColumn(column)
        table.delegate = coordinator
        table.dataSource = coordinator
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 292, height: 400))
        scroll.documentView = table
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        coordinator.update(table)
        return (table, coordinator, window)
    }

    private func descendants(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap { descendants($0) } }

    /// The button in the first row whose accessibility label is `label`.
    private func button(_ label: String, in table: NSTableView, row: Int = 0) throws -> NSButton {
        let cell = try #require(table.view(atColumn: 0, row: row, makeIfNecessary: true))
        cell.layoutSubtreeIfNeeded()
        return try #require(descendants(cell).compactMap { $0 as? NSButton }.first {
            !$0.isHiddenOrHasHiddenAncestor && $0.accessibilityLabel() == label
        }, "no button \(label)")
    }

    @Test func clickingTheLayerOrTheMaskThumbnailPicksWhatEditsTarget() throws {
        let session = try sessionWithSquare()
        session.addLayerMask(revealing: true)
        #expect(session.isMaskSelected && session.propertiesKind == .mask, "a new mask is the target")
        let (table, coordinator, _) = list(session)
        #expect(table.rect(ofRow: 0).height == 32, "one line, mask or not")

        try button("Select image: Square", in: table).performClick(nil)
        coordinator.update(table)
        #expect(!session.isMaskSelected)
        #expect(session.propertiesKind == .pixel, "Properties follows the target")

        try button("Select mask: Square", in: table).performClick(nil)
        coordinator.update(table)
        #expect(session.isMaskSelected)
        #expect(session.propertiesKind == .mask)
    }

    @Test func styledLayersListAnEffectsRowAndOneRowPerEffectEachWithAnEye() throws {
        let session = try sessionWithSquare()
        let id = try #require(session.activeLayerID)
        var effects = LayerEffects()
        effects.shadow = ShadowEffect()
        effects.stroke = StrokeEffect()
        session.setEffects(effects, name: "Add Effects")
        let (table, coordinator, _) = list(session)
        #expect(table.rect(ofRow: 0).height == 98, "the layer’s line, Effects, Stroke and Drop Shadow")
        let cell = try #require(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        let rows = descendants(cell).compactMap { $0.accessibilityLabel() }.filter { $0.hasSuffix(" effect") }
        #expect(rows == ["Stroke effect", "Drop Shadow effect"], "in the Layer Style dialog's order")

        // An effect's eye hides that effect alone, as one undo step.
        let steps = session.history.undoCount
        try button("Hide Drop Shadow", in: table).performClick(nil)
        var layer = try #require(session.activeLayer)
        #expect(layer.effects?.isEnabled(.shadow) == false && layer.effects?.isEnabled(.stroke) == true)
        #expect(session.history.undoCount == steps + 1)
        coordinator.update(table)
        try button("Show Drop Shadow", in: table).performClick(nil)
        #expect(session.activeLayer?.effects?.isEnabled(.shadow) == true)

        // The Effects row's eye hides them all, then shows them all, a step each.
        coordinator.update(table)
        try button("Hide Effects", in: table).performClick(nil)
        layer = try #require(session.activeLayer)
        #expect(layer.effects?.isEnabled(.shadow) == false && layer.effects?.isEnabled(.stroke) == false)
        coordinator.update(table)
        try button("Show Effects", in: table).performClick(nil)
        layer = try #require(session.activeLayer)
        #expect(layer.effects?.isEnabled(.shadow) == true && layer.effects?.isEnabled(.stroke) == true)
        session.undo()
        #expect(session.activeLayer?.effects?.isEnabled(.stroke) == false)

        // The fx badge's triangle folds the effect rows away and back.
        coordinator.update(table)
        try button("Hide effects: Square", in: table).performClick(nil)
        #expect(session.collapsedEffectLayerIDs == [id])
        coordinator.update(table)
        #expect(table.rect(ofRow: 0).height == 32)
        try button("Show effects: Square", in: table).performClick(nil)
        coordinator.update(table)
        #expect(table.rect(ofRow: 0).height == 98)
    }

    @Test func groupsAreCalledGroups() throws {
        let session = try sessionWithSquare()
        session.addGroup()
        #expect(session.activeLayer?.name == "Group 1")
        let square = try #require(session.document?.layers.first { $0.name == "Square" }?.id)
        session.selectLayer(square)
        session.groupSelectedLayers()
        #expect(session.activeLayer?.name == "Group 2")
        let (table, coordinator, _) = list(session)
        #expect(try button("Collapse group", in: table).isEnabled)
        let menu = try #require(coordinator.contextMenu(for: 0))
        #expect(menu.items.contains { $0.title == "Move Out of Group" })
        #expect(!menu.items.contains { $0.title.localizedCaseInsensitiveContains("folder") })
    }

    /// Twenty layers over two collapsed groups, Other and Title, each holding one layer; Title's is Headline. The list
    /// (400 pt high) shows twelve rows and part of a thirteenth.
    private func sessionWithCollapsedGroups() throws -> (EditorSession, title: UUID, other: UUID, headline: UUID) {
        let session = EditorSession()
        session.createDocument(width: 100, height: 100)
        session.addGroup()
        let title = try #require(session.activeLayerID)
        session.addBlankLayer()
        let headline = try #require(session.activeLayerID)
        session.selectLayer(nil)
        session.addGroup()
        let other = try #require(session.activeLayerID)
        session.addBlankLayer()
        session.selectLayer(nil)
        for _ in 0..<20 { session.addBlankLayer() }
        session.collapsedGroupIDs = [title, other]
        return (session, title, other, headline)
    }

    @Test func aLayerPickedOutsideTheListOpensItsGroupsAndScrollsIntoView() throws {
        let (session, _, other, headline) = try sessionWithCollapsedGroups()
        let (table, coordinator, _) = list(session)
        #expect(table.numberOfRows == 22, "twenty layers and the two groups, folded")
        #expect(table.visibleRect.minY == 0)
        // Picked on the canvas (Auto-Select, Command-click) or by `lamina select-layer`.
        session.selectLayerTarget(headline, mask: false)
        #expect(session.collapsedGroupIDs == [other], "only the groups around it open")
        coordinator.update(table)
        let row = try #require(session.layerRows.firstIndex { $0.layer.id == headline })
        #expect(row == 22)
        #expect(table.selectedRowIndexes == [row])
        #expect(table.visibleRect.contains(table.rect(ofRow: row)), "scrolled into view")

        // Scrolled away by hand, it stays where it was put through later updates.
        table.scroll(.zero)
        session.renameLayer(headline, to: "Headline")
        coordinator.update(table)
        #expect(table.visibleRect.minY == 0)

        // A Command-Shift-click on the canvas adds a layer in a folded group the same way.
        session.collapsedGroupIDs = [other]
        coordinator.update(table)
        let inOther = try #require(session.document?.layers.first { $0.parentID == other }?.id)
        session.extendSelection(with: inOther)
        #expect(session.collapsedGroupIDs.isEmpty && session.selectedLayerIDs == [headline, inOther])
        coordinator.update(table)
        let otherRow = try #require(session.layerRows.firstIndex { $0.layer.id == inOther })
        #expect(table.visibleRect.contains(table.rect(ofRow: otherRow)))
    }

    @Test func pickingInTheListNeitherScrollsItNorOpensGroups() throws {
        let (session, title, other, _) = try sessionWithCollapsedGroups()
        let (table, coordinator, _) = list(session)
        // Row 12 shows only its top half.
        #expect(table.visibleRect.intersects(table.rect(ofRow: 12)) && !table.visibleRect.contains(table.rect(ofRow: 12)))
        table.selectRowIndexes([12], byExtendingSelection: false)
        #expect(session.activeLayerID == session.layerRows[12].layer.id, "the list's own selection")
        coordinator.update(table)
        #expect(table.visibleRect.minY == 0, "the list doesn't move under the pointer")
        #expect(session.collapsedGroupIDs == [title, other])

        // A group picked in the list stays folded.
        let titleRow = try #require(session.layerRows.firstIndex { $0.layer.id == title })
        table.scrollRowToVisible(titleRow)
        let scrolled = table.visibleRect.minY
        table.selectRowIndexes([titleRow], byExtendingSelection: false)
        coordinator.update(table)
        #expect(session.activeLayerID == title && session.collapsedGroupIDs == [title, other])
        #expect(table.visibleRect.minY == scrolled)
    }

    @Test func aListUpdatedBeforeItIsLaidOutStartsAtTheTop() throws {
        let (session, _, _, _) = try sessionWithCollapsedGroups()
        session.selectLayer(session.layerRows[18].layer.id)
        // NativeLayerList.makeNSView updates the list before SwiftUI gives it a size.
        let coordinator = NativeLayerList.Coordinator(session: session)
        let table = LayerTableView()
        table.session = session
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layer")))
        table.delegate = coordinator
        table.dataSource = coordinator
        let scroll = NSScrollView(frame: .zero)
        scroll.documentView = table
        coordinator.update(table)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 292, height: 400), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = scroll
        coordinator.update(table)
        #expect(table.visibleRect.height > 0 && table.visibleRect.contains(table.rect(ofRow: 0)))
    }

    @Test func newFillOrAdjustmentLayerListsTheLayerMenusOrder() {
        #expect(LayersPanel.adjustmentMenu.flatMap { $0 } == [.grain, .levels, .curves, .exposure, .hsv, .colorBalance,
                                                             .blackWhite, .invert, .gradientMap,
                                                             .gaussianBlur, .motionBlur, .addNoise])
        #expect(Set(LayersPanel.adjustmentMenu.flatMap { $0 }) == Set(AdjustmentKind.allCases))
    }
}
