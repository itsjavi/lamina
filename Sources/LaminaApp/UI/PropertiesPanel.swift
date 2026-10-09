import SwiftUI
import LaminaCore

/// The Properties panel: the settings of whatever is selected, in the dock's top group (docs/DESIGN.md, Dock and
/// panels ▸ Properties). A title row names the selection; collapsible sections follow, scrolling when they don't fit,
/// and adjustment layers and masks end with a footer of actions.
struct PropertiesPanel: View {
    @Bindable var session: EditorSession
    /// The document's own controller, for the Canvas fields and the quick actions that open a dialog.
    var projects: ProjectController? = nil

    var body: some View {
        let kind = session.propertiesKind
        if kind == .none {
            DockEmptyState(symbol: "slider.horizontal.3", title: "No properties", message: "Create or open a document.")
        } else {
            VStack(spacing: 0) {
                PropertiesTitle(kind: kind)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { sections(kind) }
                        // Fields, and the state they hold while typed in, belong to one selection.
                        .id(session.activeLayerID)
                }
                footer(kind)
            }
            // No foreground style of its own: controls keep the system's, dimmed when they're disabled.
            .font(.system(size: 12)).monospacedDigit()
            .releasesFocusOnCommit(session)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("propertiesPanel")
        }
    }

    @ViewBuilder private func sections(_ kind: PropertiesKind) -> some View {
        switch kind {
        case .none: EmptyView()
        case .document: DocumentProperties(session: session, projects: projects)
        case .pixel, .shape:
            TransformProperties(session: session)
            AlignProperties(session: session)
            InterpolationProperties(session: session)
            PropertiesSection("Quick Actions") {
                PropertiesButtonGrid {
                    Button("Remove Background") { session.beginFilter(.removeBackground) }
                        .disabled(!session.canAdjustColors || session.hueSaturation != nil)
                        .help("Hide the background behind a layer mask (Filter ▸ Remove Background…)")
                    Button("Select Subject") { Task { await session.selectSubject() } }
                        .disabled(!session.canSelectSubject)
                        .help("Select the main subjects of the layer (Select ▸ Subject)")
                }
            }
        case .type:
            TransformProperties(session: session)
            CharacterProperties(session: session)
            ParagraphProperties(session: session)
        case .group, .layers:
            TransformProperties(session: session)
            AlignProperties(session: session)
        case .adjustment:
            if let layer = session.activeLayer, layer.adjustment != nil {
                AdjustmentProperties(session: session, layerID: layer.id)
            }
        case .mask:
            MaskProperties(session: session)
        }
    }

    @ViewBuilder private func footer(_ kind: PropertiesKind) -> some View {
        switch kind {
        case .adjustment:
            if let id = session.activeLayerID { AdjustmentFooter(session: session, layerID: id) }
        case .mask:
            MaskFooter(session: session)
        default: EmptyView()
        }
    }
}

/// The panel's first row: the selection's kind, its icon and its name.
struct PropertiesTitle: View {
    let kind: PropertiesKind

    var body: some View {
        HStack(spacing: 7) {
            // Curves' symbol turned a quarter, as the Layers panel shows it, so it reads as a curve.
            Image(systemName: kind.symbol).font(.system(size: 15))
                .rotationEffect(.degrees(kind == .adjustment(.curves) ? 90 : 0))
                .foregroundStyle(ColorRole.icon.color).frame(width: 18)
                .accessibilityHidden(true)
            Text(kind.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).frame(height: 32)
        .overlay(alignment: .bottom) { ColorRole.separator.color.frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("propertiesTitle")
    }
}

/// A section of the panel, with a heading that folds it away. Which sections are folded is remembered for every
/// selection alike, as familiar editors do.
struct PropertiesSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    private let sections = PropertiesSections.shared

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let expanded = !sections.collapsed.contains(title)
        VStack(alignment: .leading, spacing: 7) {
            Button { sections.toggle(title) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(ColorRole.secondaryText.color)
                    Text(title).font(.system(size: 11.5, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isHeader)
            if expanded { content }
        }
        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { ColorRole.separator.color.frame(height: 1) }
    }
}

/// The folded sections, by heading, saved for next time.
@MainActor @Observable final class PropertiesSections {
    static let shared = PropertiesSections()
    private(set) var collapsed = Set(ToolDefaults.string("propertiesCollapsed", "").split(separator: "\n").map(String.init))

    func toggle(_ title: String) {
        if collapsed.remove(title) == nil { collapsed.insert(title) }
        ToolDefaults.set(collapsed.sorted().joined(separator: "\n"), "propertiesCollapsed")
    }
}

/// Buttons two to a row, each as wide as its column: the quick actions.
struct PropertiesButtonGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], alignment: .leading, spacing: 6) {
            content.frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PropertiesButtonStyle())
    }
}

/// A quick action's button: the label on a `control` plate, full width of its column.
struct PropertiesButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1).minimumScaleFactor(0.85)
            .padding(.horizontal, 8).frame(maxWidth: .infinity).frame(height: 24)
            .background(configuration.isPressed ? ColorRole.activeTool.color : ColorRole.control.color,
                        in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(isEnabled ? ColorRole.text.color : ColorRole.tertiaryText.color)
            .contentShape(Rectangle())
    }
}

/// The footer of an adjustment layer or a mask: icon buttons at the right, 15 pt.
struct PropertiesFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            content
        }
        .padding(.horizontal, 6).frame(height: 30)
        .overlay(alignment: .top) { ColorRole.separator.color.frame(height: 1) }
    }
}

/// One of the footer's buttons: its symbol, with the name as help tag and accessibility label.
struct PropertiesFooterButton: View {
    let title: String
    let symbol: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15))
                .frame(width: 26, height: 24)
                .background(isOn ? ColorRole.activeTool.color : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? ColorRole.text.color : ColorRole.icon.color)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A number applied once the field is done with it (Return, Tab, a click elsewhere), for values that take a moment
/// to apply, such as the canvas size: typing doesn't resize the canvas at every digit.
struct PropertiesCommitField: View {
    let label: String
    let value: Double
    var suffix: String? = nil
    var decimals = 0
    var width: CGFloat = 58
    let commit: (Double) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(ColorRole.secondaryText.color).fixedSize()
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder).frame(width: width).focused($focused)
                .accessibilityLabel(label)
                .onAppear { sync() }
                .onChange(of: value) { if !focused { sync() } }
                .onChange(of: focused) { if !focused { apply() } }
            if let suffix { Text(suffix).foregroundStyle(ColorRole.secondaryText.color).fixedSize() }
        }
    }

    private func sync() { text = Self.formatted(value, decimals: decimals) }
    private func apply() {
        let typed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(typed), number.isFinite,
              Self.formatted(number, decimals: decimals) != Self.formatted(value, decimals: decimals) else { sync(); return }
        commit(number)
    }
    static func formatted(_ value: Double, decimals: Int) -> String {
        decimals == 0 ? NumberLabel.whole(value) : NumberLabel.upToTwoDecimals(value)
    }
}

// MARK: Document

/// Nothing selected: the canvas's size and resolution, what the rulers measure in and which guides show, and the
/// actions people reach for on a whole image.
private struct DocumentProperties: View {
    @Bindable var session: EditorSession
    let projects: ProjectController?
    @State private var linked = false

    var body: some View {
        if let document = session.document {
            let units = session.rulerUnits
            let resolution = document.resolution
            PropertiesSection("Canvas") {
                HStack(spacing: 6) {
                    PropertiesCommitField(label: "W", value: units.value(ofPixels: Double(document.width), resolution: resolution),
                                          suffix: units.abbreviation, decimals: units == .pixels ? 0 : 2) { resize(width: $0) }
                    Toggle(isOn: $linked) { Image(systemName: "link") }
                        .toggleStyle(.button).buttonStyle(.borderless)
                        .help("Keep the canvas's proportions").accessibilityLabel("Constrain Proportions")
                    PropertiesCommitField(label: "H", value: units.value(ofPixels: Double(document.height), resolution: resolution),
                                          suffix: units.abbreviation, decimals: units == .pixels ? 0 : 2) { resize(height: $0) }
                }
                .help("The canvas size, changed around its center as Image ▸ Canvas Size… changes it")
                HStack(spacing: 6) {
                    PropertiesCommitField(label: "Resolution", value: resolution, suffix: "Pixels/Inch", decimals: 2) { value in
                        guard (1...9600).contains(value) else { return }
                        Task { await projects?.changeResolution(value) }
                    }
                    .help("Pixels per inch, without resampling, as Image ▸ Image Size… does with Resample off")
                }
            }
            .disabled(projects == nil || !session.canEditLayers)
            PropertiesSection("Rulers & Grids") {
                HStack(spacing: 6) {
                    Text("Units").foregroundStyle(ColorRole.secondaryText.color)
                    Picker("Units", selection: $session.rulerUnits) {
                        ForEach(SizeUnit.rulerUnits) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                    .help("What the rulers and the canvas size measure in")
                }
                HStack(spacing: 12) {
                    Toggle("Grid", isOn: $session.showsGrid)
                    Toggle("Guides", isOn: $session.showsGuides)
                    Toggle("Rulers", isOn: $session.showsRulers)
                }
                .toggleStyle(.checkbox)
            }
            PropertiesSection("Quick Actions") {
                PropertiesButtonGrid {
                    Button("Image Size") { Task { await projects?.imageSize() } }
                        .disabled(projects == nil || !session.canStartProjectOperation)
                        .help("Image ▸ Image Size…")
                    Button("Crop") { session.selectTool(.crop) }
                        .help("The Crop Tool (C)")
                    Button("Trim") { Task { await projects?.trim() } }
                        .disabled(projects == nil || !session.canStartProjectOperation)
                        .help("Image ▸ Trim…")
                    Menu {
                        ForEach(CanvasRotation.allCases, id: \.self) { rotation in
                            Button(rotation.rawValue) { Task { await session.rotateCanvas(rotation) } }
                        }
                    } label: { Text("Rotate") } primaryAction: { Task { await session.rotateCanvas(.clockwise) } }
                        .menuStyle(.button).menuIndicator(.hidden)
                        .disabled(!session.canEditLayers)
                        .help("Rotate the canvas 90° clockwise. Hold for the other rotations (Image ▸ Image Rotation).")
                }
            }
        }
    }

    private func pixels(_ value: Double) -> Int? {
        guard let document = session.document else { return nil }
        let result = session.rulerUnits.pixels(value, resolution: document.resolution).rounded()
        guard result.isFinite, (1...Double(DocumentLimits.maxSide)).contains(result) else { return nil }
        return Int(result)
    }
    private func resize(width: Double) {
        guard let document = session.document, let width = pixels(width) else { return }
        let height = linked ? max(1, Int((Double(document.height) * Double(width) / Double(document.width)).rounded())) : document.height
        Task { await projects?.resizeCanvas(width: width, height: height) }
    }
    private func resize(height: Double) {
        guard let document = session.document, let height = pixels(height) else { return }
        let width = linked ? max(1, Int((Double(document.width) * Double(height) / Double(document.height)).rounded())) : document.width
        Task { await projects?.resizeCanvas(width: width, height: height) }
    }
}

// MARK: Layers

/// Where the selection sits: W and H (its box's own size, in pixels), X and Y (the top left of its bounds), its angle
/// and flips. Changes go through the Move tool's transform, so a Free Transform in progress takes them as part of it,
/// and otherwise each field applies as one undo step once it is done.
private struct TransformProperties: View {
    @Bindable var session: EditorSession

    private var value: LayerTransform? { session.activeLayer.map(session.editedTransform(for:)) }
    /// Fields edit while something can be transformed, or while a transform is open; a distortion is edited by its
    /// corners instead.
    private var editable: Bool {
        (session.transformEdit != nil || session.canTransform) && session.transformEdit?.corners == nil
    }

    var body: some View {
        let value = value ?? LayerTransform(origin: .zero, size: CGSize(width: 1, height: 1))
        let bounds = EditorSession.bounds(of: value)
        let finish = session.finishTransformValues
        PropertiesSection("Transform") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TransformValueField(label: "W", suffix: "px", value: value.size.width, range: 1...30_000, finish: finish) {
                        session.changeTransform(.width, to: $0)
                    }
                    Toggle(isOn: $session.locksTransformRatio) { Image(systemName: "link") }
                        .toggleStyle(.button).buttonStyle(.borderless)
                        .help("Maintain aspect ratio").accessibilityLabel("Maintain Aspect Ratio")
                    TransformValueField(label: "H", suffix: "px", value: value.size.height, range: 1...30_000, finish: finish) {
                        session.changeTransform(.height, to: $0)
                    }
                }
                HStack(spacing: 6) {
                    TransformValueField(label: "X", suffix: "px", value: bounds.minX, range: -30_000...30_000, finish: finish) {
                        session.changeTransform(.x, to: $0)
                    }
                    Spacer().frame(width: 22)
                    TransformValueField(label: "Y", suffix: "px", value: bounds.minY, range: -30_000...30_000, finish: finish) {
                        session.changeTransform(.y, to: $0)
                    }
                }
                HStack(spacing: 6) {
                    TransformValueField(label: "Angle", symbol: "angle", suffix: "°", value: value.rotation, range: -360...360, finish: finish) {
                        session.changeTransform(.angle, to: $0)
                    }
                    Spacer(minLength: 0)
                    OptionsBarIconButton(title: "Flip Horizontal", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                        session.flipTransform(horizontally: true)
                    }
                    .disabled(!session.canFlipTransform)
                    OptionsBarIconButton(title: "Flip Vertical", symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down") {
                        session.flipTransform(horizontally: false)
                    }
                    .disabled(!session.canFlipTransform)
                }
            }
            .disabled(!editable)
        }
    }
}

/// Lining the selection up: with one layer, against the canvas (or a selection); with several, against their bounds.
/// Distributing takes three or more.
private struct AlignProperties: View {
    @Bindable var session: EditorSession

    var body: some View {
        PropertiesSection("Align and Distribute") {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(MoveToolBar.horizontalAlignments + MoveToolBar.verticalAlignments, id: \.self) { alignment in
                        OptionsBarIconButton(title: "Align " + alignment.rawValue, symbol: alignment.symbol) { session.alignLayers(alignment) }
                    }
                }
                .disabled(!session.canAlignLayers)
                HStack(spacing: 2) {
                    ForEach(LayerDistribution.allCases, id: \.self) { distribution in
                        OptionsBarIconButton(title: "Distribute " + distribution.rawValue, symbol: distribution.symbol) {
                            session.distributeLayers(distribution)
                        }
                    }
                }
                .disabled(!session.canDistributeLayers)
            }
        }
    }
}

/// Lamina's per-layer sampling, by the names familiar editors give resampling.
private struct InterpolationProperties: View {
    @Bindable var session: EditorSession

    var body: some View {
        let sampling = session.activeLayer.map(session.editedTransform(for:))?.sampling ?? .high
        PropertiesSection("Layer") {
            HStack(spacing: 6) {
                Text("Interpolation").foregroundStyle(ColorRole.secondaryText.color)
                Picker("Interpolation", selection: Binding(get: { sampling }, set: { session.changeInterpolation($0) })) {
                    ForEach(LayerSampling.allCases, id: \.self) { Text($0.interpolationName).tag($0) }
                }
                .labelsHidden().fixedSize()
                .help("How the pixels are resampled where the layer is drawn larger, smaller or turned")
            }
            .disabled((session.transformEdit == nil && !session.canTransform) || session.transformEdit?.corners != nil)
        }
    }
}

// MARK: Layer mask

/// A targeted mask: refining it from the image's colors, or turning it over.
private struct MaskProperties: View {
    @Bindable var session: EditorSession

    var body: some View {
        PropertiesSection("Masks") {
            HStack(spacing: 6) {
                Text("Refine").foregroundStyle(ColorRole.secondaryText.color)
                Button("Color Range…") { session.beginColorRange(forMask: true) }
                    .disabled(!session.canSelectColorRange)
                    .help("Make the mask from the image's colors (Select ▸ Color Range…, aimed at the mask)")
                Button("Invert") { Task { await session.invertPixels() } }
                    .disabled(!session.canInvert)
                    .help("Turn the mask over: what it hid shows, and what showed is hidden")
            }
            .buttonStyle(PropertiesButtonStyle())
        }
    }
}

private struct MaskFooter: View {
    @Bindable var session: EditorSession

    var body: some View {
        PropertiesFooter {
            PropertiesFooterButton(title: "Load Selection from Mask", symbol: "rectangle.dashed") {
                if let id = session.activeLayerID { session.loadMaskSelection(layerID: id) }
            }
            .disabled(!session.canEditSelection)
            PropertiesFooterButton(title: "Apply Mask", symbol: "checkmark.rectangle") { session.applyLayerMask() }
                .disabled(!session.canApplyLayerMask)
            PropertiesFooterButton(title: "Delete Mask", symbol: "trash") { session.deleteLayerMask() }
                .disabled(!session.canEditMask)
        }
    }
}

/// A panel with nothing to show: an icon and a line, centered, in the style of the Layers and History panels' own.
struct DockEmptyState: View {
    let symbol: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 25, weight: .light))
            Text(title).font(.callout.weight(.medium))
            if let message { Text(message).font(.caption).multilineTextAlignment(.center) }
        }
        .foregroundStyle(.secondary).padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
