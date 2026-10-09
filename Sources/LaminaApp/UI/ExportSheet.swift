import SwiftUI
import LaminaCore

/// File › Export › Export As… (docs/DESIGN.md, Dialogs): the flattened canvas as it will be saved, with its size and
/// the file's, and the chosen format's settings. Export goes on to the Save panel.
struct ExportSheet: View {
    let raster: ExportRaster
    let session: EditorSession
    /// Every format this Mac can write.
    let formats: [ExportFormat]
    let finish: ((options: ExportOptions, data: Data)?) -> Void
    @State private var options: ExportOptions

    init(raster: ExportRaster, session: EditorSession, formats: [ExportFormat],
         finish: @escaping ((options: ExportOptions, data: Data)?) -> Void) {
        self.raster = raster
        self.session = session
        self.formats = formats
        self.finish = finish
        _options = State(initialValue: ExportSettings.options(for: ExportSettings.format(among: formats)))
    }

    static let settingsWidth: CGFloat = 250
    private static let labelWidth: CGFloat = 60

    /// Settings changed in this dialog for formats it has left, so switching back keeps them.
    @State private var chosen: [ExportFormat: ExportOptions] = [:]
    @State private var result: ExportResult?
    /// The preview's zoom, 1 being 100%; nil fits the whole image.
    @State private var zoom: Double?
    @Environment(\.displayScale) private var displayScale
    /// The zoom shown now, Fit's included.
    private var shownZoom: Double {
        zoom ?? ExportPreview.fitZoom(width: raster.image.width, height: raster.image.height,
                                      in: ExportPreview.frame, displayScale: displayScale)
    }
    @State private var readyOptions: ExportOptions?
    @State private var error: String?
    private var ready: Bool { result != nil && readyOptions == options && error == nil }

    var body: some View { sheet.roundedControls() }
    private var sheet: some View {
        DialogLayout(placement: .bottom, title: "Export As", defaultTitle: "Export", defaultDisabled: !ready,
                     confirm: confirm, cancel: { DialogColorSwatch.closePicker(session); finish(nil) }) {
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 8) {
                    previewFrame
                    zoomControls
                    sizeLine
                }
                .frame(width: ExportPreview.frame.width)
                fileSettings.frame(width: Self.settingsWidth)
            }
        }
        .onAppear { session.previewZoom = { command in
            switch command {
            case .zoomIn: zoomBy(1)
            case .zoomOut: zoomBy(-1)
            case .fit: zoom = nil
            case .actual: zoom = 1
            }
        } }
        .onDisappear { session.previewZoom = nil }
        .onChange(of: options.format) { old, new in
            var left = options
            left.format = old
            chosen[old] = left
            var next = chosen[new] ?? ExportSettings.options(for: new)
            // The matte is one color for every format.
            (next.red, next.green, next.blue) = (options.red, options.green, options.blue)
            options = next
        }
        .task(id: options) {
            let requested = options
            error = nil
            do {
                try await Task.sleep(for: .milliseconds(200))
                let encoded = try await ImageExporter.shared.encode(raster, options: requested)
                try Task.checkCancellation()
                result = encoded
                readyOptions = requested
            } catch is CancellationError {
                // A newer setting superseded this preview.
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
    }

    private var previewFrame: some View {
        ZStack {
            ColorRole.pasteboard.color
            if let result {
                ExportPreview(image: result.preview, pixelWidth: raster.image.width, pixelHeight: raster.image.height, zoom: $zoom)
            }
            if readyOptions != options && error == nil {
                ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: ExportPreview.frame.width, height: ExportPreview.frame.height).clipped()
        .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
        .help("Drag or scroll to move around; double-click switches between Fit and 100%")
        .accessibilityLabel("Export preview")
    }

    /// Zoom out, the percentage and zoom in, as under a filter's preview, then Fit.
    private var zoomControls: some View {
        HStack(spacing: 12) {
            Button { zoomBy(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(ExportPreview.step(from: shownZoom, in: -1) == nil)
                .help("Zoom out (⌘−)").accessibilityLabel("Zoom out")
            Text(percent).monospacedDigit().frame(minWidth: 52).accessibilityLabel("Preview zoom")
            Button { zoomBy(1) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(ExportPreview.step(from: shownZoom, in: 1) == nil)
                .help("Zoom in (⌘+). At 100% each pixel of the \(options.format.title) is one pixel of the screen, as on the canvas")
                .accessibilityLabel("Zoom in")
            Button("Fit") { zoom = nil }.disabled(zoom == nil).help("Show the whole image (⌘0)")
        }
        .buttonStyle(.borderless)
    }

    /// The image's size and, once it's encoded, the file's.
    private var sizeLine: some View {
        HStack(spacing: 0) {
            Text("\(raster.image.width.formatted()) × \(raster.image.height.formatted()) px · ")
            if let error { Text(error).foregroundStyle(.red) }
            else if ready, let result {
                Text(ByteCountFormatter.string(fromByteCount: Int64(result.data.count), countStyle: .file))
            } else { Text("Updating…") }
        }
        .monospacedDigit().foregroundStyle(ColorRole.secondaryText.color)
        .lineLimit(1)
    }

    /// The same rows for every format, dimmed where they don't apply, so the dialog keeps its size.
    private var fileSettings: some View {
        DialogGroup("File Settings") {
            DialogRow("Format:", labelWidth: Self.labelWidth) {
                Picker("Format", selection: $options.format) {
                    ForEach(formats) { Text($0.title).tag($0) }
                }
                .labelsHidden().fixedSize()
                Spacer(minLength: 0)
            }
            DialogRow("Quality:", labelWidth: Self.labelWidth) {
                Slider(value: options.format.hasQuality ? $options.quality : .constant(1), in: 0...1, step: 0.01)
                    .accessibilityLabel("Quality")
                if options.format.hasQuality {
                    TextField("Quality", value: qualityPercent, format: .number).frame(width: 40)
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    Text("%")
                } else {
                    Text("Lossless").frame(width: 52, alignment: .trailing)
                }
            }
            .disabled(!options.format.hasQuality)
            DialogRow("", labelWidth: Self.labelWidth) {
                Toggle("Transparency", isOn: options.format.keepsTransparency ? $options.transparency : .constant(false))
                    .help(options.format.keepsTransparency ? "Keep transparent areas transparent"
                                                           : "\(options.format.title) has no transparency")
                Spacer(minLength: 0)
            }
            .disabled(!options.format.keepsTransparency)
            DialogRow("Matte:", labelWidth: Self.labelWidth) {
                DialogColorSwatch(title: "Matte", color: matte, session: session)
                    .help("Background for transparency: the color that fills transparent areas")
                Spacer(minLength: 0)
            }
            .disabled(!options.fillsTransparency)
        }
    }

    private func confirm() {
        guard ready, let result else { return }
        DialogColorSwatch.closePicker(session)
        ExportSettings.save(options)
        finish((options, result.data))
    }

    private var qualityPercent: Binding<Int> {
        Binding(get: { Int((options.quality * 100).rounded()) },
                set: { options.quality = Double(min(100, max(0, $0))) / 100 })
    }
    private var percent: String { "\(Int((shownZoom * 100).rounded()))%" }
    private func zoomBy(_ direction: Int) {
        if let next = ExportPreview.step(from: shownZoom, in: direction) { zoom = next }
    }
    private var matte: Binding<PaletteColor> {
        Binding(get: { PaletteColor(red: options.red, green: options.green, blue: options.blue) },
                set: { options.red = $0.red; options.green = $0.green; options.blue = $0.blue })
    }
}

/// The encoded image, fitted or zoomed (1 is 100%: one image pixel per screen pixel, as the canvas counts it), where it
/// can be dragged or scrolled around. Double-click switches between Fit and 100%.
struct ExportPreview: View {
    static let frame = CGSize(width: 520, height: 330)
    static let steps: [Double] = [0.25, 0.5, 1, 2, 4, 8]
    let image: CGImage
    /// The exported image's size, which the preview may have been decoded smaller than.
    let pixelWidth: Int
    let pixelHeight: Int
    @Binding var zoom: Double?
    @Environment(\.displayScale) private var displayScale
    @State private var position = ScrollPosition()
    @State private var offset = CGPoint.zero
    @State private var dragStart: CGPoint?

    /// The zoom at which the whole image fits `frame`.
    static func fitZoom(width: Int, height: Int, in frame: CGSize, displayScale: CGFloat) -> Double {
        let points = CGSize(width: CGFloat(width) / max(1, displayScale), height: CGFloat(height) / max(1, displayScale))
        return Double(min(frame.width / points.width, frame.height / points.height))
    }
    /// The next zoom step past `zoom` in `direction` (1 in, −1 out), or nil at the end.
    static func step(from zoom: Double, in direction: Int) -> Double? {
        direction > 0 ? steps.first { $0 > zoom * 1.001 } : steps.last { $0 < zoom * 0.999 }
    }

    var body: some View {
        GeometryReader { geometry in
            if let zoom {
                let size = shownSize(zoom)
                ScrollView([.horizontal, .vertical]) {
                    // Nearest-neighbor from 100% up, so each pixel of the export and its artifacts shows as it is.
                    Image(decorative: image, scale: 1).resizable().interpolation(zoom >= 1 ? .none : .high)
                        .frame(width: size.width, height: size.height)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                }
                .scrollIndicators(.visible)
                .scrollPosition($position)
                .onScrollGeometryChange(for: CGPoint.self, of: { $0.contentOffset }) { _, new in offset = new }
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        let start = dragStart ?? offset
                        dragStart = start
                        position.scrollTo(point: CGPoint(x: start.x - drag.translation.width, y: start.y - drag.translation.height))
                    }
                    .onEnded { _ in dragStart = nil })
                .onTapGesture(count: 2) { self.zoom = nil }
                .onAppear { keepCentered(from: nil, to: zoom, in: geometry.size) }
                .onChange(of: zoom) { old, new in keepCentered(from: old, to: new, in: geometry.size) }
                .pointerStyle(dragStart == nil ? .grabIdle : .grabActive)
            } else {
                Image(decorative: image, scale: 1).resizable().interpolation(.high).scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { self.zoom = 1 }
            }
        }
    }

    /// The image's size on screen at `zoom`, in points.
    private func shownSize(_ zoom: Double) -> CGSize {
        CGSize(width: CGFloat(pixelWidth) / max(1, displayScale) * zoom, height: CGFloat(pixelHeight) / max(1, displayScale) * zoom)
    }

    /// Zooming keeps the middle of the view on the same part of the image; coming from Fit, it starts at the center.
    private func keepCentered(from old: Double?, to new: Double?, in view: CGSize) {
        guard let new else { return }
        let size = shownSize(new)
        var middle = CGPoint(x: size.width / 2, y: size.height / 2)
        if let old {
            let before = shownSize(old)
            let fx = before.width > 0 ? (offset.x + min(view.width, before.width) / 2) / before.width : 0.5
            let fy = before.height > 0 ? (offset.y + min(view.height, before.height) / 2) / before.height : 0.5
            middle = CGPoint(x: fx * size.width, y: fy * size.height)
        }
        position.scrollTo(point: CGPoint(x: min(max(0, middle.x - view.width / 2), max(0, size.width - view.width)),
                                         y: min(max(0, middle.y - view.height / 2), max(0, size.height - view.height))))
    }
}
