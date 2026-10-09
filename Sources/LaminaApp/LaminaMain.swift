import SwiftUI
import Sparkle
import LaminaCore

@main
struct LaminaMain: App {
    @NSApplicationDelegateAdaptor(LaminaApplicationDelegate.self) private var applicationDelegate
    private var session: EditorSession { applicationDelegate.session }
    var body: some Scene {
        Window("Lamina", id: "editor") {
            ProjectWorkspaceView(applicationDelegate: applicationDelegate).roundedControls()
        }
            .defaultSize(width: 1180, height: 780)
            // Files opened from Finder or dropped on the Dock icon go to the app delegate, which imports them into
            // the open window. Left to SwiftUI, each one builds a throwaway window and fades the editor out and back.
            .handlesExternalEvents(matching: [])
            // A first launch fills the screen (without going full screen); after that macOS reopens the window at the
            // size it was left.
            .defaultWindowPlacement { _, context in
                WindowPlacement(size: context.defaultDisplay.visibleRect.size)
            }
            // The project's name is already on its tab, so the toolbar doesn't repeat it as a window title.
            .windowToolbarStyle(.unifiedCompact(showsTitle: false))
            // The menu bar as docs/DESIGN.md (Menus) lists it: Lamina, File, Edit, Image, Layer, Type, Select, Filter,
            // View, Window, Help. Menus made here follow the system's View menu, so View is made here too, after Filter.
            .commands {
                AppMenuCommands(applicationDelegate: applicationDelegate)
                FileMenuCommands(applicationDelegate: applicationDelegate, session: session)
                EditMenuCommands(applicationDelegate: applicationDelegate, session: session)
                ImageMenuCommands(applicationDelegate: applicationDelegate, session: session)
                LayerMenuCommands(session: session)
                TypeMenuCommands(session: session)
                SelectMenuCommands(session: session)
                FilterMenuCommands(session: session)
                ViewMenuCommands(applicationDelegate: applicationDelegate, session: session)
                Group {
                    // ⌘M is Curves…, as in Photoshop. With Curves down in Image › Adjustments, the system's Minimize
                    // kept ⌘M and Curves lost it, so Minimize and Zoom are made here, without keys (`MenuBarOrder`
                    // keeps them first in Window).
                    CommandGroup(replacing: .windowSize) {
                        Button("Minimize") { NSApp.mainWindow?.performMiniaturize(nil) }
                            .assignableShortcut("Window › Minimize")
                        Button("Zoom") { NSApp.mainWindow?.performZoom(nil) }
                            .assignableShortcut("Window › Zoom")
                    }
                    DockCommands(layout: DockLayout.shared, session: session)
                    // Lamina has no help book; the system's Search stays.
                    CommandGroup(replacing: .help) {}
                }
            }
    }
}

/// Lamina: About · Check for Updates… │ Settings… │ Services │ Hide Lamina · Hide Others · Show All │ Quit.
private struct AppMenuCommands: Commands {
    let applicationDelegate: LaminaApplicationDelegate
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { applicationDelegate.updater?.checkForUpdates(nil) }
                .assignableShortcut("Lamina › Check for Updates…")
                .disabled(applicationDelegate.updater == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { SettingsWindow.shared.show() }.configuredKeyboardShortcut("k")
        }
        // ⌘H is View ▸ Extras (docs/DESIGN.md, Shortcut changes), so Hide takes ⌃⌘H.
        CommandGroup(replacing: .appVisibility) {
            Button("Hide Lamina") { NSApp.hide(nil) }
                .configuredKeyboardShortcut("h", modifiers: [.command, .control])
            Button("Hide Others") { NSApp.hideOtherApplications(nil) }
                .configuredKeyboardShortcut("h", modifiers: [.command, .option])
            Button("Show All") { NSApp.unhideAllApplications(nil) }
                .assignableShortcut("Lamina › Show All")
        }
    }
}

/// File: New… · New from Clipboard · Open… · Open Recent │ Close │ Save · Save As… · Save a Copy… │ Export │
/// Place Embedded….
private struct FileMenuCommands: Commands {
    let applicationDelegate: LaminaApplicationDelegate
    let session: EditorSession
    private var projects: ProjectController { applicationDelegate.projects }
    private var canExport: Bool { session.document != nil && projects.canStart }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New…") {
                applicationDelegate.showEditor?()
                Task { await projects.newCanvas() }
            }.configuredKeyboardShortcut("n")
                .disabled(!projects.canStart)
            // As in Preview: a new project from the image on the clipboard, no size to fill in. ⌥⌘N, since
            // ⇧⌘V is Photoshop's Paste in Place.
            Button("New from Clipboard") {
                applicationDelegate.showEditor?()
                Task { if !(await applicationDelegate.workspace.newFromClipboard()) { NSSound.beep() } }
            }
                .configuredKeyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!projects.canStart || !applicationDelegate.workspace.clipboardOffersImage)
            Button("Open…") {
                applicationDelegate.showEditor?()
                Task { await projects.open() }
            }
                .configuredKeyboardShortcut("o").disabled(!projects.canStart)
            Menu("Open Recent") {
                ForEach(RecentProjects.shared.urls, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) {
                        applicationDelegate.showEditor?()
                        Task { await projects.open(url) }
                    }
                }
                Divider()
                Button("Clear Recent File List") { RecentProjects.shared.clear() }
                    .assignableShortcut("File › Open Recent › Clear Recent File List")
                    .disabled(RecentProjects.shared.urls.isEmpty)
            }
                .disabled(!projects.canStart)
            Divider()
            Button("Close") {
                if let window = projects.window {
                    Task { await projects.close(window) }
                }
            }.configuredKeyboardShortcut("w").disabled(!projects.canStart)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { Task { await projects.save() } }
                .configuredKeyboardShortcut("s").disabled(session.document == nil || !projects.canStart)
            Button("Save As…") { Task { await projects.save(asNew: true) } }
                .configuredKeyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(session.document == nil || !projects.canStart)
            PlannedMenuItem(feature: .saveACopy, session: session)
                .configuredKeyboardShortcut("s", modifiers: [.command, .option])
            Divider()
            Menu("Export") {
                Button("Quick Export as PNG") { Task { await projects.quickExportPNG() } }
                    .assignableShortcut("File › Export › Quick Export as PNG")
                    .disabled(!canExport)
                Divider()
                Button("Export As…") { Task { await projects.exportAs() } }
                    .configuredKeyboardShortcut("w", modifiers: [.command, .option, .shift])
                    .disabled(!canExport)
            }
            Divider()
            Button("Place Embedded…") { session.showsImporter = true }
                .assignableShortcut("File › Place Embedded…")
                .disabled(session.levels != nil || session.showsBusy || session.isImporting || session.showsNewDocument)
        }
    }
}

/// Edit: Undo · Redo │ Cut · Copy · Copy Merged · Paste · Clear │ Search │ Fill… · Stroke… · Content-Aware Fill… │
/// Free Transform · Transform │ Keyboard Shortcuts… · Toolbar….
private struct EditMenuCommands: Commands {
    let applicationDelegate: LaminaApplicationDelegate
    let session: EditorSession

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            // Dialog text fields keep native text undo; document history
            // is unavailable while an import or modal edit is active.
            if session.textDraft != nil || session.levels != nil || session.isProjectBusy || session.showsNewDocument || session.showsImporter || session.renamingLayerID != nil || session.transformEdit?.persistent == true {
                Button("Undo") {
                    if NSApp.keyWindow?.firstResponder is NSTextView {
                        NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil)
                    }
                }
                    .configuredKeyboardShortcut("z")
                Button("Redo") {
                    if NSApp.keyWindow?.firstResponder is NSTextView {
                        NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil)
                    }
                }
                    .configuredKeyboardShortcut("z", modifiers: [.command, .shift])
            } else {
                Button(session.history.canUndo ? "Undo \(session.history.undoName)" : "Undo") { session.undo() }
                    .configuredKeyboardShortcut("z").disabled(!session.canUndo)
                Button(session.history.canRedo ? "Redo \(session.history.redoName)" : "Redo") { session.redo() }
                    .configuredKeyboardShortcut("z", modifiers: [.command, .shift]).disabled(!session.canRedo)
            }
        }
        CommandGroup(replacing: .pasteboard) {
            // Canvas pixels when the canvas has focus; text fields keep their own editing.
            // Cut, Copy and Paste check when chosen rather than through .disabled: what they depend on
            // (the pasteboard, the copied pixels, the busy flag) isn't observed, so a disabled state could
            // go stale — the first Paste after a Copy used to beep until something else refreshed the menu.
            Button("Cut") {
                if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                else if session.selection != nil, session.canCopyPixels { Task { await session.cutSelection() } }
                else { NSSound.beep() }
            }
                .configuredKeyboardShortcut("x")
            Button("Copy") {
                if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                else if session.canCopyPixels || session.canCopyLayer { session.copySelection() }
                else { NSSound.beep() }
            }
                .configuredKeyboardShortcut("c")
            Button("Copy Merged") { session.copyMergedSelection() }
                .configuredKeyboardShortcut("c", modifiers: [.command, .shift]).disabled(!session.canCopyMerged)
            Button("Paste") {
                if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                else if applicationDelegate.workspace.pasteCopiedLayer() { }
                else if session.canPaste { session.paste() }
                else { NSSound.beep() }
            }
                .configuredKeyboardShortcut("v")
            Button("Clear") { Task { await session.clearSelectedPixels() } }
                .assignableShortcut("Edit › Clear")
                .disabled(session.selection == nil || !session.canEditPixels)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            PlannedMenuItem(feature: .search, session: session).configuredKeyboardShortcut("f")
            Divider()
            // Also ⇧⌫; ⌥⌫ and ⌘⌫ fill straight away with the foreground and background colors (`CanvasView`).
            Button("Fill…") { session.beginFill() }
                .configuredKeyboardShortcut(KeyEquivalent(Character(ShortcutChord.functionKey(5))), modifiers: .shift)
                .disabled(!session.canFill)
            Button("Stroke…") { Task { await applicationDelegate.projects.stroke() } }
                .assignableShortcut("Edit › Stroke…")
                .disabled(!session.canStrokeSelection)
            Button("Content-Aware Fill…") { session.beginFilter(.contentAwareFill) }
                .assignableShortcut("Edit › Content-Aware Fill…")
                .disabled(!session.canContentAwareFill)
            Divider()
            // The selected pixels when there is a selection, else the layer (or the selected layers).
            Button("Free Transform") { session.transformCommand() }
                .configuredKeyboardShortcut("t").disabled(!session.canTransform && !session.canTransformSelection)
            Menu("Transform") {
                Button("Distort") { Task { await session.distortCommand() } }
                    .assignableShortcut("Edit › Transform › Distort")
                    .disabled(!session.canDistort)
                Divider()
                Button("Flip Horizontal") { session.flipTransform(horizontally: true) }
                    .assignableShortcut("Edit › Transform › Flip Horizontal")
                    .disabled(!session.canFlipTransform)
                Button("Flip Vertical") { session.flipTransform(horizontally: false) }
                    .assignableShortcut("Edit › Transform › Flip Vertical")
                    .disabled(!session.canFlipTransform)
            }
            Divider()
            Button("Keyboard Shortcuts…") { ShortcutSettings.shared.show() }
                .configuredKeyboardShortcut("k", modifiers: [.command, .option, .shift])
            PlannedMenuItem(feature: .customizeToolbar, session: session)
        }
    }
}

/// Image: Mode │ Adjustments │ Image Size… · Canvas Size… · Image Rotation · Trim….
private struct ImageMenuCommands: Commands {
    let applicationDelegate: LaminaApplicationDelegate
    let session: EditorSession
    private var cannotAdjust: Bool { !session.canAdjustColors || session.hueSaturation != nil }

    var body: some Commands {
        CommandMenu("Image") {
            // Lamina works in RGB at 8 bits per channel; 16 and 32 bits are planned (TASK-90).
            Menu("Mode") {
                Toggle("RGB Color", isOn: .constant(true)).assignableShortcut("Image › Mode › RGB Color")
                Divider()
                Toggle("8 Bits/Channel", isOn: .constant(true)).assignableShortcut("Image › Mode › 8 Bits/Channel")
                PlannedMenuItem(feature: .sixteenBitsPerChannel, session: session)
                PlannedMenuItem(feature: .thirtyTwoBitsPerChannel, session: session)
            }
            Divider()
            Menu("Adjustments") {
                Button("Levels…") { session.beginLevels() }
                    .configuredKeyboardShortcut("l").disabled(cannotAdjust)
                Button("Curves…") { session.beginFilter(.curves) }
                    .configuredKeyboardShortcut("m").disabled(cannotAdjust)
                Button("Exposure…") { session.beginFilter(.exposure) }
                    .assignableShortcut("Image › Adjustments › Exposure…").disabled(cannotAdjust)
                Divider()
                Button("Hue/Saturation…") { session.beginHueSaturation() }
                    .configuredKeyboardShortcut("u").disabled(!session.canAdjustColors)
                Button("Color Balance…") { session.beginFilter(.colorBalance) }
                    .configuredKeyboardShortcut("b").disabled(cannotAdjust)
                Button("Black & White…") { session.beginFilter(.blackWhite) }
                    .configuredKeyboardShortcut("b", modifiers: [.command, .option, .shift]).disabled(cannotAdjust)
                PlannedMenuItem(feature: .colorLookup, session: session)
                Divider()
                // A targeted mask inverts too.
                Button("Invert") { Task { await session.invertPixels() } }
                    .configuredKeyboardShortcut("i").disabled(!session.canInvert)
                Button("Gradient Map…") { session.beginFilter(.gradientMap) }
                    .assignableShortcut("Image › Adjustments › Gradient Map…").disabled(cannotAdjust)
                Divider()
                Button("Grain…") { session.beginFilter(.grain) }
                    .assignableShortcut("Image › Adjustments › Grain…").disabled(cannotAdjust)
            }
            Divider()
            Button("Image Size…") { Task { await applicationDelegate.projects.imageSize() } }
                .configuredKeyboardShortcut("i", modifiers: [.command, .option])
                .disabled(session.document == nil || !applicationDelegate.projects.canStart)
            Button("Canvas Size…") { Task { await applicationDelegate.projects.canvasSize() } }
                .configuredKeyboardShortcut("c", modifiers: [.command, .option])
                .disabled(session.document == nil || !applicationDelegate.projects.canStart)
            Menu("Image Rotation") {
                ForEach([CanvasRotation.halfTurn, .clockwise, .counterclockwise], id: \.self) { rotation in
                    Button(rotation.rawValue) { Task { await session.rotateCanvas(rotation) } }
                        .assignableShortcut("Image › Image Rotation › \(rotation.rawValue)")
                }
                Divider()
                Button("Flip Canvas Horizontal") { session.flipCanvas(horizontally: true) }
                    .assignableShortcut("Image › Image Rotation › Flip Canvas Horizontal")
                Button("Flip Canvas Vertical") { session.flipCanvas(horizontally: false) }
                    .assignableShortcut("Image › Image Rotation › Flip Canvas Vertical")
            }
                .disabled(!session.canEditLayers)
            Button("Trim…") { Task { await applicationDelegate.projects.trim() } }
                .assignableShortcut("Image › Trim…")
                .disabled(session.document == nil || !applicationDelegate.projects.canStart)
        }
    }
}

/// Layer, in the groups docs/DESIGN.md lists: making and deleting layers, styles, adjustments, masks, placeholders,
/// grouping and visibility, stacking order, alignment, merging.
private struct LayerMenuCommands: Commands {
    let session: EditorSession
    private var hasLayer: Bool { session.canEditLayers && session.activeLayer != nil }

    var body: some Commands {
        CommandMenu("Layer") {
            Menu("New") {
                Button("Layer…") { session.newLayerNamingIt() }
                    .configuredKeyboardShortcut("n", modifiers: [.command, .shift]).disabled(!session.canEditLayers)
                Divider()
                Button("Group…") { session.newGroupNamingIt() }
                    .assignableShortcut("Layer › New › Group…").disabled(!session.canEditLayers)
                Button("Group from Layers…") { session.groupFromLayersNamingIt() }
                    .assignableShortcut("Layer › New › Group from Layers…").disabled(!hasLayer)
                Divider()
                // With no selection it copies the whole layer, as in Photoshop.
                Button("Layer Via Copy") { session.layerViaCopy() }
                    .configuredKeyboardShortcut("j")
                    .disabled(!session.canCopyPixels && !(session.selection == nil && hasLayer))
            }
            Button("Duplicate Layer…") { session.duplicateLayerNamingIt() }
                .assignableShortcut("Layer › Duplicate Layer…").disabled(!hasLayer)
            Menu("Delete") {
                Button("Layer") { session.deleteSelectedLayers() }
                    .assignableShortcut("Layer › Delete › Layer").disabled(!hasLayer)
            }
            Divider()
            Button("Rename Layer…") { session.renamingLayerID = session.activeLayerID }
                .assignableShortcut("Layer › Rename Layer…").disabled(!hasLayer)
            Menu("Layer Style") {
                ForEach(LayerStylePage.all, id: \.self) { page in
                    Button(page.title + "…") { session.openLayerStyle(page) }
                        .assignableShortcut("Layer › Layer Style › \(page.title)…")
                        .disabled(!session.canOpenLayerStyle)
                    if page == .blendingOptions { Divider() }
                }
                Divider()
                Button("Copy Layer Style") { session.copyLayerStyle() }
                    .assignableShortcut("Layer › Layer Style › Copy Layer Style")
                    .disabled(!session.canCopyLayerStyle)
                Button("Paste Layer Style") { session.pasteLayerStyle() }
                    .assignableShortcut("Layer › Layer Style › Paste Layer Style")
                    .disabled(!session.canPasteLayerStyle)
                Button("Clear Layer Style") { session.clearLayerStyle() }
                    .assignableShortcut("Layer › Layer Style › Clear Layer Style")
                    .disabled(!session.canClearLayerStyle)
            }
            Divider()
            Menu("New Adjustment Layer") {
                ForEach(Array(AdjustmentKind.menuSections.enumerated()), id: \.offset) { index, section in
                    if index > 0 { Divider() }
                    ForEach(section, id: \.self) { kind in
                        Button(kind.rawValue + (kind.isEditable ? "…" : "")) { session.addAdjustment(kind) }
                            .assignableShortcut("Layer › New Adjustment Layer › \(kind.rawValue)")
                    }
                }
            }.disabled(!session.canEditLayers || session.document == nil)
            // An adjustment layer's settings, which show in Properties.
            Button("Layer Content Options…") { session.showProperties() }
                .assignableShortcut("Layer › Layer Content Options…")
                .disabled(session.activeLayer?.adjustment == nil)
            Divider()
            Menu("Layer Mask") {
                Button("Reveal All") { session.addLayerMask(revealing: true) }
                    .assignableShortcut("Layer › Layer Mask › Reveal All").disabled(!session.canAddLayerMask)
                Button("Hide All") { session.addLayerMask(revealing: false) }
                    .assignableShortcut("Layer › Layer Mask › Hide All").disabled(!session.canAddLayerMask)
                Button("Reveal Selection") { session.addMask(revealing: true) }
                    .assignableShortcut("Layer › Layer Mask › Reveal Selection").disabled(!session.canAddSelectionMask)
                Button("Hide Selection") { session.addMask(revealing: false) }
                    .assignableShortcut("Layer › Layer Mask › Hide Selection").disabled(!session.canAddSelectionMask)
                Divider()
                Button("Delete") { session.deleteLayerMask() }
                    .assignableShortcut("Layer › Layer Mask › Delete").disabled(!session.canDeleteLayerMask)
                Button("Apply") { session.applyLayerMask() }
                    .assignableShortcut("Layer › Layer Mask › Apply").disabled(!session.canApplyLayerMask)
            }
            Button(session.activeLayer?.maskSourceID == nil ? "Create Clipping Mask" : "Release Clipping Mask") {
                if let id = session.activeLayerID { session.toggleClippingMask(id) }
            }
                .configuredKeyboardShortcut("g", modifiers: [.command, .option])
                .disabled(session.activeLayerID.map { !session.canToggleClippingMask($0) } ?? true)
            // A dialog in Lamina (Basic or Advanced, with a preview), so it keeps its ellipsis.
            Button("Remove Background…") { session.beginFilter(.removeBackground) }
                .assignableShortcut("Layer › Remove Background…")
                .disabled(!session.canAdjustColors || session.hueSaturation != nil)
            Divider()
            PlannedMenuItem(feature: .rasterize, session: session)
            PlannedMenuItem(feature: .convertToEditableVectors, session: session)
            Divider()
            Button("Group Layers") { session.groupSelectedLayers() }
                .configuredKeyboardShortcut("g").disabled(!session.canEditLayers)
            Button("Ungroup Layers") { session.ungroupLayers() }
                .configuredKeyboardShortcut("g", modifiers: [.command, .shift]).disabled(!session.canUngroupLayers)
            Button(session.selectedLayersHidden ? "Show Layers" : "Hide Layers") { session.toggleSelectedLayersVisibility() }
                .configuredKeyboardShortcut(",").disabled(!hasLayer)
            Button(session.activeLayerID.map { session.hasOtherVisibleLayers(than: $0) } == false ? "Show All Other Layers" : "Hide All Other Layers") {
                if let id = session.activeLayerID { session.toggleOtherLayersVisibility(id) }
            }.assignableShortcut("Layer › Hide All Other Layers")
                .disabled(!session.canToggleOtherLayers || session.activeLayer == nil)
            Divider()
            Menu("Arrange") {
                Button("Bring Forward") { session.moveActiveLayer(by: 1) }
                    .configuredKeyboardShortcut("]").disabled(!session.canMoveActiveLayer(by: 1))
                Button("Send Backward") { session.moveActiveLayer(by: -1) }
                    .configuredKeyboardShortcut("[").disabled(!session.canMoveActiveLayer(by: -1))
                Divider()
                Button("Move Out of Group") { session.moveActiveLayerOutOfGroup() }
                    .assignableShortcut("Layer › Arrange › Move Out of Group")
                    .disabled(!session.canEditLayers || session.activeLayer?.parentID == nil)
            }
            Menu("Combine Shapes") {
                ForEach(PlannedFeature.combineShapes) { PlannedMenuItem(feature: $0, session: session) }
            }
            PlannedMenuItem(feature: .releaseToLayers, session: session)
            Divider()
            Menu("Align") {
                ForEach(LayerAlignment.menuSections.indices, id: \.self) { index in
                    if index > 0 { Divider() }
                    ForEach(LayerAlignment.menuSections[index], id: \.self) { alignment in
                        Button(alignment.rawValue) { session.alignLayers(alignment) }
                            .assignableShortcut("Layer › Align › \(alignment.rawValue)")
                    }
                }
            }
                .disabled(!session.canAlignLayers)
            Menu("Distribute") {
                ForEach(LayerDistribution.menuSections.indices, id: \.self) { index in
                    if index > 0 { Divider() }
                    ForEach(LayerDistribution.menuSections[index], id: \.self) { distribution in
                        Button(distribution.menuTitle) { session.distributeLayers(distribution) }
                            .assignableShortcut("Layer › Distribute › \(distribution.menuTitle)")
                    }
                }
            }
                .disabled(!session.canDistributeLayers)
            Divider()
            // Merge Down, or Merge Layers with several selected.
            Button(session.mergeTitle) { session.mergeLayers() }
                .configuredKeyboardShortcut("e").disabled(!session.canMergeLayers)
            Button("Merge Visible") { session.mergeVisible() }
                .configuredKeyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!session.canMergeVisible)
            Button("Flatten Image") { session.flattenImage() }
                .assignableShortcut("Layer › Flatten Image")
                .disabled(!session.canFlattenImage)
        }
    }
}

/// Type: Panels (Character, Paragraph). Lamina keeps the type settings in Properties, so both open it.
private struct TypeMenuCommands: Commands {
    let session: EditorSession
    var body: some Commands {
        CommandMenu("Type") {
            Menu("Panels") {
                Button("Character") { session.showProperties() }
                    .assignableShortcut("Type › Panels › Character")
                Button("Paragraph") { session.showProperties() }
                    .assignableShortcut("Type › Panels › Paragraph")
            }
        }
    }
}

/// Select: All · Deselect · Inverse │ Color Range… · Subject │ Modify │ Load Selection….
private struct SelectMenuCommands: Commands {
    let session: EditorSession

    var body: some Commands {
        CommandMenu("Select") {
            // A field being edited keeps its own Select All: offer it to the responder chain
            // first, which covers every kind of text control rather than NSTextView alone,
            // and select the canvas only when nothing there wanted it.
            Button("All") {
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) { return }
                guard session.document != nil else { return }
                session.selectAll()
            }
                // Never disabled: on macOS this menu item is what binds Cmd-A to selectAll:, so
                // switching it off takes Select All away from every text field too. With no
                // document and nothing being edited the action simply does nothing.
                .configuredKeyboardShortcut("a")
            Button("Deselect") { session.deselect() }
                .configuredKeyboardShortcut("d").disabled(session.selection == nil || !session.canEditSelection)
            Button("Inverse") { session.invertSelection() }
                .configuredKeyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(session.selection == nil || !session.canEditSelection)
            Divider()
            Button("Color Range…") { session.beginColorRange() }
                .assignableShortcut("Select › Color Range…")
                .disabled(!session.canSelectColorRange)
            Button("Subject") { Task { await session.selectSubject() } }
                .assignableShortcut("Select › Subject")
                .disabled(!session.canSelectSubject)
            Divider()
            Menu("Modify") {
                Button("Expand…") { session.promptSelectionAmount(.expand) }
                    .assignableShortcut("Select › Modify › Expand…")
                    .disabled(!session.canModifySelection)
                Button("Contract…") { session.promptSelectionAmount(.contract) }
                    .assignableShortcut("Select › Modify › Contract…")
                    .disabled(!session.canModifySelection)
                Button("Feather…") { session.promptSelectionAmount(.feather) }
                    .configuredKeyboardShortcut(KeyEquivalent(Character(ShortcutChord.functionKey(6))), modifiers: .shift)
                    .disabled(!session.canModifySelection)
            }
            Divider()
            // Each layer's transparency and each mask, as a new selection or added to or taken from this one.
            Button("Load Selection…") { session.beginLoadSelection() }
                .assignableShortcut("Select › Load Selection…")
                .disabled(!session.canLoadSelection)
        }
    }
}

/// Filter: Last Filter │ Camera Raw Filter… · Lens Correction… · Liquify… │ a submenu for each category with
/// Lamina's filters in it.
private struct FilterMenuCommands: Commands {
    let session: EditorSession

    var body: some Commands {
        CommandMenu("Filter") {
            Button(session.lastFilter.map { "Last Filter: " + $0.rawValue } ?? "Last Filter") {
                Task { await session.repeatLastFilter() }
            }
                .configuredKeyboardShortcut("f", modifiers: [.command, .control]).disabled(!session.canRepeatLastFilter)
            Divider()
            Button("Camera Raw Filter…") { session.beginFilter(.cameraRaw) }
                .configuredKeyboardShortcut("a", modifiers: [.command, .shift]).disabled(disabled(.cameraRaw))
            Button("Lens Correction…") { session.beginFilter(.lensCorrection) }
                .configuredKeyboardShortcut("r", modifiers: [.command, .shift]).disabled(disabled(.lensCorrection))
            // Not a dialog here: it picks the Liquify brush, whose bar ends with Cancel and Done.
            Button("Liquify…") { session.beginLiquify() }
                .configuredKeyboardShortcut("x", modifiers: [.command, .shift]).disabled(!session.canLiquify)
            Divider()
            ForEach(FilterKind.filterMenu, id: \.title) { submenu in
                Menu(submenu.title) {
                    ForEach(Array(submenu.kinds.enumerated()), id: \.offset) { _, kind in
                        if let kind {
                            Button("\(kind.rawValue)…") { session.beginFilter(kind) }
                                .assignableShortcut("Filter › \(submenu.title) › \(kind.rawValue)…")
                                .disabled(disabled(kind))
                        } else {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func disabled(_ kind: FilterKind) -> Bool {
        !(kind == .vignette ? session.canVignette : session.canAdjustColors) || session.hueSaturation != nil
    }
}

/// View: proofing │ zoom │ Screen Mode │ Extras · Show │ Rulers │ Snap · Snap To │ Guides │ Grid Settings…. Made as a
/// menu of its own, after Filter; the system's View menu, emptied, goes away.
private struct ViewMenuCommands: Commands {
    let applicationDelegate: LaminaApplicationDelegate
    let session: EditorSession
    private var noDocument: Bool { session.document == nil }

    var body: some Commands {
        CommandGroup(replacing: .toolbar) {}
        CommandGroup(replacing: .sidebar) {}
        CommandMenu("View") {
            Menu("Proof Setup") { PlannedMenuItem(feature: .proofSetup, session: session) }
            PlannedMenuItem(feature: .proofColors, session: session).configuredKeyboardShortcut("y")
            PlannedMenuItem(feature: .gamutWarning, session: session).configuredKeyboardShortcut("y", modifiers: [.command, .shift])
            Divider()
            // With a dialog's preview open (Export As), these zoom that preview rather than the canvas.
            Button("Zoom In") {
                guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                if let preview = session.previewZoom { preview(.zoomIn) } else { session.zoomKeyboard(by: 1) }
            }
                .configuredKeyboardShortcut("=").disabled(noDocument)
            Button("Zoom Out") {
                guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                if let preview = session.previewZoom { preview(.zoomOut) } else { session.zoomKeyboard(by: -1) }
            }
                .configuredKeyboardShortcut("-").disabled(noDocument)
            Button("Fit on Screen") {
                if let preview = session.previewZoom { preview(.fit) } else { session.fit() }
            }.configuredKeyboardShortcut("0").disabled(noDocument)
            Button("100%") {
                if let preview = session.previewZoom { preview(.actual) } else { session.zoom(to: 1) }
            }.configuredKeyboardShortcut("1").disabled(noDocument)
            Divider()
            // Standard is the only mode until TASK-78; F and Shift-F on the canvas say so too (`pressPlannedKey`).
            Menu("Screen Mode") {
                Toggle("Standard Screen Mode", isOn: .constant(true))
                    .assignableShortcut("View › Screen Mode › Standard Screen Mode")
                PlannedMenuItem(feature: .fullScreenModeWithMenuBar, session: session)
                PlannedMenuItem(feature: .fullScreenMode, session: session)
            }
            Divider()
            // Hides the grid, guides, pixel grid and selection edges together, each keeping its own setting.
            Toggle("Extras", isOn: Binding(get: { session.showsExtras }, set: { session.showsExtras = $0 }))
                .configuredKeyboardShortcut("h").disabled(noDocument)
            Menu("Show") {
                Toggle("Grid", isOn: Binding(get: { session.showsGrid }, set: { session.showsGrid = $0 }))
                    .configuredKeyboardShortcut("'").disabled(noDocument)
                Toggle("Guides", isOn: Binding(get: { session.showsGuides }, set: { session.showsGuides = $0 }))
                    .configuredKeyboardShortcut(";").disabled(noDocument)
                // From 800% up.
                Toggle("Pixel Grid", isOn: Binding(get: { session.showsPixelGrid }, set: { session.showsPixelGrid = $0 }))
                    .assignableShortcut("View › Show › Pixel Grid")
            }
            Divider()
            Toggle("Rulers", isOn: Binding(get: { session.showsRulers }, set: { session.showsRulers = $0 }))
                .configuredKeyboardShortcut("r").disabled(noDocument)
            Divider()
            Toggle("Snap", isOn: Binding(get: { session.snapEnabled }, set: { session.snapEnabled = $0 }))
                .configuredKeyboardShortcut(";", modifiers: [.command, .shift]).disabled(noDocument)
            Menu("Snap To") {
                Toggle("Guides", isOn: Binding(get: { session.snapToGuides }, set: { session.snapToGuides = $0 }))
                    .assignableShortcut("View › Snap To › Guides")
                    .disabled(noDocument)
                Toggle("Grid", isOn: Binding(get: { session.snapToGrid }, set: { session.snapToGrid = $0 }))
                    .assignableShortcut("View › Snap To › Grid")
                    .disabled(noDocument)
                Toggle("Layers", isOn: Binding(get: { session.snapToLayers }, set: { session.snapToLayers = $0 }))
                    .assignableShortcut("View › Snap To › Layers")
                    .disabled(noDocument)
                Toggle("Document Bounds", isOn: Binding(get: { session.snapToDocumentBounds },
                                                        set: { session.snapToDocumentBounds = $0 }))
                    .assignableShortcut("View › Snap To › Document Bounds")
                    .disabled(noDocument)
            }
            Divider()
            Menu("Guides") {
                Toggle("Lock Guides", isOn: Binding(get: { session.locksGuides }, set: { session.locksGuides = $0 }))
                    .configuredKeyboardShortcut(";", modifiers: [.command, .option]).disabled(noDocument)
                Button("Clear Guides") { session.clearGuides() }
                    .assignableShortcut("View › Guides › Clear Guides")
                    .disabled(!session.canClearGuides)
            }
            Divider()
            Button("Grid Settings…") { Task { await applicationDelegate.projects.gridSettings() } }
                .assignableShortcut("View › Grid Settings…")
                .disabled(noDocument)
            Divider()
            // AppKit's own View menu, which held this item, gives way to this one (MenuBarOrder). No ⌃⌘F: that's Last Filter.
            Button(FullScreenState.shared.isFullScreen ? "Exit Full Screen" : "Enter Full Screen") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
                .assignableShortcut("View › Enter Full Screen")
        }
    }
}

// MARK: The menus' layout, shared with Keyboard Shortcuts (`ShortcutDefinition.assignableMenuCommands`)

extension FilterKind {
    /// The Filter menu's category submenus in Photoshop's order, with Lamina's filters in each; nil is a separator.
    static let filterMenu: [(title: String, kinds: [FilterKind?])] = [
        ("Blur", [.gaussianBlur, .motionBlur]), ("Noise", [.addNoise]), ("Pixelate", [.dither]), ("Render", [.vignette]),
        ("Sharpen", [.unsharpMask, nil, .tonalContrast]), ("Stylize", [.bloomGlow]), ("Other", [.highPass]),
    ]
}

extension AdjustmentKind {
    /// Layer › New Adjustment Layer, in Photoshop's groups, Lamina's filter layers last.
    static let menuSections: [[AdjustmentKind]] = [
        [.grain], [.levels, .curves, .exposure], [.hsv, .colorBalance, .blackWhite], [.invert, .gradientMap],
        [.gaussianBlur, .motionBlur, .addNoise],
    ]
}

extension LayerAlignment {
    /// Layer › Align, in Photoshop's order.
    static let menuSections: [[LayerAlignment]] = [[.top, .verticalCenter, .bottom], [.left, .horizontalCenter, .right]]
}

extension LayerDistribution {
    /// Layer › Distribute, in Photoshop's order.
    static let menuSections: [[LayerDistribution]] = [[.verticalCenters, .horizontalCenters], [.horizontalSpacing, .verticalSpacing]]
    /// The menu's names: Photoshop calls the spacing ones Horizontally and Vertically.
    var menuTitle: String {
        switch self {
        case .horizontalSpacing: "Horizontally"
        case .verticalSpacing: "Vertically"
        case .horizontalCenters, .verticalCenters: rawValue
        }
    }
}
