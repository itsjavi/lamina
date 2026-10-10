import AppKit
import SwiftUI
import LaminaCore

/// Native mouse-down selection and drag tracking, without a double-click delay.
struct NativeLayerList: NSViewRepresentable {
    let session: EditorSession
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = LayerTableView()
        table.session = session
        table.headerView = nil
        table.backgroundColor = .clear
        table.style = .plain
        table.rowHeight = LayerCell.lineHeight
        table.intercellSpacing = .zero
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layer"))
        column.width = 252
        table.addTableColumn(column)
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.renameClickedLayer(_:))
        table.action = #selector(Coordinator.clickedLayer(_:))
        table.registerForDraggedTypes([Coordinator.layerType, Coordinator.maskType, Coordinator.effectType])
        table.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        table.setAccessibilityIdentifier("layersList")
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        context.coordinator.update(table)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        if let table = scroll.documentView as? NSTableView { context.coordinator.update(table) }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation {
        static let layerType = NSPasteboard.PasteboardType("com.itsjavi.lamina.layer-row")
        /// An Option-drag from a mask thumbnail: the id of the layer whose mask is being copied.
        static let effectType = NSPasteboard.PasteboardType("com.itsjavi.lamina.layer-effect")
        static let maskType = NSPasteboard.PasteboardType("com.itsjavi.lamina.layer-mask")
        let session: EditorSession
        private var rows: [ImageLayer] = []
        private var rowDetails: [UUID: LayerHierarchy.Entry] = [:]
        private var oldCollapsed: Set<UUID> = []
        /// The styled layers whose effect rows are folded, as the rows' heights were last worked out.
        private var collapsedEffects: Set<UUID> = []
        private var editingEnabled = false
        private var synchronizing = false
        /// The active layer as the list last showed it (see `update`).
        private var shownActiveLayerID: UUID?
        init(session: EditorSession) { self.session = session }

        func update(_ table: NSTableView) {
            let entries = session.layerRows
            let byID = Dictionary(uniqueKeysWithValues: (session.document?.layers ?? []).map { ($0.id, $0) })
            let next = entries.compactMap { byID[$0.layer.id] }
            // A layer made active since the last update whose row was out of sight — picked on the canvas or by a
            // command, perhaps inside a group that has just opened — is scrolled into view. Whatever is picked in the
            // list itself was in sight, so the list never moves under the pointer, and a later update never undoes a
            // scroll the person made. A list not laid out yet (just made) has nothing in sight to scroll, and starts
            // at the top.
            var revealed: UUID?
            if shownActiveLayerID != session.activeLayerID, let id = session.activeLayerID, !table.visibleRect.isEmpty {
                let shown = table.rows(in: table.visibleRect)
                if rows.firstIndex(where: { $0.id == id }).map({ !NSLocationInRange($0, shown) }) ?? true { revealed = id }
            }
            shownActiveLayerID = session.activeLayerID
            let previousDetails = rowDetails
            rowDetails = Dictionary(uniqueKeysWithValues: entries.map { ($0.layer.id, $0) })
            let expansionChanged = oldCollapsed != session.collapsedGroupIDs
            oldCollapsed = session.collapsedGroupIDs
            let oldCollapsedEffects = collapsedEffects
            collapsedEffects = session.collapsedEffectLayerIDs
            let enabled = session.canEditLayers
            synchronizing = true
            defer { synchronizing = false }
            let old = rows
            rows = next
            let editableChanged = editingEnabled != enabled
            editingEnabled = enabled
            if old.map(\.id) != next.map(\.id) {
                table.reloadData()
            } else {
                let resized = IndexSet(next.indices.filter {
                    Self.height(of: old[$0], collapsedEffects: oldCollapsedEffects) != Self.height(of: next[$0], collapsedEffects: collapsedEffects)
                })
                // Selection never reloads cells or recreates thumbnails.
                let changed = IndexSet(next.indices.filter {
                    editableChanged || expansionChanged || resized.contains($0) || (old[$0].name != next[$0].name || old[$0].isVisible != next[$0].isVisible || old[$0].size != next[$0].size || old[$0].parentID != next[$0].parentID || old[$0].isGroup != next[$0].isGroup || old[$0].asset?.image !== next[$0].asset?.image || (old[$0].liveText != nil) != (next[$0].liveText != nil) || old[$0].effects != next[$0].effects || old[$0].mask != next[$0].mask || old[$0].maskSourceID != next[$0].maskSourceID) || previousDetails[next[$0].id]?.depth != rowDetails[next[$0].id]?.depth || previousDetails[next[$0].id]?.visible != rowDetails[next[$0].id]?.visible
                })
                // Adding, removing or folding effects only changes how tall a row is. Left to AppKit that is animated, and
                // the row appears to be taken away and put back; here it simply becomes its new height.
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0
                if !resized.isEmpty { table.noteHeightOfRows(withIndexesChanged: resized) }
                if !changed.isEmpty { table.reloadData(forRowIndexes: changed, columnIndexes: IndexSet(integer: 0)) }
                NSAnimationContext.endGrouping()
            }
            let indices = IndexSet(next.indices.filter { session.selectedEffect == nil && session.selectedLayerIDs.contains(next[$0].id) })
            if table.selectedRowIndexes != indices { table.selectRowIndexes(indices, byExtendingSelection: false) }
            if let revealed, let row = next.firstIndex(where: { $0.id == revealed }) { table.scrollRowToVisible(row) }
            // Border-only updates: selecting a target never rebuilds thumbnails or canvas pixels.
            let visible = table.rows(in: table.visibleRect)
            if visible.location != NSNotFound {
                for row in visible.location..<min(next.count, NSMaxRange(visible)) {
                    (table.view(atColumn: 0, row: row, makeIfNecessary: false) as? LayerCell)?.updateTarget()
                }
            }
            // A rename — double-click, the row's menu, or the Layer menu — is typed in the row itself.
            if let id = session.renamingLayerID, let row = next.firstIndex(where: { $0.id == id }) {
                table.scrollRowToVisible(row)
                DispatchQueue.main.async {
                    (table.view(atColumn: 0, row: row, makeIfNecessary: true) as? LayerCell)?.beginRenaming()
                }
            }
        }

        func layer(for row: Int) -> ImageLayer? {
            guard rows.indices.contains(row) else { return nil }
            return rows[row]
        }

        /// `onThumbnail`: the right-click landed on the layer's or the mask's thumbnail, which, as in Photoshop, also
        /// offers to load what it holds as a selection, or to combine it with the selection.
        func contextMenu(for row: Int, onThumbnail: Bool = false) -> NSMenu? {
            guard rows.indices.contains(row) else { return nil }
            if session.selectedLayerIDs.isEmpty {
                session.selectLayer(rows[row].id)
            }
            let menu = NSMenu()

            if onThumbnail {
                let noun = session.isMaskSelected ? "Mask" : "Pixels"
                for (title, action) in [("Select " + noun, #selector(selectTargetAction)),
                                        ("Add \(noun) to Selection", #selector(addTargetToSelectionAction)),
                                        ("Subtract \(noun) from Selection", #selector(subtractTargetFromSelectionAction)),
                                        ("Intersect \(noun) with Selection", #selector(intersectTargetWithSelectionAction))] {
                    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                    item.target = self
                    item.isEnabled = validateMenuItem(item)
                    menu.addItem(item)
                }
                menu.addItem(NSMenuItem.separator())
            }

            // 1. Duplicate Layer
            let duplicateItem = NSMenuItem(title: "Duplicate Layer", action: #selector(duplicateLayerAction), keyEquivalent: "")
            duplicateItem.target = self
            duplicateItem.isEnabled = validateMenuItem(duplicateItem)
            menu.addItem(duplicateItem)

            // 2. Rename…
            let renameItem = NSMenuItem(title: "Rename…", action: #selector(renameLayerAction), keyEquivalent: "")
            renameItem.target = self
            renameItem.isEnabled = validateMenuItem(renameItem)
            menu.addItem(renameItem)

            // 3. Delete Layer / Delete Selected Layers
            let deleteTitle: String
            if session.isMaskSelected && session.activeLayer?.mask != nil {
                deleteTitle = "Delete Mask"
            } else if session.selectedLayerIDs.count > 1 {
                deleteTitle = "Delete Selected Layers"
            } else {
                deleteTitle = "Delete Layer"
            }
            let deleteItem = NSMenuItem(title: deleteTitle, action: #selector(deleteLayerAction), keyEquivalent: "")
            deleteItem.target = self
            deleteItem.isEnabled = validateMenuItem(deleteItem)
            menu.addItem(deleteItem)

            menu.addItem(NSMenuItem.separator())

            // 4. Create Clipping Mask / Release Clipping Mask
            let clippingTitle = session.activeLayer?.maskSourceID != nil ? "Release Clipping Mask" : "Create Clipping Mask"
            let clippingItem = NSMenuItem(title: clippingTitle, action: #selector(toggleClippingMaskAction), keyEquivalent: "")
            clippingItem.target = self
            clippingItem.isEnabled = validateMenuItem(clippingItem)
            menu.addItem(clippingItem)

            // 5. Group Selected Layers
            let groupItem = NSMenuItem(title: "Group Selected Layers", action: #selector(groupSelectedLayersAction), keyEquivalent: "")
            groupItem.target = self
            groupItem.isEnabled = validateMenuItem(groupItem)
            menu.addItem(groupItem)

            // A group right-clicked can be ungrouped: its layers stay where they are, and the group goes.
            if rows[row].isGroup {
                let ungroupItem = NSMenuItem(title: "Ungroup Layers", action: #selector(ungroupLayersAction), keyEquivalent: "")
                ungroupItem.target = self
                ungroupItem.isEnabled = validateMenuItem(ungroupItem)
                menu.addItem(ungroupItem)
            }

            // 6. Move Out of Group
            let moveOutItem = NSMenuItem(title: "Move Out of Group", action: #selector(moveOutOfFolderAction), keyEquivalent: "")
            moveOutItem.target = self
            moveOutItem.isEnabled = validateMenuItem(moveOutItem)
            menu.addItem(moveOutItem)

            // 7. Merge Down / Merge Layers / Merge Group
            let mergeItem = NSMenuItem(title: session.mergeTitle, action: #selector(mergeLayersAction), keyEquivalent: "")
            mergeItem.target = self
            mergeItem.isEnabled = validateMenuItem(mergeItem)
            menu.addItem(mergeItem)
            for (title, action) in [("Merge Visible", #selector(mergeVisibleAction)), ("Flatten Image", #selector(flattenImageAction))] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                item.isEnabled = validateMenuItem(item)
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())

            // 8. Add Mask >
            let addMaskItem = NSMenuItem(title: "Add Mask", action: nil, keyEquivalent: "")
            let addMaskSubmenu = NSMenu(title: "Add Mask")
            let revealAllItem = NSMenuItem(title: "Reveal All (White)", action: #selector(addWhiteMaskAction), keyEquivalent: "")
            revealAllItem.target = self
            revealAllItem.isEnabled = validateMenuItem(revealAllItem)
            addMaskSubmenu.addItem(revealAllItem)
            let hideAllItem = NSMenuItem(title: "Hide All (Black)", action: #selector(addBlackMaskAction), keyEquivalent: "")
            hideAllItem.target = self
            hideAllItem.isEnabled = validateMenuItem(hideAllItem)
            addMaskSubmenu.addItem(hideAllItem)
            addMaskItem.submenu = addMaskSubmenu
            addMaskItem.isEnabled = session.canEditMask && session.activeLayer?.mask == nil
            menu.addItem(addMaskItem)

            // 9. Enable Mask / Disable Mask
            let toggleMaskTitle = session.activeLayer?.mask?.isEnabled == false ? "Enable Mask" : "Disable Mask"
            let toggleMaskItem = NSMenuItem(title: toggleMaskTitle, action: #selector(toggleMaskAction), keyEquivalent: "")
            toggleMaskItem.target = self
            toggleMaskItem.isEnabled = validateMenuItem(toggleMaskItem)
            menu.addItem(toggleMaskItem)

            let applyMaskItem = NSMenuItem(title: "Apply Layer Mask", action: #selector(applyLayerMaskAction), keyEquivalent: "")
            applyMaskItem.target = self
            applyMaskItem.isEnabled = validateMenuItem(applyMaskItem)
            menu.addItem(applyMaskItem)

            // 10. Delete Mask
            let deleteMaskItem = NSMenuItem(title: "Delete Mask", action: #selector(deleteMaskAction), keyEquivalent: "")
            deleteMaskItem.target = self
            deleteMaskItem.isEnabled = validateMenuItem(deleteMaskItem)
            menu.addItem(deleteMaskItem)

            // 11. Link Mask / Unlink Mask
            let linkMaskTitle = session.activeLayer?.mask?.isLinked == false ? "Link Mask" : "Unlink Mask"
            let linkMaskItem = NSMenuItem(title: linkMaskTitle, action: #selector(toggleMaskLinkAction), keyEquivalent: "")
            linkMaskItem.target = self
            linkMaskItem.isEnabled = validateMenuItem(linkMaskItem)
            menu.addItem(linkMaskItem)

            menu.addItem(NSMenuItem.separator())

            for (title, action) in [("Copy Layer Style", #selector(copyLayerStyleAction)),
                                    ("Paste Layer Style", #selector(pasteLayerStyleAction)),
                                    ("Clear Layer Style", #selector(clearLayerStyleAction))] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                item.isEnabled = validateMenuItem(item)
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())

            // 12. Hide Layer / Show Layer
            let visibilityTitle = session.activeLayer?.isVisible == false ? "Show Layer" : "Hide Layer"
            let visibilityItem = NSMenuItem(title: visibilityTitle, action: #selector(toggleVisibilityAction), keyEquivalent: "")
            visibilityItem.target = self
            visibilityItem.isEnabled = validateMenuItem(visibilityItem)
            menu.addItem(visibilityItem)

            let hidesOthers = session.activeLayerID.map { session.hasOtherVisibleLayers(than: $0) } ?? true
            let othersItem = NSMenuItem(title: hidesOthers ? "Hide All Other Layers" : "Show All Other Layers",
                                        action: #selector(toggleOtherLayersVisibilityAction), keyEquivalent: "")
            othersItem.target = self
            othersItem.isEnabled = validateMenuItem(othersItem)
            menu.addItem(othersItem)

            return menu
        }

        func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            switch menuItem.action {
            case #selector(duplicateLayerAction):
                return session.canEditLayers && session.activeLayer != nil
            case #selector(renameLayerAction):
                return session.canEditLayers && session.activeLayer != nil && session.selectedLayerIDs.count == 1
            case #selector(deleteLayerAction):
                return session.canEditLayers && session.activeLayer != nil
            case #selector(toggleClippingMaskAction):
                return session.activeLayerID.map { session.canToggleClippingMask($0) } ?? false
            case #selector(groupSelectedLayersAction):
                return session.canEditLayers && session.document != nil && (session.document?.layers.count ?? 0) < 10_000 && !session.selectedLayerIDs.isEmpty
            case #selector(ungroupLayersAction):
                return session.canUngroupLayers
            case #selector(moveOutOfFolderAction):
                return session.canEditLayers && session.activeLayer?.parentID != nil
            case #selector(mergeLayersAction):
                return session.canMergeLayers
            case #selector(addWhiteMaskAction), #selector(addBlackMaskAction):
                return session.canEditMask && session.activeLayer?.mask == nil
            case #selector(toggleMaskAction):
                return session.canEditMask && session.activeLayer?.mask != nil
            case #selector(deleteMaskAction):
                return session.canEditMask && session.activeLayer?.mask != nil
            case #selector(toggleMaskLinkAction):
                return session.canEditLayers && session.activeLayer?.mask != nil && session.activeLayer?.isGroup == false && session.activeLayer?.adjustment == nil
            case #selector(toggleVisibilityAction):
                return session.canEditLayers && session.activeLayer != nil
            case #selector(mergeVisibleAction):
                return session.canMergeVisible
            case #selector(flattenImageAction):
                return session.canFlattenImage
            case #selector(applyLayerMaskAction):
                return session.canApplyLayerMask
            case #selector(copyLayerStyleAction):
                return session.canCopyLayerStyle
            case #selector(pasteLayerStyleAction):
                return session.canPasteLayerStyle
            case #selector(clearLayerStyleAction):
                return session.canClearLayerStyle
            case #selector(toggleOtherLayersVisibilityAction):
                return session.canToggleOtherLayers && session.activeLayer != nil
            case #selector(selectTargetAction):
                return session.canEditSelection && hasSelectableTarget
            case #selector(addTargetToSelectionAction), #selector(subtractTargetFromSelectionAction),
                 #selector(intersectTargetWithSelectionAction):
                return session.canEditSelection && hasSelectableTarget && session.selection != nil
            default:
                if menuItem.submenu != nil && menuItem.title == "Add Mask" {
                    return session.canEditMask && session.activeLayer?.mask == nil
                }
                return true
            }
        }

        @objc func duplicateLayerAction(_ sender: Any?) {
            session.duplicateActiveLayer()
        }

        @objc func renameLayerAction(_ sender: Any?) {
            guard session.canEditLayers, let id = session.activeLayerID else { return }
            session.renamingLayerID = id
        }

        @objc func deleteLayerAction(_ sender: Any?) {
            session.deleteLayerOrMask()
        }

        @objc func toggleClippingMaskAction(_ sender: Any?) {
            if let id = session.activeLayerID { session.toggleClippingMask(id) }
        }

        @objc func groupSelectedLayersAction(_ sender: Any?) {
            session.groupSelectedLayers()
        }

        @objc func ungroupLayersAction(_ sender: Any?) {
            session.ungroupLayers()
        }

        @objc func moveOutOfFolderAction(_ sender: Any?) {
            session.moveActiveLayerOutOfGroup()
        }

        @objc func mergeLayersAction(_ sender: Any?) {
            session.mergeLayers()
        }

        @objc func addWhiteMaskAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.selectLayerTarget(id, mask: false)
            session.addMask(revealing: true)
        }

        @objc func addBlackMaskAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.selectLayerTarget(id, mask: false)
            session.addMask(revealing: false)
        }

        @objc func toggleMaskAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.selectLayerTarget(id, mask: false)
            session.toggleLayerMask()
        }

        @objc func deleteMaskAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.selectLayerTarget(id, mask: false)
            session.deleteLayerMask()
        }

        @objc func toggleMaskLinkAction(_ sender: Any?) {
            if let id = session.activeLayerID { session.toggleMaskLink(id) }
        }

        @objc func toggleVisibilityAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.toggleLayerVisibility(id)
        }

        @objc func toggleOtherLayersVisibilityAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            session.toggleOtherLayersVisibility(id)
        }

        @objc func mergeVisibleAction(_ sender: Any?) { session.mergeVisible() }
        @objc func flattenImageAction(_ sender: Any?) { session.flattenImage() }
        @objc func applyLayerMaskAction(_ sender: Any?) { session.applyLayerMask() }
        @objc func copyLayerStyleAction(_ sender: Any?) { session.copyLayerStyle() }
        @objc func pasteLayerStyleAction(_ sender: Any?) { session.pasteLayerStyle() }
        @objc func clearLayerStyleAction(_ sender: Any?) { session.clearLayerStyle() }

        /// The thumbnail right-clicked holds something to select: the mask, or the layer's own pixels.
        private var hasSelectableTarget: Bool {
            guard let layer = session.activeLayer else { return false }
            return session.isMaskSelected ? layer.mask != nil : layer.asset != nil && !layer.isGroup
        }
        private func loadTargetSelection(_ mode: SelectionMode) {
            guard let id = session.activeLayerID else { return }
            if session.isMaskSelected { session.loadMaskSelection(layerID: id, mode: mode) }
            else { session.loadLayerSelection(layerID: id, mode: mode) }
        }
        @objc func selectTargetAction(_ sender: Any?) { loadTargetSelection(.replace) }
        @objc func addTargetToSelectionAction(_ sender: Any?) { loadTargetSelection(.add) }
        @objc func subtractTargetFromSelectionAction(_ sender: Any?) { loadTargetSelection(.subtract) }
        @objc func intersectTargetWithSelectionAction(_ sender: Any?) {
            guard let id = session.activeLayerID else { return }
            if session.isMaskSelected { session.intersectMaskSelection(layerID: id) }
            else { session.intersectLayerSelection(layerID: id) }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
        /// A one-line row, then, unless the fx badge folded them, an "Effects" row and a row per effect.
        static func height(of layer: ImageLayer, collapsedEffects: Set<UUID>) -> CGFloat {
            let effects = layer.effects?.kinds.count ?? 0
            guard effects > 0, !collapsedEffects.contains(layer.id) else { return LayerCell.lineHeight }
            return LayerCell.lineHeight + CGFloat(effects + 1) * LayerCell.effectRowHeight
        }
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            Self.height(of: rows[row], collapsedEffects: collapsedEffects)
        }
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            tableView.makeView(withIdentifier: LayerRowView.identifier, owner: self) as? LayerRowView ?? LayerRowView()
        }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("layerCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? LayerCell ?? LayerCell()
            cell.identifier = identifier
            cell.configure(rows[row], enabled: editingEnabled, session: session, depth: rowDetails[rows[row].id]?.depth ?? 0,
                           visible: rowDetails[rows[row].id]?.visible ?? true, showsEffects: !collapsedEffects.contains(rows[row].id))
            return cell
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !synchronizing, let table = notification.object as? NSTableView else { return }
            let selected = table.selectedRowIndexes.filter { rows.indices.contains($0) }
            let ids = Set(selected.map { rows[$0].id })
            let primary = selected.contains(table.clickedRow) ? rows[table.clickedRow].id : selected.first.map { rows[$0].id }
            session.selectLayers(ids, primary: primary)
        }
        /// A click on a row's name (its thumbnails are buttons of their own) targets the layer itself, even when its
        /// mask was selected — so transforming then moves layer and mask together.
        @objc func clickedLayer(_ table: NSTableView) {
            guard rows.indices.contains(table.clickedRow), session.isMaskSelected,
                  session.selectedLayerIDs == [rows[table.clickedRow].id],
                  // Clicks on the row's buttons (the mask thumbnail among them) reach the table too.
                  let event = NSApp.currentEvent,
                  (table.view(atColumn: 0, row: table.clickedRow, makeIfNecessary: false) as? LayerCell)?.isOnControl(event.locationInWindow) != true
            else { return }
            session.commitTransform()
            session.selectLayerTarget(rows[table.clickedRow].id, mask: false)
        }
        @objc func renameClickedLayer(_ table: NSTableView) {
            guard session.canEditLayers, rows.indices.contains(table.clickedRow) else { return }
            let id = rows[table.clickedRow].id
            session.activeLayerID = id
            // On the thumbnail (or another of the row's controls) a double-click opens what the layer holds: its
            // text, or an adjustment's settings in Properties. On the name it renames the layer, as it does for every
            // other layer.
            let point = NSApp.currentEvent?.locationInWindow ?? .zero
            let cell = table.view(atColumn: 0, row: table.clickedRow, makeIfNecessary: false) as? LayerCell
            // On the "Effects" row it opens the Layer Style dialog.
            if cell?.isOnEffectsHeader(point) == true {
                session.selectLayerTarget(id, mask: false)
                session.openLayerStyle(.blendingOptions)
                return
            }
            if cell?.isOnControl(point) == true {
                if rows[table.clickedRow].liveText != nil { session.editActiveText(); return }
                if rows[table.clickedRow].adjustment != nil { session.showProperties(); return }
            }
            session.renamingLayerID = id
        }
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard session.canEditLayers, rows.indices.contains(row) else { return nil }
            let item = NSPasteboardItem()
            item.setString(rows[row].id.uuidString, forType: Self.layerType)
            return item
        }
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                       proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
            if let source = info.draggingSource as? LayerEffectRow {
                let target = tableView.row(at: tableView.convert(info.draggingLocation, from: nil))
                guard source.session === session, rows.indices.contains(target),
                      session.canCopyEffect(source.kind, from: source.layerID, to: rows[target].id) else { return [] }
                tableView.setDropRow(target, dropOperation: .on)
                return .copy
            }
            if let source = draggedMask(info) {
                // A mask lands on whichever row is under the pointer.
                let target = tableView.row(at: tableView.convert(info.draggingLocation, from: nil))
                guard rows.indices.contains(target), session.canCopyMask(from: source, to: rows[target].id) else { return [] }
                tableView.setDropRow(target, dropOperation: .on)
                return .copy
            }
            guard session.canEditLayers, info.draggingSource as? NSTableView === tableView,
                  (0...rows.count).contains(row) else { return [] }
            let ids = draggedLayers(info)
            guard !ids.isEmpty else { return [] }
            // With Option held the drag offers only Copy, including complete folder trees.
            let copying = info.draggingSourceOperationMask == .copy
            let intoFolder = operation == .on && rows.indices.contains(row) && rows[row].isGroup
            let parent = intoFolder ? rows[row].id : (rows.indices.contains(row) ? rows[row].parentID : nil)
            guard ids.allSatisfy({ session.canPlaceLayer($0, in: parent) }) else { return [] }
            tableView.setDropRow(row, dropOperation: intoFolder ? .on : .above)
            return copying ? .copy : .move
        }
        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                       row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            if let source = info.draggingSource as? LayerEffectRow {
                guard source.session === session, rows.indices.contains(row),
                      session.canCopyEffect(source.kind, from: source.layerID, to: rows[row].id) else { return false }
                session.copyEffect(source.kind, from: source.layerID, to: rows[row].id)
                return true
            }
            if let source = draggedMask(info) {
                guard rows.indices.contains(row), session.canCopyMask(from: source, to: rows[row].id) else { return false }
                session.copyMask(from: source, to: rows[row].id)
                return true
            }
            guard info.draggingSource as? NSTableView === tableView else { return false }
            let ids = draggedLayers(info)
            guard !ids.isEmpty else { return false }
            let copying = info.draggingSourceOperationMask == .copy
            let intoFolder = dropOperation == .on && rows.indices.contains(row) && rows[row].isGroup
            return place(ids, at: row, intoFolder: intoFolder, copying: copying)
        }
        /// Reorders one layer to the row a drop above it would use: the list's own move, without the dragging
        /// plumbing, so anything that picks a row by itself — a test, a keyboard command — can reach it.
        @discardableResult func moveLayer(_ id: UUID, to row: Int) -> Bool {
            // `session.placeLayer` already refuses an unknown layer and a session that cannot edit layers, so the
            // only thing left to reject is a row that is not a drop target. `place` treats a row past the end as
            // the bottom, so what this actually catches is a negative one; the bound is written the way
            // `validateDrop` writes it, so the two accept the same rows.
            guard (0...rows.count).contains(row) else { return false }
            return place([id], at: row, intoFolder: false, copying: false)
        }
        private func place(_ ids: [UUID], at row: Int, intoFolder: Bool, copying: Bool) -> Bool {
            // Where the drop lands is worked out once: each layer placed shifts the rows beneath it.
            let current = session.layerRows
            let parent: UUID?, above: UUID?, atBottom: Bool
            if intoFolder {
                parent = rows[row].id; above = nil; atBottom = false
            } else if row >= current.count {
                parent = nil; above = nil; atBottom = true
            } else {
                let target = current[row].layer
                parent = target.parentID; above = target.id; atBottom = false
            }
            // Dropped above a layer (or at the very bottom) the last one placed ends up nearest it, so they go in
            // from the top down; dropped into a folder each lands on top, so they go in from the bottom up.
            let order = intoFolder ? Array(ids.reversed()) : ids
            session.beginEdit(copying ? (ids.count > 1 ? "Duplicate Layers" : "Duplicate Layer")
                                      : (ids.count > 1 ? "Move Layers" : "Move Layer"))
            var placed = false
            for id in order {
                let done = copying ? session.duplicateLayer(id, in: parent, above: above, atBottom: atBottom)
                                   : session.placeLayer(id, in: parent, above: above, atBottom: atBottom)
                placed = done || placed
            }
            // The layers that moved stay selected, so they can be dragged on as a group.
            if placed, !copying { session.selectLayers(Set(ids), primary: ids.first) }
            session.endEdit()
            return placed
        }
        private func draggedMask(_ info: NSDraggingInfo) -> UUID? {
            info.draggingPasteboard.string(forType: Self.maskType).flatMap(UUID.init(uuidString:))
        }
        /// Every layer being dragged, in the order the list shows them: a row's pasteboard item each, leaving out
        /// anything inside a dragged folder, which the folder brings along itself.
        private func draggedLayers(_ info: NSDraggingInfo) -> [UUID] {
            let dropped = (info.draggingPasteboard.pasteboardItems ?? []).compactMap {
                $0.string(forType: Self.layerType).flatMap(UUID.init(uuidString:))
            }
            let dragged = Set(dropped)
            let carried = dragged.reduce(into: Set<UUID>()) { $0.formUnion(session.descendantIDs(of: $1)) }
            return session.layerRows.map(\.layer.id).filter { dragged.contains($0) && !carried.contains($0) }
        }
    }
}

final class LayerTableView: NSTableView {
    weak var session: EditorSession?
    private var clippingTracking: NSTrackingArea?
    private var clippingMonitor: Any?
    private var clippingCursorActive = false

    /// Cmd-A selects the whole canvas, as Select > All does, even with the Layers panel just clicked — never every layer.
    /// A layer's name being edited keeps its own Select All: its field editor answers first.
    override func selectAll(_ sender: Any?) {
        guard let session = session ?? (delegate as? NativeLayerList.Coordinator)?.session, session.document != nil else { return }
        session.selectAll()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0, row < numberOfRows else { return nil }
        guard let coordinator = delegate as? NativeLayerList.Coordinator else { return nil }
        guard let targetLayer = coordinator.layer(for: row) else { return nil }
        let currentSession = session ?? coordinator.session

        let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? LayerCell
        let isEffect = cell?.selectEffect(at: event.locationInWindow, editing: false) == true
        var onThumbnail = false
        if !isEffect {
            currentSession.effectSelection = nil
            let thumb = thumbnail(at: point)
            let isMaskThumb = thumb?.isMaskTarget == true
            let isLayerThumb = thumb?.loadsSelection == true
            onThumbnail = isMaskThumb || isLayerThumb

            if selectedRowIndexes.contains(row) {
                if isMaskThumb {
                    currentSession.selectLayerTarget(targetLayer.id, mask: true)
                } else if isLayerThumb {
                    currentSession.selectLayerTarget(targetLayer.id, mask: false)
                } else {
                    currentSession.selectLayers(currentSession.selectedLayerIDs, primary: targetLayer.id)
                }
            } else {
                selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                window?.makeFirstResponder(self)
                if isMaskThumb {
                    currentSession.selectLayerTarget(targetLayer.id, mask: true)
                } else {
                    currentSession.selectLayerTarget(targetLayer.id, mask: false)
                }
            }
        }

        return coordinator.contextMenu(for: row, onThumbnail: onThumbnail)
    }
    private static func clippingCursor(releasing: Bool) -> NSCursor {
        let image = NSImage(size: NSSize(width: 30, height: 28), flipped: false) { _ in
            let arrow = NSImage(systemSymbolName: "arrow.turn.down.right", accessibilityDescription: nil)!
            let box = NSImage(systemSymbolName: releasing ? "rectangle.badge.minus" : "rectangle.badge.plus", accessibilityDescription: nil)!
            func drawOutlined(_ symbol: NSImage, in rect: NSRect) {
                let white = symbol.withSymbolConfiguration(.init(paletteColors: [.white]))!
                let black = symbol.withSymbolConfiguration(.init(paletteColors: [.black]))!
                for step in 0..<16 {
                    let angle = CGFloat(step) * .pi / 8
                    white.draw(in: rect.offsetBy(dx: cos(angle), dy: sin(angle)))
                }
                black.draw(in: rect)
            }
            drawOutlined(arrow, in: NSRect(x: 1, y: 11, width: 16, height: 15))
            drawOutlined(box, in: NSRect(x: 10, y: 1, width: 19, height: 17))
            return true
        }
        image.accessibilityDescription = releasing ? "Release clipping mask" : "Create clipping mask"
        return NSCursor(image: image, hotSpot: NSPoint(x: 3, y: 3))
    }
    private static let createClippingCursor = clippingCursor(releasing: false)
    private static let releaseClippingCursor = clippingCursor(releasing: true)
    /// Option over a mask thumbnail: the duplicate pointer with a small eye at its lower right — an Option-click shows
    /// the mask alone on the canvas, and an Option-drag still copies it onto another layer.
    private static let showMaskCursor: NSCursor = {
        let base = CanvasView.duplicateCursor
        let eye = NSRect(x: base.hotSpot.x + 15, y: base.hotSpot.y + 18, width: 7.5, height: 5.5)
        let size = NSSize(width: max(base.image.size.width, eye.maxX + 2), height: max(base.image.size.height, eye.maxY + 2))
        let image = NSImage(size: size, flipped: true) { _ in
            // The eye first, so the arrows sit in front of it.
            let symbol = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)!
            let white = symbol.withSymbolConfiguration(.init(paletteColors: [.white]))!
            let black = symbol.withSymbolConfiguration(.init(paletteColors: [.black]))!
            for step in 0..<16 {
                let angle = CGFloat(step) * .pi / 8
                white.draw(in: eye.offsetBy(dx: cos(angle), dy: sin(angle)))
            }
            black.draw(in: eye)
            base.image.draw(in: NSRect(origin: .zero, size: base.image.size), from: .zero, operation: .sourceOver,
                            fraction: 1, respectFlipped: true, hints: nil)
            return true
        }
        image.accessibilityDescription = "Show mask alone"
        return NSCursor(image: image, hotSpot: base.hotSpot)
    }()
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let clippingTracking { removeTrackingArea(clippingTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate], owner: self)
        addTrackingArea(area); clippingTracking = area
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let clippingMonitor { NSEvent.removeMonitor(clippingMonitor); self.clippingMonitor = nil }
        if window != nil {
            clippingMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                guard let self else { return event }
                self.refreshClippingCursor(event.modifierFlags)
                // A modifier change is not a mouse event: AppKit restores its own cursor once this one is handled,
                // so the cursor is worked out again right after, from wherever the pointer is by then.
                DispatchQueue.main.async { [weak self] in self?.refreshClippingCursor(NSEvent.modifierFlags) }
                return event
            }
        }
    }
    /// Keeps the cursor right over the layer list: with Option held, the clipping cursor over the bottom quarter
    /// of a row, as in Photoshop, and the duplicate cursor over the rest of it (a mask thumbnail shows the mask alone); a thumbnail's own cursor with Command held over
    /// it; otherwise the arrow — even when a
    /// tool's cursor followed the mouse in. `location` is in window coordinates; without one
    /// (a modifier change) the current mouse position is used.
    func refreshClippingCursor(_ flags: NSEvent.ModifierFlags, at location: NSPoint? = nil) {
        guard let window else { return }
        let point = convert(location ?? window.mouseLocationOutsideOfEventStream, from: nil)
        let inside = visibleRect.contains(point)
        guard inside, flags.contains(.option), !flags.contains(.command) else {
            // Outside the list, a modifier change must not touch another view's cursor.
            if clippingCursorActive || (inside && !thumbnailOwnsCursor(at: point, flags: flags)) { NSCursor.arrow.set() }
            clippingCursorActive = false
            return
        }
        clippingCursorActive = true
        (clippingCursor(at: point) ?? .arrow).set()
    }

    /// With Option held, the cursor for whatever is under `point`: the clipping cursor over the bottom of a row,
    /// the duplicate cursor over the rest of it, and over a mask thumbnail the one for showing the mask alone.
    private func clippingCursor(at point: NSPoint) -> NSCursor? {
        let index = row(at: point)
        guard let session, session.layerRows.indices.contains(index) else { return nil }
        let layer = session.layerRows[index].layer
        // Option-click on a mask shows it alone (Option-dragging it onto another layer still copies it).
        if let thumbnail = thumbnail(at: point), thumbnail.isMaskTarget, !thumbnail.isHidden {
            return Self.showMaskCursor
        }
        guard isClippingZone(point, row: index) else {
            return session.canEditLayers ? CanvasView.duplicateCursor : NSCursor.arrow
        }
        guard session.canToggleClippingMask(layer.id) else { return NSCursor.arrow }
        return layer.maskSourceID == nil ? Self.createClippingCursor : Self.releaseClippingCursor
    }

    /// Option-click clips along the bottom edge of a row: a fixed strip, not a share of the row's height, so a row
    /// listing several effects keeps the rest of itself free for Option-dragging those effects.
    private static let clippingStrip: CGFloat = 8
    private func isClippingZone(_ point: NSPoint, row: Int) -> Bool {
        guard row >= 0 else { return false }
        if let entries = session?.layerRows, entries.indices.contains(row), entries[row].layer.isGroup == true { return false }
        let rect = rect(ofRow: row)
        return point.y >= rect.maxY - min(Self.clippingStrip, rect.height / 3)
    }
    /// Command held over a thumbnail that loads a selection: that thumbnail shows its cursor.
    private func thumbnailOwnsCursor(at point: NSPoint, flags: NSEvent.ModifierFlags) -> Bool {
        guard flags.contains(.command), let thumbnail = thumbnail(at: point) else { return false }
        return thumbnail.cmdClickLoads && thumbnail.isEnabled
    }
    /// The layer or mask thumbnail under a point in this view's coordinates, if any.
    private func thumbnail(at point: NSPoint) -> LayerThumbnailButton? {
        guard let superview else { return nil }
        var view = superview.hitTest(convert(point, to: superview))
        while let current = view, current !== self {
            if let thumbnail = current as? LayerThumbnailButton { return thumbnail }
            view = current.superview
        }
        return nil
    }
    override func mouseEntered(with event: NSEvent) { refreshClippingCursor(event.modifierFlags, at: event.locationInWindow) }
    override func mouseMoved(with event: NSEvent) { refreshClippingCursor(event.modifierFlags, at: event.locationInWindow) }
    override func cursorUpdate(with event: NSEvent) { refreshClippingCursor(event.modifierFlags, at: event.locationInWindow) }
    override func mouseExited(with event: NSEvent) {
        // Reloading rows (after a brush stroke, say) rebuilds the tracking areas, which sends an exit even though
        // the pointer never left: taking the cursor back then makes it flicker. Only a real exit resets it.
        if let window, visibleRect.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)) {
            refreshClippingCursor(NSEvent.modifierFlags)
            return
        }
        if clippingCursorActive { NSCursor.arrow.set(); clippingCursorActive = false }
    }

    /// Effect rows are interactive subviews. In the clipping zone, Option-click belongs to the table
    /// instead, so the same region that advertises the clipping cursor also handles the click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard hit != nil else { return nil }
        let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
        let local = convert(point, from: superview)
        guard flags.contains(.option), !flags.contains(.command),
              isClippingZone(local, row: row(at: local)) else { return hit }
        // Option-dragging a mask thumbnail must still copy its mask.
        var target = hit
        while let view = target, view !== self {
            if let thumbnail = view as? LayerThumbnailButton, thumbnail.isMaskTarget { return hit }
            target = view.superview
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        // Handle clipping before effect selection: effects occupy the lower portion of taller rows.
        if event.modifierFlags.contains(.option), !event.modifierFlags.contains(.command), isClippingZone(point, row: row),
           thumbnail(at: point)?.isMaskTarget != true,
           let entries = session?.layerRows, entries.indices.contains(row) {
            session?.effectSelection = nil
            session?.toggleClippingMask(entries[row].layer.id)
            refreshClippingCursor(event.modifierFlags)
            return
        }
        if row >= 0, let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? LayerCell,
           cell.selectEffect(at: event.locationInWindow, editing: event.clickCount > 1) {
            window?.makeFirstResponder(self)
            return
        }
        session?.effectSelection = nil
        if row >= 0, event.modifierFlags.intersection([.command, .shift]).isEmpty,
           !(selectedRowIndexes.count > 1 && selectedRowIndexes.contains(row)) {
            // Paint selection before AppKit enters its click/drag tracking loop.
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            window?.makeFirstResponder(self)
            displayIfNeeded()
        }
        super.mouseDown(with: event)
    }
    override func keyDown(with event: NSEvent) {
        guard let event = ShortcutSettings.shared.canvasEvent(event) else { return }
        let plain = event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        if event.keyCode == 53, session?.transformEdit != nil {
            session?.cancelTransform()
        } else if [36, 76].contains(event.keyCode), session?.transformEdit != nil {
            session?.commitTransform()
        } else if plain, event.charactersIgnoringModifiers?.lowercased() == "x" {
            session?.swapPaletteColors()
        } else if plain, event.charactersIgnoringModifiers?.lowercased() == "d" {
            session?.resetPaletteColors()
        } else if plain, let key = event.charactersIgnoringModifiers?.lowercased(), EditorSession.isToolKey(key) {
            // As on the canvas: the slot's last tool, Shift for its next one, a held key only once.
            if !event.isARepeat { session?.pressToolKey(key, shift: event.modifierFlags.contains(.shift)) }
        } else if plain, let digit = Int(event.charactersIgnoringModifiers ?? ""), session?.usesOpacityKeys == true {
            session?.typeOpacityDigit(digit)
        // With the Move tool the arrows move the layer, as on the canvas, rather than changing the row selection.
        } else if plain, session?.transformEdit != nil || session?.tool == .move, [123, 124, 125, 126].contains(event.keyCode) {
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            session?.nudgeLayer(dx: event.keyCode == 123 ? -step : event.keyCode == 124 ? step : 0,
                                dy: event.keyCode == 126 ? -step : event.keyCode == 125 ? step : 0)
        } else if [51, 117].contains(event.keyCode), plain {
            session?.deleteKeyPressed()
        } else if [53, 36, 76].contains(event.keyCode), plain {
            // Escape or Return with nothing to cancel or apply: the table would only beep at it.
        } else { super.keyDown(with: event) }
    }
}

/// A layer's row while it is selected: `selection` behind its one-line top only (an effect row marks its own
/// selection), with the row's text left in its usual colors.
private final class LayerRowView: NSTableRowView {
    static let identifier = NSUserInterfaceItemIdentifier("layerRow")
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isEmphasized: Bool { get { false } set {} }
    override func drawSelection(in dirtyRect: NSRect) {
        ColorRole.selection.nsColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: min(bounds.height, LayerCell.lineHeight)).fill()
    }
}

/// One layer: a one-line row (eye, then, stepped in by its group depth, a group's triangle and folder or the layer's
/// thumbnail, the link and mask thumbnail, the name and an fx badge) and, under a styled layer, its effect rows.
private final class LayerCell: NSTableCellView, NSTextFieldDelegate {
    /// The one-line row, and each row under a styled layer: "Effects", then one per effect.
    static let lineHeight: CGFloat = 32
    static let effectRowHeight: CGFloat = 22
    /// The column of eyes at the left, and how far each group level (and a clipping mask) steps a row in.
    static let eyeColumn: CGFloat = 26
    static let indentStep: CGFloat = 14
    /// Thumbnails fit a 24 pt square. Their buttons are 3 pt larger all round, where the target outline goes.
    static let thumbnailBox: CGFloat = 24
    static let thumbnailInset: CGFloat = 3
    /// Where a row's content starts, right of the eye column, before its indent.
    static let contentStart = eyeColumn + 6
    /// Where the name starts in a layer's row (not a group's, whose triangle comes first), before its indent: the
    /// "Effects" row's label lines up with it.
    static let nameStart = contentStart + thumbnailBox + 2 * thumbnailInset + 4

    /// The layer's own name, without the mark a clipped layer's row shows in front of it.
    private var layerName = ""
    private var renaming = false
    private let eye = EyeSwipeButton()
    private let effectRows = NSStackView()
    private var effectsHeader: LayerEffectsHeader?
    private var effectButtons: [LayerEffectRow] = []
    private let disclosure = NSButton()
    private var indentation: NSLayoutConstraint!
    private var disclosureWidth: NSLayoutConstraint!
    private let thumbnail = LayerThumbnailButton()
    private let maskThumbnail = LayerThumbnailButton()
    private let disabledMaskMark = MaskDisabledMark(labelWithString: "╱")
    /// Between the thumbnails: the chain while layer and mask are linked, empty (still clickable) once unlinked.
    private let linkButton = NSButton()
    private var maskGap: NSLayoutConstraint!
    /// The chain symbol runs corner to corner; turned 45° counterclockwise it stands upright in a narrow gap.
    private static let linkImage: NSImage? = {
        guard let symbol = NSImage(systemSymbolName: "link", accessibilityDescription: "Linked")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)) else { return nil }
        let side = max(symbol.size.width, symbol.size.height)
        let image = NSImage(size: NSSize(width: ceil(side * 0.7), height: ceil(side * 1.45)), flipped: false) { rect in
            let turn = NSAffineTransform()
            turn.translateX(by: rect.midX, yBy: rect.midY)
            turn.rotate(byDegrees: 45)
            turn.concat()
            symbol.draw(in: NSRect(x: -symbol.size.width / 2, y: -symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height))
            return true
        }
        image.isTemplate = true
        return image
    }()
    private var maskWidth: NSLayoutConstraint!
    /// Fixed slots keep names aligned while the thumbnails inside take the canvas's shape.
    private let thumbnailSlot = NSLayoutGuide()
    private let maskSlot = NSLayoutGuide()
    private var thumbnailWidth: NSLayoutConstraint!
    private var thumbnailHeight: NSLayoutConstraint!
    private var maskThumbnailWidth: NSLayoutConstraint!
    private var maskThumbnailHeight: NSLayoutConstraint!
    private let nameLabel = NSTextField(labelWithString: "")
    /// "fx" and a triangle that folds the effect rows away, on styled layers.
    private let effectsBadge = NSButton()
    private var nameToBadge: NSLayoutConstraint!
    private var nameToEdge: NSLayoutConstraint!
    /// Photoshop's padlock at the row's right: solid when the layer is locked all, hollow when partly locked, and
    /// faint on a layer locked only by a group around it.
    private let lockMark = NSImageView()
    private var nameToLock: NSLayoutConstraint!
    private var badgeToEdge: NSLayoutConstraint!
    private var badgeToLock: NSLayoutConstraint!
    /// Whether the layer's thumbnail shows the target outline: pictures, and anything with a mask to tell apart.
    private var outlinesThumbnail = true
    private var layerID: UUID?
    private weak var session: EditorSession?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        effectRows.orientation = .vertical
        effectRows.alignment = .leading
        effectRows.spacing = 0
        effectRows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectRows)
        NSLayoutConstraint.activate([
            effectRows.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectRows.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectRows.topAnchor.constraint(equalTo: topAnchor, constant: Self.lineHeight)
        ])
        disclosure.isBordered = false
        disclosure.imagePosition = .imageOnly
        disclosure.contentTintColor = ColorRole.icon.nsColor
        disclosure.target = self
        disclosure.action = #selector(toggleExpansion)
        eye.isBordered = false
        eye.imagePosition = .imageOnly
        eye.contentTintColor = ColorRole.icon.nsColor
        eye.target = self
        eye.action = #selector(toggleVisibility)
        for button in [thumbnail, maskThumbnail] {
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.target = self
        }
        thumbnail.action = #selector(selectImage)
        maskThumbnail.action = #selector(selectMask)
        maskThumbnail.isMaskTarget = true
        maskThumbnail.framed = true
        thumbnail.loadsSelection = true
        linkButton.isBordered = false
        linkButton.title = ""
        linkButton.imagePosition = .imageOnly
        linkButton.contentTintColor = ColorRole.secondaryText.nsColor
        linkButton.target = self
        linkButton.action = #selector(toggleMaskLink)
        disabledMaskMark.font = .systemFont(ofSize: 24, weight: .medium)
        disabledMaskMark.textColor = .systemRed
        disabledMaskMark.isHidden = true
        nameLabel.lineBreakMode = .byTruncatingTail
        // One line, whatever the name holds: a text layer named after a paragraph would otherwise grow the row.
        nameLabel.usesSingleLineMode = true
        nameLabel.maximumNumberOfLines = 1
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        effectsBadge.isBordered = false
        effectsBadge.imagePosition = .imageTrailing
        effectsBadge.contentTintColor = ColorRole.icon.nsColor
        effectsBadge.attributedTitle = NSAttributedString(string: "fx", attributes: [
            .font: NSFont(descriptor: NSFont.systemFont(ofSize: 12, weight: .semibold).fontDescriptor
                .withDesign(.serif)?.withSymbolicTraits(.italic) ?? NSFont.systemFont(ofSize: 12).fontDescriptor, size: 12)
                ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: ColorRole.icon.nsColor,
        ])
        // As wide as "fx" and its triangle, never stretched by a short name.
        effectsBadge.setContentHuggingPriority(.required, for: .horizontal)
        effectsBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        effectsBadge.target = self
        effectsBadge.action = #selector(toggleEffects)
        effectsBadge.toolTip = "Show or hide the layer's effects"
        for view in [eye, disclosure, thumbnail, linkButton, maskThumbnail, disabledMaskMark, nameLabel, effectsBadge, lockMark] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // A faint hairline along the bottom of each row marks where one layer ends and the next begins, and another
        // runs down the right of the eye column.
        let edge = RowEdgeLine()
        let column = RowEdgeLine(vertical: true)
        for line in [edge, column] {
            line.translatesAutoresizingMaskIntoConstraints = false
            addSubview(line)
        }
        NSLayoutConstraint.activate([
            edge.leadingAnchor.constraint(equalTo: leadingAnchor), edge.trailingAnchor.constraint(equalTo: trailingAnchor),
            edge.bottomAnchor.constraint(equalTo: bottomAnchor), edge.heightAnchor.constraint(equalToConstant: 1),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.eyeColumn),
            column.widthAnchor.constraint(equalToConstant: 1),
            column.topAnchor.constraint(equalTo: topAnchor), column.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let middle = Self.lineHeight / 2
        let thumbnailSide = Self.thumbnailBox + 2 * Self.thumbnailInset
        indentation = disclosure.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentStart)
        disclosureWidth = disclosure.widthAnchor.constraint(equalToConstant: 0)
        addLayoutGuide(thumbnailSlot)
        addLayoutGuide(maskSlot)
        maskWidth = maskSlot.widthAnchor.constraint(equalToConstant: 0)
        maskGap = maskSlot.leadingAnchor.constraint(equalTo: thumbnailSlot.trailingAnchor, constant: 0)
        thumbnailWidth = thumbnail.widthAnchor.constraint(equalToConstant: thumbnailSide)
        thumbnailHeight = thumbnail.heightAnchor.constraint(equalToConstant: thumbnailSide)
        maskThumbnailWidth = maskThumbnail.widthAnchor.constraint(equalToConstant: thumbnailSide)
        maskThumbnailHeight = maskThumbnail.heightAnchor.constraint(equalToConstant: thumbnailSide)
        nameToBadge = nameLabel.trailingAnchor.constraint(equalTo: effectsBadge.leadingAnchor, constant: -4)
        nameToEdge = nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        nameToLock = nameLabel.trailingAnchor.constraint(equalTo: lockMark.leadingAnchor, constant: -4)
        badgeToEdge = effectsBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        badgeToLock = effectsBadge.trailingAnchor.constraint(equalTo: lockMark.leadingAnchor, constant: -3)
        lockMark.setContentHuggingPriority(.required, for: .horizontal)
        lockMark.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            eye.leadingAnchor.constraint(equalTo: leadingAnchor), eye.topAnchor.constraint(equalTo: topAnchor),
            eye.widthAnchor.constraint(equalToConstant: Self.eyeColumn), eye.heightAnchor.constraint(equalToConstant: Self.lineHeight),
            indentation, disclosureWidth,
            disclosure.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            disclosure.heightAnchor.constraint(equalToConstant: 20),
            thumbnailSlot.leadingAnchor.constraint(equalTo: disclosure.trailingAnchor),
            thumbnailSlot.widthAnchor.constraint(equalToConstant: thumbnailSide),
            thumbnailSlot.topAnchor.constraint(equalTo: topAnchor),
            thumbnailSlot.heightAnchor.constraint(equalToConstant: Self.lineHeight),
            thumbnail.centerXAnchor.constraint(equalTo: thumbnailSlot.centerXAnchor),
            thumbnail.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            thumbnailWidth, thumbnailHeight,
            maskGap,
            linkButton.centerXAnchor.constraint(equalTo: maskSlot.leadingAnchor, constant: -5),
            linkButton.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            linkButton.widthAnchor.constraint(equalToConstant: 9), linkButton.heightAnchor.constraint(equalToConstant: 20),
            maskWidth,
            maskSlot.topAnchor.constraint(equalTo: topAnchor), maskSlot.heightAnchor.constraint(equalToConstant: Self.lineHeight),
            maskThumbnail.centerXAnchor.constraint(equalTo: maskSlot.centerXAnchor),
            maskThumbnail.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            maskThumbnailWidth, maskThumbnailHeight,
            disabledMaskMark.centerXAnchor.constraint(equalTo: maskThumbnail.centerXAnchor),
            disabledMaskMark.centerYAnchor.constraint(equalTo: maskThumbnail.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: maskSlot.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            effectsBadge.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            lockMark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            lockMark.centerYAnchor.constraint(equalTo: topAnchor, constant: middle),
            effectsBadge.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ layer: ImageLayer, enabled: Bool, session: EditorSession, depth: Int, visible: Bool, showsEffects: Bool) {
        self.session = session
        // A group steps its contents in by the same distance a clipping mask does; the two add up.
        let indent = CGFloat(min(depth, 8)) * Self.indentStep + (layer.maskSourceID == nil ? 0 : Self.indentStep)
        for row in effectRows.arrangedSubviews { effectRows.removeArrangedSubview(row); row.removeFromSuperview() }
        effectsHeader = nil
        effectButtons = []
        let kinds = LayerEffectKind.layerStyleOrder.filter { layer.effects?.contains($0) == true }
        if showsEffects, let effects = layer.effects, !kinds.isEmpty {
            let header = LayerEffectsHeader(session: session, layerID: layer.id, showing: kinds.contains { effects.isEnabled($0) },
                                            enabled: enabled, indent: indent)
            effectRows.addArrangedSubview(header)
            header.widthAnchor.constraint(equalTo: effectRows.widthAnchor).isActive = true
            effectsHeader = header
            effectButtons = kinds.map { kind in
                let row = LayerEffectRow(session: session, layerID: layer.id, kind: kind, enabled: effects.isEnabled(kind), indent: indent)
                effectRows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: effectRows.widthAnchor).isActive = true
                return row
            }
        }
        indentation.constant = Self.contentStart + indent
        disclosure.isHidden = !layer.isGroup
        disclosureWidth.constant = layer.isGroup ? 13 : 0
        disclosure.isEnabled = enabled
        let collapsed = session.collapsedGroupIDs.contains(layer.id)
        disclosure.image = Self.chevron(collapsed ? "chevron.right" : "chevron.down",
                                        description: collapsed ? "Expand group" : "Collapse group")
        // Pixel layers and masks show the whole canvas with their pixels where they sit, as Photoshop does;
        // adjustment and type layers show their symbol on a plate, groups a folder. Pictures redraw only when what
        // they show changes.
        let canvas = session.document?.size ?? CGSize(width: 1, height: 1)
        let editableText = layer.liveText != nil
        let framed = layer.adjustment == nil && !layer.isGroup && !editableText
        let box = Self.thumbnailBox, inset = Self.thumbnailInset
        let layerSize = framed ? CanvasThumbnail.fittedSize(canvas: canvas, box: box) : CGSize(width: box, height: box)
        thumbnailWidth.constant = layerSize.width + 2 * inset
        thumbnailHeight.constant = layerSize.height + 2 * inset
        let key = ThumbnailKey(image: layer.asset.map { ObjectIdentifier($0.thumbnail) }, transform: layer.transform, canvas: canvas, editableText: editableText)
        if layerID != layer.id || thumbnailKey != key {
            thumbnail.image = layer.adjustment.map { Self.symbolIcon($0.kind.panelSymbol, description: $0.kind.rawValue) }
                ?? (layer.isGroup ? Self.folderIcon
                    : editableText ? Self.typeIcon
                    : CanvasThumbnail.layer(layer.asset?.thumbnail, transform: layer.transform, canvas: canvas, box: box))
            thumbnailKey = key
        }
        thumbnail.plate = layer.adjustment != nil || editableText
        thumbnail.framed = framed
        thumbnail.contentTintColor = editableText ? ColorRole.text.nsColor : ColorRole.icon.nsColor
        let maskSize = CanvasThumbnail.fittedSize(canvas: canvas, box: box)
        maskThumbnailWidth.constant = maskSize.width + 2 * inset
        maskThumbnailHeight.constant = maskSize.height + 2 * inset
        let maskKey = ThumbnailKey(image: layer.mask.map { ObjectIdentifier($0.asset.thumbnail) }, transform: layer.maskTransform, canvas: canvas)
        if layerID != layer.id || maskThumbnailKey != maskKey {
            maskThumbnail.image = layer.mask.map { CanvasThumbnail.mask($0.asset.thumbnail, transform: layer.maskTransform, canvas: canvas, box: box) }
            maskThumbnailKey = maskKey
        }
        layerID = layer.id
        maskThumbnail.isHidden = layer.mask == nil
        maskThumbnail.layerID = layer.id
        maskWidth.constant = layer.mask == nil ? 0 : box + 2 * inset
        disabledMaskMark.isHidden = layer.mask?.isEnabled != false
        thumbnail.isEnabled = !session.showsBusy && !session.isImporting
        maskThumbnail.isEnabled = thumbnail.isEnabled
        outlinesThumbnail = framed || layer.mask != nil
        let linkable = layer.mask != nil && layer.adjustment == nil && !layer.isGroup
        maskGap.constant = layer.mask == nil ? 0 : linkable ? 10 : 2
        linkButton.isHidden = !linkable
        linkButton.image = layer.mask?.isLinked == false ? nil : Self.linkImage
        linkButton.isEnabled = thumbnail.isEnabled
        linkButton.toolTip = layer.mask?.isLinked == false ? "Link layer and mask so they move together"
            : "Unlink layer and mask to move or transform them separately"
        linkButton.setAccessibilityLabel(layer.mask?.isLinked == false ? "Link mask: \(layer.name)" : "Unlink mask: \(layer.name)")
        thumbnail.toolTip = layer.isGroup ? "Group"
            : editableText ? "Type layer: double-click to edit its text"
            : layer.adjustment.map { "\($0.kind.rawValue): double-click to edit it in Properties" }
            ?? "\(layer.sizeLabel). Click to target the layer; Cmd-click to select its pixels (Cmd-Shift adds, Cmd-Option subtracts)"
        maskThumbnail.toolTip = "Layer mask: click to target it; Option-click to view it alone; Shift-click to enable/disable; Cmd-click to select its black areas (Cmd-Shift adds, Cmd-Option subtracts)"
        let kind = editableText ? "text" : layer.isGroup ? "group" : layer.adjustment != nil ? "adjustment" : "image"
        thumbnail.setAccessibilityLabel("Select \(kind): \(layer.name)")
        maskThumbnail.setAccessibilityLabel("Select mask: \(layer.name)")
        let styled = !kinds.isEmpty
        effectsBadge.isHidden = !styled
        effectsBadge.image = Self.chevron(showsEffects ? "chevron.down" : "chevron.right", description: nil)
        effectsBadge.setAccessibilityLabel(showsEffects ? "Hide effects: \(layer.name)" : "Show effects: \(layer.name)")
        let inherited = session.document?.effectiveLocks(of: layer.id) ?? LayerLocks()
        let locked = !inherited.isEmpty
        lockMark.isHidden = !locked
        if locked {
            let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            lockMark.image = NSImage(systemSymbolName: layer.locks.all ? "lock.fill" : "lock", accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            lockMark.contentTintColor = layer.locks.isEmpty ? ColorRole.tertiaryText.nsColor : ColorRole.icon.nsColor
            lockMark.toolTip = layer.locks.isEmpty ? "Locked by its group" : layer.locks.all ? "Locked" : "Partly locked"
            lockMark.setAccessibilityLabel("\(lockMark.toolTip ?? ""): \(layer.name)")
        }
        NSLayoutConstraint.deactivate([nameToBadge, nameToEdge, nameToLock, badgeToEdge, badgeToLock])
        NSLayoutConstraint.activate(styled ? [nameToBadge, locked ? badgeToLock : badgeToEdge] : [locked ? nameToLock : nameToEdge])
        updateTarget()
        layerName = layer.name
        // A reused cell must not carry another row's half-finished rename.
        if renaming, layerID != layer.id { restoreLabel() }
        if !renaming { nameLabel.stringValue = (layer.maskSourceID == nil ? "" : "↳ ") + layer.name }
        eye.image = Self.eyeImage(visible: layer.isVisible)
        eye.setAccessibilityLabel("\(layer.isVisible ? "Hide" : "Show") \(layer.name)")
        eye.isEnabled = enabled
        eye.layerID = layer.id
        eye.session = session
        alphaValue = visible ? 1 : 0.35
    }
    private var maskThumbnailKey: ThumbnailKey?
    func selectEffect(at point: NSPoint, editing: Bool) -> Bool {
        guard let row = effectButtons.first(where: { $0.bounds.contains($0.convert(point, from: nil)) }) else { return false }
        row.select(editing: editing)
        return true
    }
    /// Whether a window point lands on the "Effects" row.
    func isOnEffectsHeader(_ windowPoint: NSPoint) -> Bool {
        guard let effectsHeader else { return false }
        return effectsHeader.bounds.contains(effectsHeader.convert(windowPoint, from: nil))
    }
    override func viewDidChangeEffectiveAppearance() { updateTarget() }
    func updateTarget() {
        effectButtons.forEach { $0.updateSelection() }
        let layer = session?.document?.layers.first(where: { $0.id == layerID })
        if let sourceID = layer?.maskSourceID {
            let source = session?.document?.layers.first(where: { $0.id == sourceID })?.name ?? "Missing source"
            nameLabel.toolTip = "Clipped to \(source). Option-click the bottom of its row to release."
        } else { nameLabel.toolTip = nil }
        let active = session?.activeLayerID == layerID && session?.selectedLayerIDs.count == 1
        let mask = session?.isMaskSelected == true
        // The targeted thumbnail is outlined in the text color, as in the mockup; a mask shown alone on the canvas
        // in the accent, so the two read apart.
        thumbnail.outline = active && !mask && outlinesThumbnail ? ColorRole.text.nsColor : nil
        maskThumbnail.outline = active && mask
            ? (session?.maskAloneLayer?.id == layerID ? NSColor.controlAccentColor : ColorRole.text.nsColor) : nil
    }
    /// Types the layer's name in the row: Return keeps it, Escape leaves it as it was, as does clicking away.
    func beginRenaming() {
        // Not `canEditLayers`: that is false while a rename is pending, which is exactly when this runs.
        guard !renaming, let session, layerID != nil,
              session.document != nil, !session.isProjectBusy, !session.isImporting else { return }
        renaming = true
        nameLabel.isEditable = true
        nameLabel.isSelectable = true
        nameLabel.isBezeled = true
        nameLabel.bezelStyle = .roundedBezel
        nameLabel.drawsBackground = true
        nameLabel.delegate = self
        nameLabel.stringValue = layerName
        window?.makeFirstResponder(nameLabel)
        nameLabel.currentEditor()?.selectAll(nil)
    }
    private func restoreLabel() {
        renaming = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.isBezeled = false
        nameLabel.drawsBackground = false
        nameLabel.delegate = nil
    }
    private func endRenaming(keeping: Bool) {
        guard renaming, let session, let layerID else { return }
        let typed = nameLabel.stringValue
        restoreLabel()
        if keeping { session.renameLayer(layerID, to: typed) }
        if session.renamingLayerID == layerID { session.renamingLayerID = nil }
        // Show whatever name the layer ended up with, marked as the row shows it.
        if let layer = session.document?.layers.first(where: { $0.id == layerID }) {
            layerName = layer.name
            nameLabel.stringValue = (layer.maskSourceID == nil ? "" : "↳ ") + layer.name
        }
        // Hand focus back to the list, so tool shortcuts and the arrow keys work straight away.
        var ancestor = superview
        while ancestor != nil && !(ancestor is NSTableView) { ancestor = ancestor?.superview }
        if let table = ancestor { window?.makeFirstResponder(table) }
    }
    func controlTextDidEndEditing(_ notification: Notification) { endRenaming(keeping: true) }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        endRenaming(keeping: false)
        return true
    }
    @objc private func selectImage() { if let layerID { session?.selectLayerTarget(layerID, mask: false) } }
    @objc private func toggleMaskLink() { if let layerID { session?.toggleMaskLink(layerID) } }
    /// Whether a window point lands on one of the row's buttons rather than its name.
    func isOnControl(_ windowPoint: NSPoint) -> Bool {
        [eye, disclosure, thumbnail, linkButton, maskThumbnail, effectsBadge].contains {
            !$0.isHidden && $0.bounds.contains($0.convert(windowPoint, from: nil))
        }
    }
    @objc func loadMaskSelection() {
        guard let layerID else { return }
        if Self.intersects { session?.intersectMaskSelection(layerID: layerID) }
        else { session?.loadMaskSelection(layerID: layerID, mode: Self.loadMode) }
    }
    @objc func loadLayerSelection() {
        guard let layerID else { return }
        if Self.intersects { session?.intersectLayerSelection(layerID: layerID) }
        else { session?.loadLayerSelection(layerID: layerID, mode: Self.loadMode) }
    }
    /// Cmd-Shift-Option intersects, as in Photoshop.
    private static var intersects: Bool { (NSApp.currentEvent?.modifierFlags ?? []).isSuperset(of: [.shift, .option]) }
    /// Cmd-Shift adds and Cmd-Option subtracts, as in Photoshop.
    private static var loadMode: SelectionMode {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        return flags.contains(.option) ? .subtract : flags.contains(.shift) ? .add : .replace
    }
    @objc func toggleMaskAlone() {
        guard let layerID else { return }
        session?.toggleMaskAlone(layerID)
    }
    @objc private func selectMask() {
        guard let layerID else { return }
        session?.selectLayerTarget(layerID, mask: true)
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { session?.toggleLayerMask() }
    }
    @objc private func toggleExpansion() { if let layerID { session?.toggleGroupExpansion(layerID) } }
    @objc private func toggleEffects() { if let layerID { session?.toggleEffectsExpansion(layerID) } }
    private var thumbnailKey: ThumbnailKey?
    @objc private func toggleVisibility() { if let layerID { session?.toggleLayerVisibility(layerID) } }

    static func eyeImage(visible: Bool, pointSize: CGFloat = 12) -> NSImage? {
        NSImage(systemSymbolName: visible ? "eye" : "eye.slash", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .regular))
    }
    private static func chevron(_ name: String, description: String?) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .semibold))
    }
    /// Symbols drawn centered in a template image the thumbnail's size, which the button shows 1:1 and tints:
    /// adjustment layers' symbols (the Adjustments panel's) at the panels' 15 pt, and a group's folder.
    private static var symbolIcons: [String: NSImage] = [:]
    private static func symbolIcon(_ name: String, description: String, pointSize: CGFloat = 15) -> NSImage? {
        if let icon = symbolIcons[name] { return icon }
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .regular)) else { return nil }
        let icon = NSImage(size: NSSize(width: thumbnailBox, height: thumbnailBox), flipped: false) { bounds in
            let size = symbol.size
            symbol.draw(in: NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height))
            return true
        }
        icon.isTemplate = true
        icon.accessibilityDescription = description
        symbolIcons[name] = icon
        return icon
    }
    private static let folderIcon = symbolIcon("folder", description: "Group", pointSize: 16)
    /// A type layer's thumbnail: a serif "T", as the Type tool's icon draws it.
    private static let typeIcon: NSImage = {
        let base = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: 15) } ?? base
        let letter = NSAttributedString(string: "T", attributes: [.font: font, .foregroundColor: NSColor.black])
        let icon = NSImage(size: NSSize(width: thumbnailBox, height: thumbnailBox), flipped: false) { bounds in
            let size = letter.size()
            letter.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
            return true
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "Type layer"
        return icon
    }()
}

/// Draws the separator along the top of a row under a styled layer.
@MainActor private func drawTopHairline(in view: NSView) {
    let scale = view.window?.backingScaleFactor ?? 2
    ColorRole.separator.nsColor.setFill()
    NSRect(x: 0, y: view.bounds.maxY - 1 / scale, width: view.bounds.width, height: 1 / scale).fill()
}

/// The "Effects" row under a styled layer: its eye hides or shows every effect; a double-click on it opens the
/// Layer Style dialog. Other clicks on it belong to the layer's row.
private final class LayerEffectsHeader: NSView {
    private let eye = NSButton()
    private weak var session: EditorSession?
    private let layerID: UUID
    init(session: EditorSession, layerID: UUID, showing: Bool, enabled: Bool, indent: CGFloat) {
        self.session = session; self.layerID = layerID
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: LayerCell.effectRowHeight).isActive = true
        eye.isBordered = false
        eye.image = LayerCell.eyeImage(visible: showing, pointSize: 11)
        eye.imagePosition = .imageOnly
        eye.contentTintColor = ColorRole.icon.nsColor
        eye.target = self; eye.action = #selector(toggle)
        eye.isEnabled = enabled
        eye.setAccessibilityLabel(showing ? "Hide Effects" : "Show Effects")
        let label = NSTextField(labelWithString: "Effects")
        label.font = .systemFont(ofSize: 11)
        label.textColor = ColorRole.secondaryText.nsColor
        for view in [eye, label] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            eye.leadingAnchor.constraint(equalTo: leadingAnchor), eye.centerYAnchor.constraint(equalTo: centerYAnchor),
            eye.widthAnchor.constraint(equalToConstant: LayerCell.eyeColumn), eye.heightAnchor.constraint(equalToConstant: LayerCell.effectRowHeight),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayerCell.nameStart + indent),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) { drawTopHairline(in: self) }
    override var isFlipped: Bool { false }
    /// Only the eye answers clicks; the rest of the row goes to the list, which selects the layer.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return eye.frame.contains(local) ? eye : nil
    }
    @objc private func toggle() { session?.toggleAllEffects(on: layerID) }
}

/// An effect belongs visually to its layer but has its own selection and visibility control.
private final class LayerEffectRow: NSView, NSDraggingSource {
    fileprivate weak var session: EditorSession?
    fileprivate let layerID: UUID
    fileprivate let kind: LayerEffectKind
    private var copyDown: NSEvent?
    private let eye = NSButton()
    private let label: NSTextField
    init(session: EditorSession, layerID: UUID, kind: LayerEffectKind, enabled: Bool, indent: CGFloat) {
        self.session = session; self.layerID = layerID; self.kind = kind
        label = NSTextField(labelWithString: kind.rawValue)
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: LayerCell.effectRowHeight).isActive = true
        eye.isBordered = false
        eye.image = LayerCell.eyeImage(visible: enabled, pointSize: 11)
        eye.imagePosition = .imageOnly
        eye.contentTintColor = ColorRole.icon.nsColor
        eye.target = self; eye.action = #selector(toggle)
        eye.isEnabled = session.canEditLayers
        eye.setAccessibilityLabel((enabled ? "Hide " : "Show ") + kind.rawValue)
        label.font = .systemFont(ofSize: 11)
        label.textColor = enabled ? ColorRole.secondaryText.nsColor : ColorRole.tertiaryText.nsColor
        label.lineBreakMode = .byTruncatingTail
        for view in [eye, label] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            eye.leadingAnchor.constraint(equalTo: leadingAnchor),
            eye.centerYAnchor.constraint(equalTo: centerYAnchor),
            eye.widthAnchor.constraint(equalToConstant: LayerCell.eyeColumn), eye.heightAnchor.constraint(equalToConstant: LayerCell.effectRowHeight),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayerCell.nameStart + LayerCell.indentStep + indent),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
        toolTip = "Click to select; double-click to edit; Option-drag to copy " + kind.rawValue.lowercased()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(kind.rawValue + " effect")
        updateSelection()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) { drawTopHairline(in: self) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
        if flags.contains(.option), !flags.contains(.command) { return self }
        return eye.frame.contains(local) ? eye : self
    }
    func select(editing: Bool) {
        session?.selectEffect(kind, on: layerID, editing: editing)
        var ancestor = superview
        while let view = ancestor, !(view is NSTableView) { ancestor = view.superview }
        if let ancestor { window?.makeFirstResponder(ancestor) }
        updateSelection()
    }
    override func mouseDown(with event: NSEvent) {
        copyDown = nil
        if event.modifierFlags.contains(.option), !event.modifierFlags.contains(.command), session?.canEditLayers == true {
            copyDown = event
        } else { select(editing: event.clickCount > 1) }
    }
    override func mouseUp(with event: NSEvent) {
        if copyDown != nil { copyDown = nil; select(editing: false) }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let down = copyDown else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        guard dx * dx + dy * dy >= 9 else { return }
        copyDown = nil
        guard event.modifierFlags.contains(.option), session?.canEditLayers == true else { return }
        let item = NSPasteboardItem()
        item.setString(layerID.uuidString + ":" + kind.rawValue, forType: NativeLayerList.Coordinator.effectType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let snapshot = NSImage(size: bounds.size)
        if let rep = bitmapImageRepForCachingDisplay(in: bounds) {
            cacheDisplay(in: bounds, to: rep)
            snapshot.addRepresentation(rep)
        }
        dragging.setDraggingFrame(bounds, contents: snapshot)
        beginDraggingSession(with: [dragging], event: down, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .copy : []
    }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { select(editing: false); return true }
    @objc private func toggle() { session?.toggleEffect(kind, on: layerID) }
    func updateSelection() {
        let selected = session?.selectedEffect == LayerEffectSelection(layerID: layerID, kind: kind)
        layer?.backgroundColor = selected ? ColorRole.selection.resolved(for: effectiveAppearance).cgColor : NSColor.clear.cgColor
    }
}

/// Select on mouse-down, then let the table retain native drag and multiselect tracking.
private final class LayerThumbnailButton: NSButton, NSDraggingSource {
    /// The row's layer, for a mask thumbnail's Option-drag.
    var layerID: UUID?
    var isMaskTarget = false { didSet { updateTrackingAreas() } }
    /// Image thumbnails also load a selection on Cmd-click (masks always do).
    var loadsSelection = false { didSet { updateTrackingAreas() } }
    var cmdClickLoads: Bool { isMaskTarget || loadsSelection }
    /// Drawn on a `control` plate (adjustment and type layers' symbols) or edged as a well (pictures and masks).
    var plate = false { didSet { if plate != oldValue { needsDisplay = true } } }
    var framed = false { didSet { if framed != oldValue { needsDisplay = true } } }
    /// The target outline, 2 pt wide and 1 pt off the picture.
    var outline: NSColor? { didSet { if outline != oldValue { needsDisplay = true } } }
    override func draw(_ dirtyRect: NSRect) {
        let picture = bounds.insetBy(dx: LayerCell.thumbnailInset, dy: LayerCell.thumbnailInset)
        if plate {
            ColorRole.control.nsColor.setFill()
            NSBezierPath(roundedRect: picture, xRadius: 3, yRadius: 3).fill()
        }
        super.draw(dirtyRect)
        if framed {
            ColorRole.edge.nsColor.setStroke()
            let edge = NSBezierPath(rect: picture.insetBy(dx: 0.5, dy: 0.5))
            edge.lineWidth = 1
            edge.stroke()
        }
        if let outline {
            outline.setStroke()
            let ring = NSBezierPath(rect: picture.insetBy(dx: -2, dy: -2))
            ring.lineWidth = 2
            ring.stroke()
        }
    }
    private var hoverArea: NSTrackingArea?
    private var hovering = false
    private var modifierMonitor: Any?

    // Mask thumbnails show the load-selection cursor while hovered with Cmd held.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = nil
        guard cmdClickLoads else { return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate,
                                                         .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        guard cmdClickLoads else { return }
        hovering = true
        if modifierMonitor == nil {
            modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                guard let self else { return event }
                self.updateCursor(event.modifierFlags)
                DispatchQueue.main.async { [weak self] in self?.updateCursor(NSEvent.modifierFlags) }
                return event
            }
        }
        updateCursor(event.modifierFlags)
    }
    override func mouseMoved(with event: NSEvent) { if hovering { updateCursor(event.modifierFlags) } }
    override func cursorUpdate(with event: NSEvent) {
        if hovering { updateCursor(event.modifierFlags) } else { super.cursorUpdate(with: event) }
    }
    override func mouseExited(with event: NSEvent) {
        guard hovering else { return }
        hovering = false
        if let modifierMonitor { NSEvent.removeMonitor(modifierMonitor) }
        modifierMonitor = nil
        // The list decides what the cursor is anywhere else in the row; leaving a thumbnail is not a reason to
        // drop the clipping or duplicate cursor it is showing.
        var ancestor = superview
        while ancestor != nil && !(ancestor is LayerTableView) { ancestor = ancestor?.superview }
        if let table = ancestor as? LayerTableView { table.refreshClippingCursor(NSEvent.modifierFlags) }
        else { NSCursor.arrow.set() }
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, let modifierMonitor { NSEvent.removeMonitor(modifierMonitor); self.modifierMonitor = nil }
    }
    private func updateCursor(_ flags: NSEvent.ModifierFlags) {
        guard hovering, isEnabled else { return }
        if flags.contains(.option), !flags.contains(.command) {
            var ancestor = superview
            while ancestor != nil && !(ancestor is LayerTableView) { ancestor = ancestor?.superview }
            (ancestor as? LayerTableView)?.refreshClippingCursor(flags)
            return
        }
        (flags.contains(.command) ? CanvasView.loadSelectionCursor : NSCursor.arrow).set()
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        var ancestor = superview
        while ancestor != nil && !(ancestor is NSTableView) { ancestor = ancestor?.superview }
        guard let table = ancestor as? NSTableView else { super.mouseDown(with: event); return }
        if event.modifierFlags.contains(.option), !event.modifierFlags.contains(.command) {
            if isMaskTarget, !isHidden { dragMaskCopy(event); return }
            table.mouseDown(with: event)
            return
        }
        if cmdClickLoads && event.modifierFlags.contains(.command) {
            // Cmd-click on a thumbnail loads a selection; elsewhere in the row it multi-selects.
            _ = target?.perform(isMaskTarget ? #selector(LayerCell.loadMaskSelection) : #selector(LayerCell.loadLayerSelection))
            return
        }
        if isMaskTarget && event.modifierFlags.contains(.shift) {
            sendAction(action, to: target)
            return
        }
        if event.modifierFlags.intersection([.command, .shift]).isEmpty { sendAction(action, to: target) }
        table.mouseDown(with: event)
    }
}

extension LayerThumbnailButton {
    /// Option-drag from a mask thumbnail carries a copy of the mask to another row; a click without a drag shows
    /// the mask alone on the canvas, or the composite again, as in Photoshop.
    fileprivate func dragMaskCopy(_ down: NSEvent) {
        guard let window, let layerID else { return }
        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { _ = target?.perform(#selector(LayerCell.toggleMaskAlone)); return }
            let dx = event.locationInWindow.x - down.locationInWindow.x, dy = event.locationInWindow.y - down.locationInWindow.y
            guard dx * dx + dy * dy >= 9 else { continue }
            let item = NSPasteboardItem()
            item.setString(layerID.uuidString, forType: NativeLayerList.Coordinator.maskType)
            let dragging = NSDraggingItem(pasteboardWriter: item)
            let snapshot = NSImage(size: bounds.size)
            if let rep = bitmapImageRepForCachingDisplay(in: bounds) {
                cacheDisplay(in: bounds, to: rep)
                snapshot.addRepresentation(rep)
            }
            dragging.setDraggingFrame(bounds, contents: snapshot)
            beginDraggingSession(with: [dragging], event: down, source: self)
            return
        }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .copy : []
    }
}
/// One device pixel of separator, along the bottom of the view or, vertical, down its left; ignored by clicks.
private final class RowEdgeLine: NSView {
    private var vertical = false
    convenience init(vertical: Bool) {
        self.init(frame: .zero)
        self.vertical = vertical
    }
    override func draw(_ dirtyRect: NSRect) {
        let scale = window?.backingScaleFactor ?? 2
        ColorRole.separator.nsColor.setFill()
        (vertical ? NSRect(x: 0, y: 0, width: 1 / scale, height: bounds.height)
                  : NSRect(x: 0, y: 0, width: bounds.width, height: 1 / scale)).fill()
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
/// A layer's eye. Pressing it shows or hides the layer; keeping the button down and dragging up or down the list
/// gives every eye passed over the same state, as in Photoshop.
private final class EyeSwipeButton: NSButton {
    var layerID: UUID?
    weak var session: EditorSession?
    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let layerID, let session, let window,
              let visible = session.beginVisibilitySwipe(layerID) else { return }
        // Showing or hiding a layer reloads its row, which can take this very button out of the list; tracking the
        // drag here, rather than waiting for mouseDragged and mouseUp to arrive, keeps the undo step from being left
        // open if it does.
        defer { session.endVisibilitySwipe() }
        var ancestor = superview
        while ancestor != nil && !(ancestor is NSTableView) { ancestor = ancestor?.superview }
        guard let table = ancestor as? NSTableView else { return }
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { return }
            let row = table.row(at: table.convert(next.locationInWindow, from: nil))
            guard session.layerRows.indices.contains(row) else { continue }
            session.setVisibilityInSwipe(session.layerRows[row].layer.id, visible: visible)
            table.autoscroll(with: next)
        }
    }
}
private final class MaskDisabledMark: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// What a row's canvas-framed thumbnail shows, so it redraws only when one of these changes.
private struct ThumbnailKey: Equatable {
    let image: ObjectIdentifier?
    let transform: LayerTransform
    let canvas: CGSize
    var editableText = false
}

extension ImageLayer {
    /// The layer's size on the canvas and, once it's scaled, by how much, for its row. A photo shrunk to 5% keeps
    /// every one of its pixels; the percentage says so, where the size alone reads as if it had been resampled small.
    var sizeLabel: String {
        let text = "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) px"
        guard let pixels = asset?.image.width, pixels > 0 else { return text }
        // Measured across the width, as the Transform bar's Scale field is.
        let percent = Double(size.width) / Double(pixels) * 100
        guard abs(percent - 100) >= 0.05 else { return text }
        return text + " · " + percent.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }
}
