import SwiftUI

/// File › Export JPEG… and Export As…: the flattened canvas as it will be saved, with the format's settings.
struct ExportSheet: View {
    let raster: ExportRaster
    let session: EditorSession
    /// The formats to choose from: just JPEG for Export JPEG…, every one this Mac can write for Export As….
    let formats: [ExportFormat]
    let finish: ((format: ExportFormat, data: Data)?) -> Void
    @State private var options: ExportOptions
    /// The format Export As… last exported, which it starts from next time.
    private static let formatKey = "exportAsFormat"

    init(raster: ExportRaster, session: EditorSession, formats: [ExportFormat],
         finish: @escaping ((format: ExportFormat, data: Data)?) -> Void) {
        self.raster = raster
        self.session = session
        self.formats = formats
        self.finish = finish
        var start = ExportOptions(format: formats.first ?? .jpeg)
        if formats.count > 1, let saved = UserDefaults.standard.string(forKey: Self.formatKey),
           let format = ExportFormat(rawValue: saved), formats.contains(format) {
            start.format = format
        }
        start.quality = Self.savedQuality(start.format)
        _options = State(initialValue: start)
    }

    /// The quality of the last export in a format, which the next one in it starts from.
    private static func qualityKey(_ format: ExportFormat) -> String {
        format == .jpeg ? "jpegExportQuality" : "\(format.rawValue)ExportQuality"
    }
    private static func savedQuality(_ format: ExportFormat) -> Double {
        guard let saved = UserDefaults.standard.object(forKey: qualityKey(format)) as? Double, saved.isFinite else {
            return ExportOptions.defaultQuality
        }
        return min(1, max(0, saved))
    }
    /// Qualities set in this sheet for formats it has left, so switching back keeps them.
    @State private var qualities: [ExportFormat: Double] = [:]
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

    var body: some View { sheet.roundedControls() }
    @ViewBuilder private var sheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Export \(options.format.title)").font(.title2.bold())
                Spacer()
                Button("Fit") { zoom = nil }.disabled(zoom == nil)
                    .help("Show the whole image (⌘0)")
                Button { zoomBy(1) } label: { Image(systemName: "plus.magnifyingglass") }
                    .disabled(ExportPreview.step(from: shownZoom, in: 1) == nil)
                    .help("Zoom in (⌘+), now \(percent). At 100% each pixel of the \(options.format.title) is one pixel of the screen, as on the canvas")
                Button { zoomBy(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                    .disabled(ExportPreview.step(from: shownZoom, in: -1) == nil)
                    .help("Zoom out (⌘−), now \(percent)")
            }
            // Closer to the title row than the rest of the dialog's spacing.
            .padding(.bottom, -8)
            ZStack {
                Color(white: 0.12)
                if let result {
                    ExportPreview(image: result.preview, pixelWidth: raster.image.width, pixelHeight: raster.image.height, zoom: $zoom)
                }
                if readyOptions != options && error == nil {
                    ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }.frame(width: ExportPreview.frame.width, height: ExportPreview.frame.height).clipped()
                .help("Drag or scroll to move around; double-click switches between Fit and 100%")
            if formats.count > 1 {
                Picker("Format", selection: $options.format) {
                    ForEach(formats) { Text($0.title).tag($0) }
                }.fixedSize()
            }
            // The same rows for every format, disabled or reworded where they don't apply, so the sheet keeps its size.
            HStack {
                Text("Quality").foregroundStyle(options.format.hasQuality ? .primary : .secondary)
                Slider(value: options.format.hasQuality ? $options.quality : .constant(1), in: 0...1, step: 0.01)
                Text(options.format.hasQuality ? "\(Int((options.quality * 100).rounded()))%" : "Lossless")
                    .monospacedDigit().frame(width: 60, alignment: .trailing)
            }.disabled(!options.format.hasQuality)
            HStack(spacing: 8) {
                if options.format.keepsTransparency {
                    Text("Transparent areas stay transparent").foregroundStyle(.secondary)
                } else {
                    Text("Background for transparency")
                    DialogColorSwatch(title: "\(options.format.title) Background", color: matte, session: session)
                        .help("Color that fills transparent areas")
                }
            }.frame(minHeight: 18)
            HStack(spacing: 12) {
                Text("\(raster.image.width.formatted()) × \(raster.image.height.formatted()) px · sRGB")
                    .foregroundStyle(.secondary)
                Spacer()
                if let error { Text(error).foregroundStyle(.red) }
                else if readyOptions == options, let result {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(result.data.count), countStyle: .file)).monospacedDigit()
                } else { Text("Updating…").foregroundStyle(.secondary) }
                Button("Cancel") { DialogColorSwatch.closePicker(session); finish(nil) }.configuredNativeShortcut(.escape)
                Button("Export…") {
                    DialogColorSwatch.closePicker(session)
                    if options.format.hasQuality { UserDefaults.standard.set(options.quality, forKey: Self.qualityKey(options.format)) }
                    if formats.count > 1 { UserDefaults.standard.set(options.format.rawValue, forKey: Self.formatKey) }
                    finish(result.map { (options.format, $0.data) })
                }
                    .configuredNativeShortcut(.return)
                    .disabled(result == nil || readyOptions != options || error != nil)
            }
        }
        .padding(24)
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
            qualities[old] = options.quality
            options.quality = qualities[new] ?? Self.savedQuality(new)
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
    static let frame = CGSize(width: 560, height: 330)
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
