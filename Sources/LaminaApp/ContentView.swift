import SwiftUI
import UniformTypeIdentifiers
import LaminaCore

struct ContentView: View {
    @Bindable var session: EditorSession
    var applicationDelegate: LaminaApplicationDelegate? = nil
    @Environment(\.openWindow) private var openWindow
    @State private var canvasFrame: CGRect = .zero
    @State private var levelsPanel = FloatingPanelController(name: "levelsPanel")
    @State private var adjustmentPanel = FloatingPanelController(name: "adjustmentPanel")
    @State private var selectionAmountPanel = FloatingPanelController(name: "selectionAmountPanel")
    @State private var colorRangePanel = FloatingPanelController(name: "colorRangePanel")
    @State private var filterPanel = FloatingPanelController(name: "filterPanel")
    @State private var layerStylePanel = FloatingPanelController(name: "layerStylePanel")
    /// Edit › Fill… and Select › Load Selection….
    @State private var commandDialogPanel = FloatingPanelController(name: "commandDialogPanel")
    @State private var isDropTargeted = false
    /// The dock's widths, split and open panels, shared with the Window menu.
    private let dockLayout = DockLayout.shared
    /// The window's width, so the tab strip can use the toolbar's free space.
    @State private var windowWidth: CGFloat = 1180
    /// A layer dragged from this canvas's own tab has nowhere to go, so the canvas doesn't light up for it.
    private var acceptsDrop: Bool {
        guard let workspace = applicationDelegate?.workspace else { return true }
        return workspace.canReceiveDrag(into: workspace.current.id)
    }
    // Extracted from `body`: as one expression the type checker times out (Xcode 26.1).
    /// The active tool's settings, which the options bar shows after the tool's icon.
    @ViewBuilder private var toolHeaders: some View {
        Group {
            // A Free Transform waiting for Commit or Cancel turns the Move bar into the Free Transform bar; a drag
            // that applies itself when let go (a move, a nudge) leaves the Move bar in place.
            if session.tool == .move, session.transformEdit?.persistent == true {
                FreeTransformBar(session: session).id(session.activeLayerID)
            } else if session.tool == .move {
                MoveToolBar(session: session)
            }
            if session.tool.isBrushTool {
                BrushControls(session: session)
            }
            if session.tool.isSelectionTool {
                LassoControls(session: session)
            }
            if session.tool == .gradient {
                GradientControls(session: session)
            }
            if session.tool == .paintBucket {
                PaintBucketControls(session: session)
            }
            if session.tool == .type {
                TypeControls(session: session)
            }
            if session.tool.shapeKind != nil {
                ShapeControls(session: session)
            }
            if session.tool == .eyedropper {
                OptionsBarRow {
                    Toggle("Show Sampling Ring", isOn: $session.showsSampleRing).toggleStyle(.checkbox)
                        .help("Show a ring of the color under the pointer and the one before it while sampling")
                }
            }
            if session.tool == .hand || session.tool == .zoom {
                NavigationToolHeader(session: session)
            }
            if session.tool == .crop {
                CropControls(session: session)
            }
            // No tool (A) keeps the bar, its icon and nothing after it, so the canvas doesn't jump.
            if session.tool == .idle {
                Spacer().toolHeaderBar()
            }
        }
    }

    @ViewBuilder private var editorStack: some View {
        VStack(spacing: 0) {
            OptionsBar(session: session) { toolHeaders }
            Divider()
            HStack(spacing: 0) {
                ToolbarColumn(session: session)
                Divider()
                VStack(spacing: 0) {
                    if session.showsRulers, session.document != nil {
                        HStack(spacing: 0) {
                            CanvasRulerCorner()
                            CanvasRulerView(session: session, axis: .horizontal)
                                .frame(height: CanvasRuler.thickness)
                        }
                    }
                    HStack(spacing: 0) {
                        if session.showsRulers, session.document != nil {
                            CanvasRulerView(session: session, axis: .vertical)
                                .frame(width: CanvasRuler.thickness)
                        }
                        ZStack {
                            EditorCanvas(session: session)
                            if session.document == nil { welcome }
                            if let layer = session.maskAloneLayer {
                                // At the foot of the canvas, clear of the transform box's rotation handle.
                                MaskAloneBadge(session: session, layer: layer).fixedSize()
                                    .padding(.bottom, 14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            }
                            InProgressNoticeView(session: session)
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("editor")) } action: { canvasFrame = $0 }
                    }
                    // Under the canvas only, as in a document window: the tools and panels run to the window's foot.
                    Divider()
                    // Keeps its own height however short the window gets; the tools scroll instead.
                    statusBar.fixedSize(horizontal: false, vertical: true)
                }
                .modifier(HistoryFlyout(session: session, layout: dockLayout))
                Divider()
                DockArea(session: session, layout: dockLayout, projects: applicationDelegate?.projects)
            }
        }
        .modifier(WidthReader(width: $windowWidth))
    }

    // Split again for 1.1: the chain outgrew the type checker once more.
    @ViewBuilder private var editorChrome: some View {
        editorStack
        .background(ColorRole.chrome.color)
        .background {
            if let applicationDelegate, applicationDelegate.projects.workspace == nil {
                ProjectWindowBridge(controller: applicationDelegate.projects).frame(width: 0, height: 0)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .coordinateSpace(name: "editor")
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier, ProjectWorkspace.layerType], isTargeted: $isDropTargeted) { providers, location in
            guard session.levels == nil, !session.isProjectBusy, !session.showsNewDocument, !session.showsImporter, session.renamingLayerID == nil else { return false }
            let point: CGPoint?
            if let document = session.document, canvasFrame.contains(location) {
                point = session.viewport.documentPoint(
                    from: CGPoint(x: location.x - canvasFrame.minX, y: location.y - canvasFrame.minY),
                    documentSize: document.size)
            } else { point = nil }
            if let workspace = applicationDelegate?.workspace {
                let destination = workspace.current.id
                guard workspace.canSwitch, workspace.canReceiveDrag(into: destination) else { return false }
                Task { await workspace.receiveProviders(providers, into: destination, at: point) }
            } else {
                Task { await ImageFileDrop.importProviders(providers, into: session, at: point) }
            }
            return true
        }
        .overlay {
            if isDropTargeted, acceptsDrop {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 3)
                    .frame(width: max(0, canvasFrame.width - 6), height: max(0, canvasFrame.height - 6))
                    .position(x: canvasFrame.midX, y: canvasFrame.midY)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { applicationDelegate?.showEditor = { openWindow(id: "editor") } }
        .navigationTitle(session.documentName)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { requestNewCanvas() } label: { Label("New Document", systemImage: "plus") }
                    .help("New Document (⌘N)").accessibilityIdentifier("newCanvasToolbar")
                    .disabled(session.isImporting || session.showsBusy || session.levels != nil)
                    .modifier(NewProjectDropTarget(workspace: applicationDelegate?.workspace))
            }
            ToolbarSpacer(.fixed, placement: .navigation)
            if let workspace = applicationDelegate?.workspace {
                ToolbarItem(placement: .navigation) {
                    ProjectTabStrip(workspace: workspace)
                        // As wide as the title bar allows: the window less the traffic lights and New button before
                        // it. Bounded, so adding tabs never pushes New aside; crowded tabs narrow, then overflow.
                        .frame(width: max(200, windowWidth - ProjectTabStrip.titleBarInset), height: 34, alignment: .center)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            ToolbarSpacer(.flexible, placement: .navigation)
        }
    }

    var body: some View {
        editorChrome
        .onChange(of: session.levels == nil) { _, closed in
            if closed { levelsPanel.close() }
            else {
                levelsPanel.onClose = { session.cancelLevels() }
                levelsPanel.show(title: "Levels", content: LevelsSheet(session: session))
            }
        }
        .onChange(of: session.colorRange == nil) { _, closed in
            if closed { colorRangePanel.close() }
            else {
                colorRangePanel.onClose = { session.cancelColorRange() }
                colorRangePanel.show(title: "Color Range", content: ColorRangeSheet(session: session))
            }
        }
        .onChange(of: session.hueSaturation == nil) { _, closed in
            if closed { adjustmentPanel.close() }
            else {
                adjustmentPanel.onClose = { session.cancelHueSaturation() }
                adjustmentPanel.show(title: "Hue/Saturation", content: HueSaturationSheet(session: session))
            }
        }
        .onChange(of: session.layerStyle == nil) { _, closed in
            if closed { layerStylePanel.close() }
            else {
                layerStylePanel.onClose = { session.finishLayerStyle(commit: false) }
                layerStylePanel.show(title: "Layer Style", content: LayerStyleDialog(session: session))
            }
        }
        .onChange(of: session.selectionAmountOperation) { _, operation in
            if let operation {
                selectionAmountPanel.onClose = { session.selectionAmountOperation = nil }
                selectionAmountPanel.show(title: operation.rawValue + " Selection",
                    content: SelectionAmountSheet(session: session, operation: operation))
            } else { selectionAmountPanel.close() }
        }
        .onChange(of: session.commandDialog) { _, dialog in
            switch dialog {
            case .fill:
                commandDialogPanel.onClose = { Task { await session.finishFill(nil) } }
                commandDialogPanel.show(title: "Fill", content: FillSheet(session: session))
            case .loadSelection:
                guard let channel = session.defaultSelectionChannel else { session.commandDialog = nil; return }
                commandDialogPanel.onClose = { session.finishLoadSelection(nil) }
                commandDialogPanel.show(title: "Load Selection",
                    content: LoadSelectionSheet(session: session, channels: session.selectionChannels, initial: channel))
            case nil: commandDialogPanel.close()
            }
        }
        // Last Filter applies without the panel.
        .onChange(of: session.filterEdit == nil || session.filterEdit?.repeating == true) { _, closed in
            if closed { filterPanel.close() }
            else {
                filterPanel.onClose = { session.cancelFilter() }
                let placement: FloatingPanelPlacement = session.filterEdit?.kind == .cameraRaw ? .dockedToMainWindowRight : .automatic
                filterPanel.show(title: session.filterEdit?.kind.rawValue ?? "Filter", content: FilterSheet(session: session),
                                 placement: placement)
            }
        }
        .onChange(of: session.document == nil) { _, empty in
            if !empty { session.canvasFocusRequest += 1 }
        }
        .fileImporter(isPresented: $session.showsImporter,
                      allowedContentTypes: UTType.importableImages, allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await session.importImages(urls) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { session.importError = error.localizedDescription }
            }
        }
        .alert("Import couldn’t finish", isPresented: Binding(
            get: { session.importError != nil }, set: { if !$0 { session.importError = nil } })) {
                // No cancel role: an alert with only a cancel button gets a second OK of its own.
                Button("OK") { session.importError = nil }
            } message: { Text(session.importError ?? "") }
        .alert("Couldn’t paint", isPresented: Binding(get: { session.brushError != nil },
            set: { if !$0 { session.brushError = nil } })) {
                Button("OK") { session.brushError = nil }
            } message: { Text(session.brushError ?? "") }
        .alert("Couldn’t crop", isPresented: Binding(get: { session.cropError != nil },
            set: { if !$0 { session.cropError = nil } })) {
                Button("OK") { session.cropError = nil }
            } message: { Text(session.cropError ?? "") }
    }
    private func requestNewCanvas() {
        if let applicationDelegate { Task { await applicationDelegate.projects.newCanvas() } }
        else { session.clearProject() }
    }
    /// The empty window's New Document, centered on the pasteboard and scrolling when the window is too small for it.
    private var welcome: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                NewDocumentView(session: session, presentation: .welcome,
                    defaultName: applicationDelegate?.workspace.current.title ?? session.documentName,
                    create: { session.createNewProject($0) },
                    open: { Task { await applicationDelegate?.projects.open() } })
                    .padding(20)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
            .scrollIndicators(.automatic)
        }
    }
    private var statusBar: some View {
        HStack(spacing: 14) {
            if let document = session.document {
                ZoomField(session: session).fixedSize()
                Text(document.sizeDescription).foregroundStyle(ColorRole.text.color).fixedSize()
                    .accessibilityIdentifier("canvasDimensions")
            } else { Text("Ready when you are") }
            Spacer(minLength: 12)
            if session.showsBusy {
                ProgressView().controlSize(.mini)
                Text("Working…")
            } else if session.isImporting {
                ProgressView().controlSize(.mini)
                Text("Importing images…")
            } else {
                Text(session.tool.hint)
            }
        }
        // The hints give way first: one line, cut off at the end, while the zoom and size keep their width.
        .lineLimit(1)
        .font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
        .padding(.horizontal, 8).frame(height: StatusBarStyle.height)
        .accessibilityElement(children: .contain)
    }
}

extension View {
    /// Bordered buttons and pop-up menus drawn as capsules throughout the app. Borderless and plain buttons (the tool
    /// rail, the Layers panel footer) have no border to shape, so they're unaffected.
    func roundedControls() -> some View { buttonBorderShape(.capsule) }
}

extension View {
    /// Return or Escape in a property field gives up its focus and hands it back to the canvas, so a tool's key
    /// works straight away instead of typing into the field.
    func releasesFocusOnCommit(_ session: EditorSession) -> some View {
        onSubmit { session.canvasFocusRequest += 1 }
            .onExitCommand { session.canvasFocusRequest += 1 }
    }
}

/// What a field's key monitor reads. The monitor outlives the view value that installed it, so reading the value
/// and applying the step go through here, refreshed on every redraw.
@MainActor final class ArrowStepper {
    var editing = false
    var value: () -> Double = { 0 }
    var change: (Double) -> Void = { _ in }
    private var monitor: Any?

    /// Takes Up and Down while the field holds focus: one step, or ten with Shift.
    func listen(step: Double) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only while a field really is being edited: a field left behind (its tool bar swapped out, say) must not
            // keep taking Up and Down from the canvas, where they nudge the layer.
            guard let self, self.editing, event.keyCode == 126 || event.keyCode == 125,
                  NSApp.keyWindow?.firstResponder is NSTextView else { return event }
            let amount = step * (event.modifierFlags.contains(.shift) ? 10 : 1)
            self.change(self.value() + (event.keyCode == 126 ? amount : -amount))
            return nil
        }
    }
    func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        editing = false
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

/// Up and Down nudge the value in a focused property field, Shift by ten times as much — a text field takes the
/// arrow keys for its insertion point, so they are caught while it holds focus.
private struct ArrowStepping: ViewModifier {
    let step: Double
    let value: () -> Double
    let change: (Double) -> Void
    @FocusState private var focused: Bool
    @State private var stepper = ArrowStepper()
    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: focused) { _, editing in
                stepper.editing = editing
                editing ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
            .onAppear { refresh() }
            .onChange(of: value()) { _, _ in refresh() }
    }
    private func refresh() {
        stepper.value = value
        stepper.change = change
    }
}

extension View {
    /// Up and Down step this field's value; each field's own binding keeps it in range.
    func arrowSteps(_ step: Double = 1, value: @escaping () -> Double, change: @escaping (Double) -> Void) -> some View {
        modifier(ArrowStepping(step: step, value: value, change: change))
    }
    /// The same, for a field that already owns its focus: it says when it is being edited.
    func arrowSteps(_ step: Double = 1, editing: Bool, stepper: ArrowStepper,
                    value: @escaping () -> Double, change: @escaping (Double) -> Void) -> some View {
        onAppear { stepper.value = value; stepper.change = change }
            .onChange(of: value()) { _, _ in stepper.value = value; stepper.change = change }
            .onChange(of: editing) { _, active in
                stepper.editing = active
                stepper.value = value
                stepper.change = change
                active ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
    }
}

/// Reports the width it is laid out at. Kept out of the editor's body, whose type-checking is already near its limit.
private struct WidthReader: ViewModifier {
    @Binding var width: CGFloat
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
