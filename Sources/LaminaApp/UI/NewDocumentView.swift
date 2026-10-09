import SwiftUI
import AppKit
import LaminaCore

/// File › New… (a sheet) and the empty window's welcome, laid out as Photoshop's New Document: preset tabs and
/// cards on the left, Preset Details on the right, the buttons at the bottom right.
struct NewDocumentView: View {
    enum Presentation { case dialog, welcome }
    let session: EditorSession
    let presentation: Presentation
    /// The name the document gets unless another is typed.
    let defaultName: String
    let create: (NewDocumentRequest) -> Void
    /// The dialog's Close.
    var close: () -> Void = {}
    /// The welcome's Open….
    var open: () -> Void = {}

    static let cardSize = CGSize(width: 140, height: 104)
    static let detailsWidth: CGFloat = 240
    private static let cardSpacing: CGFloat = 10
    private static let columns = 4
    private static var gridWidth: CGFloat { cardSize.width * CGFloat(columns) + cardSpacing * CGFloat(columns - 1) }

    @State private var size = NewCanvasSize()
    @State private var name = ""
    @State private var category = DocumentPresetCategory.recent
    @State private var background = BackgroundContents.transparent
    @State private var clipboard: DocumentPreset?
    @State private var recent: [DocumentPreset] = []
    @State private var started = false
    @FocusState private var focusedField: Field?
    private enum Field { case name, width, height, resolution }

    private var cards: [DocumentPreset] { category == .recent ? recent : category.presets }
    private var selectedCard: DocumentPreset? { cards.first { size.matches($0) } }
    private var fillColor: PaletteColor? { background.color(background: session.backgroundColor) }
    private var request: NewDocumentRequest? {
        guard message == nil, let width = size.pixelWidth, let height = size.pixelHeight, let resolution = size.pixelsPerInch else { return nil }
        return NewDocumentRequest(name: name, width: width, height: height, resolution: resolution, background: fillColor)
    }
    /// Why Create is dimmed, or nil when it isn't.
    private var message: String? {
        if size.pixelsPerInch == nil {
            return size.resolutionUnit == .perInch ? "Enter a resolution from 1 to 9,600 pixels/inch."
                : "Enter a resolution from 0.4 to 3,779.5 pixels/centimeter."
        }
        guard let width = size.pixelWidth, let height = size.pixelHeight else {
            if size.unit == .pixels { return "Enter whole numbers from 1 to \(DocumentLimits.maxSide.formatted()) pixels." }
            return "Enter a size that comes to 1 to \(DocumentLimits.maxSide.formatted()) pixels on each side."
        }
        if background != .transparent, width * height > DocumentLimits.maxSurfacePixels {
            return "A filled background can be up to \(DocumentLimits.maxSurfaceMegapixels) megapixels. Choose Transparent for a larger canvas."
        }
        return nil
    }

    var body: some View {
        Group {
            switch presentation {
            case .dialog:
                DialogLayout(placement: .bottom, title: "New Document", defaultTitle: "Create", cancelTitle: "Close",
                             defaultDisabled: request == nil, confirm: confirm, cancel: close) { content }
            case .welcome:
                welcome
            }
        }
        .disabled(session.isImporting || session.showsBusy)
        .onAppear(perform: start)
        // Shown with the window, the view appears before the window sets up its first responder, which can take the
        // focus back; ask again once it has, so Width is ready to type over.
        .task {
            await Task.yield()
            if focusedField == nil { focusedField = .width }
        }
        .onChange(of: session.newDocumentFocusRequest) { focusedField = .width }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshCards()
        }
    }

    /// The empty window's New Document: the dialog's layout with Open… and Import Image… where Close would be,
    /// as there's nothing to close.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Document").font(.headline)
            content
            HStack(spacing: 10) {
                Button("Open…", action: open)
                Button("Import Image…") { session.showsImporter = true }
                Spacer(minLength: 0)
                Button(action: confirm) { Text("Create").frame(minWidth: 64) }
                    .buttonStyle(.borderedProminent).configuredNativeShortcut(.return)
                    .disabled(request == nil).accessibilityIdentifier("createCanvas")
            }
        }
        .padding(20)
        .fixedSize()
        .background(ColorRole.window.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ColorRole.edge.color) }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Presets", selection: $category) {
                    ForEach(DocumentPresetCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .frame(width: Self.gridWidth)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cardSize.width), spacing: Self.cardSpacing),
                                             count: Self.columns), alignment: .leading, spacing: Self.cardSpacing) {
                        ForEach(cards) { card($0) }
                    }
                }
                .scrollIndicators(.automatic)
                .frame(height: Self.cardSize.height * 3 + Self.cardSpacing * 2)
            }
            .frame(width: Self.gridWidth)
            Divider()
            details.frame(width: Self.detailsWidth, alignment: .leading)
        }
    }

    private func card(_ preset: DocumentPreset) -> some View {
        let selected = selectedCard == preset
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Button { choose(preset) } label: {
            VStack(alignment: .leading, spacing: 3) {
                PresetShape(preset: preset).frame(maxWidth: .infinity).frame(height: 46)
                Text(preset.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(preset.sizeLabel).font(.system(size: 11)).foregroundStyle(ColorRole.secondaryText.color).lineLimit(1)
            }
            .padding(10)
            .frame(width: Self.cardSize.width, height: Self.cardSize.height, alignment: .topLeading)
            .background(selected ? ColorRole.selection.color : ColorRole.field.color, in: shape)
            .overlay { shape.strokeBorder(selected ? Color.accentColor : ColorRole.separator.color, lineWidth: selected ? 2 : 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help("\(preset.title), \(preset.fullLabel)")
        .accessibilityLabel("\(preset.title), \(preset.fullLabel)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRESET DETAILS").font(.system(size: 11, weight: .medium)).kerning(0.6)
                .foregroundStyle(ColorRole.secondaryText.color)
            TextField("Name", text: $name).textFieldStyle(.plain).font(.system(size: 16, weight: .semibold))
                .focused($focusedField, equals: .name)
                .padding(.bottom, 6)
                .accessibilityLabel("Name")
            Text("Width")
            HStack(spacing: 8) {
                field("Width", text: $size.width, focus: .width)
                Picker("Units", selection: Binding(get: { size.unit }, set: { size.convert(to: $0) })) {
                    ForEach(NewCanvasSize.units) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
            }
            Text("Height")
            HStack(spacing: 8) {
                field("Height", text: $size.height, focus: .height)
                Text("Orientation").foregroundStyle(ColorRole.secondaryText.color)
                Spacer(minLength: 0)
                orientation(portrait: true)
                orientation(portrait: false)
            }
            Text("Resolution")
            HStack(spacing: 8) {
                field("Resolution", text: $size.resolution, focus: .resolution)
                Picker("Resolution Units", selection: Binding(get: { size.resolutionUnit }, set: { size.convert(to: $0) })) {
                    ForEach(ResolutionUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
            }
            Text("Background Contents")
            HStack(spacing: 8) {
                Picker("Background Contents", selection: $background) {
                    ForEach(BackgroundContents.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                backgroundSwatch
            }
            Text(message ?? summary)
                .font(.callout).foregroundStyle(message == nil ? ColorRole.secondaryText.color : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var summary: String {
        guard let width = size.pixelWidth, let height = size.pixelHeight else { return " " }
        return "\(width.formatted()) × \(height.formatted()) px · sRGB"
    }

    /// What the Background layer is filled with: the checkerboard alone for Transparent.
    private var backgroundSwatch: some View {
        let color = fillColor.map(\.swiftUI) ?? .clear
        return GradientSwatch(colors: [color, color])
            .frame(width: 22, height: 22)
            .help(background == .backgroundColor ? "The toolbar's background color" : background.rawValue)
    }

    private func field(_ title: String, text: Binding<String>, focus: Field) -> some View {
        TextField(title, text: text).frame(width: 96)
            .focused($focusedField, equals: focus)
            .accessibilityLabel(title)
            .accessibilityIdentifier(title.lowercased() + "Input")
    }

    private func orientation(portrait: Bool) -> some View {
        let on = size.isPortrait == portrait
        return Button { size.setOrientation(portrait: portrait) } label: {
            Image(systemName: portrait ? "rectangle.portrait" : "rectangle")
                .frame(width: 22, height: 20)
                .background(on ? ColorRole.activeTool.color : .clear, in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(portrait ? "Portrait" : "Landscape")
        .accessibilityLabel(portrait ? "Portrait" : "Landscape")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func choose(_ preset: DocumentPreset) {
        size.apply(preset)
    }

    private func refreshCards() {
        clipboard = DocumentPreset.clipboard()
        recent = RecentDocumentSizes.cards(clipboard: clipboard)
    }

    /// Fills the details in once: the clipboard's image size when there is one (except in the first window at
    /// launch, which opens on what was last created), otherwise the size last created, or the default.
    private func start() {
        guard !started else { return }
        started = true
        name = defaultName
        refreshCards()
        let skipsClipboard = session.skipsInitialClipboardCanvasSize
        session.skipsInitialClipboardCanvasSize = false
        if let clipboard, !skipsClipboard { size.apply(clipboard) }
        else if let last = recent.first(where: { $0.title != "Clipboard" }) { size.apply(last) }
        focusedField = .width
    }

    private func confirm() {
        guard let request else { return }
        let title = selectedCard.flatMap { $0.title == "Clipboard" ? nil : $0.title } ?? "Custom"
        if let preset = size.preset(titled: title) { RecentDocumentSizes.record(preset) }
        create(request)
    }
}

/// A preset card's picture: its shape, as wide and tall as the format.
private struct PresetShape: View {
    let preset: DocumentPreset
    var body: some View {
        let width = max(1, Double(preset.pixelWidth)), height = max(1, Double(preset.pixelHeight))
        let scale = min(56 / width, 40 / height)
        Group {
            if preset.title == "Clipboard" {
                Image(systemName: "doc.on.clipboard").font(.system(size: 26, weight: .light))
            } else {
                RoundedRectangle(cornerRadius: 2).strokeBorder(lineWidth: 1.5)
                    .frame(width: max(8, width * scale), height: max(8, height * scale))
            }
        }
        .foregroundStyle(ColorRole.icon.color)
    }
}
