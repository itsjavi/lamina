import SwiftUI
import AppKit
import ImageIO
import LaminaCore

/// What New Canvas's fields hold: a width and height in `unit`, and a resolution in pixels per inch, as typed.
struct NewCanvasSize: Equatable {
    var width = "1920"
    var height = "1080"
    var unit = SizeUnit.pixels
    var resolution = "72"
    /// The units a new canvas can be measured in: Percent has nothing to be a percentage of.
    static let units: [SizeUnit] = [.pixels, .inches, .centimeters, .millimeters]

    /// A typed number, with either decimal separator.
    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil }
    }
    /// Pixels per inch, when the field holds one in 1…9,600.
    var pixelsPerInch: Double? { Self.number(resolution).flatMap { (1...9600).contains($0) ? $0 : nil } }
    /// The pixels a field's text comes to: whole numbers in pixels, any positive size in a print unit.
    func pixels(_ text: String) -> Int? {
        guard let pixelsPerInch else { return nil }
        if unit == .pixels { return CanvasDocument.validDimension(text) }
        guard let value = Self.number(text), value > 0 else { return nil }
        let pixels = unit.pixels(value, resolution: pixelsPerInch).rounded()
        return (1...Double(DocumentLimits.maxSide)).contains(pixels) ? Int(pixels) : nil
    }
    var pixelWidth: Int? { pixels(width) }
    var pixelHeight: Int? { pixels(height) }
    var isValid: Bool { pixelWidth != nil && pixelHeight != nil }

    /// The same size shown in `newUnit`; a field that doesn't hold a size is left as it is.
    mutating func convert(to newUnit: SizeUnit) {
        guard newUnit != unit, let pixelsPerInch else { unit = newUnit; return }
        func converted(_ text: String) -> String {
            guard let value = Self.number(text), value > 0 else { return text }
            let pixels = unit.pixels(value, resolution: pixelsPerInch)
            if newUnit == .pixels { return String(Int(min(pixels.rounded(), Double(DocumentLimits.maxSide) * 1000))) }
            return newUnit.value(ofPixels: pixels, resolution: pixelsPerInch)
                .formatted(.number.precision(.fractionLength(0...3)).grouping(.never))
        }
        width = converted(width)
        height = converted(height)
        unit = newUnit
    }
}

struct NewCanvasSheet: View {
    let session: EditorSession
    var onCreate: (((width: Int, height: Int, resolution: Double)) -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    @State private var size = NewCanvasSize()
    @State private var suggestedClipboardSize = false
    @FocusState private var focusedField: Field?
    private enum Field { case width, height, resolution }
    private var valid: Bool { size.isValid }
    private var message: String {
        if size.pixelsPerInch == nil { return "Enter a resolution from 1 to 9,600 pixels/inch." }
        if size.unit == .pixels { return "Enter whole numbers from 1 to \(DocumentLimits.maxSide.formatted()) pixels." }
        return "Enter a size that comes to 1 to \(DocumentLimits.maxSide.formatted()) pixels on each side."
    }
    private var summary: String {
        guard size.unit != .pixels, let width = size.pixelWidth, let height = size.pixelHeight else { return "Transparent canvas · sRGB" }
        return "\(width) × \(height) px · Transparent canvas · sRGB"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 14) {
                HStack {
                    Text("New canvas").font(.title2.weight(.semibold))
                    Spacer()
                    // Preset sizes, tucked into a More button; the size in use is checked.
                    Menu {
                        Picker("Size", selection: preset) {
                            Text("Custom").tag(CanvasPreset?.none)
                            ForEach(CanvasPreset.groups.indices, id: \.self) { group in
                                Divider()
                                ForEach(CanvasPreset.groups[group]) { Text($0.title).tag(CanvasPreset?.some($0)) }
                            }
                        }
                        .pickerStyle(.inline).labelsHidden()
                    } label: {
                        // Three dots drawn exactly (a rotated symbol keeps its sideways width), flush with the fields'
                        // right edge; the frame keeps it easy to click.
                        VStack(spacing: 2.5) { ForEach(0..<3, id: \.self) { _ in Circle().frame(width: 2.5, height: 2.5) } }
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28, alignment: .trailing)
                            // Clickable a little past the dots on the right too, without moving them off the edge.
                            .padding(.trailing, 10)
                            .contentShape(Rectangle())
                            .padding(.trailing, -10)
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .help("Preset sizes for screens and common formats")
                    .accessibilityLabel("Preset sizes")
                }
            }
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    dimension("Width", text: $size.width, field: .width, suffix: size.unit.abbreviation)
                    Image(systemName: "multiply").foregroundStyle(.tertiary).padding(.top, 20)
                    dimension("Height", text: $size.height, field: .height, suffix: size.unit.abbreviation)
                }
                HStack(spacing: 16) {
                    unitMenu
                    // Keeps the columns lined up with the fields above.
                    Image(systemName: "multiply").hidden()
                    dimension("Resolution", text: $size.resolution, field: .resolution, suffix: "ppi")
                }
            }
            Text(valid ? summary : message)
                .font(.callout).foregroundStyle(valid ? Color.secondary : Color.orange)
            HStack(spacing: 10) {
                Button("Open project") { onOpen?() }.buttonStyle(.bordered)
                Button("Import image") { session.showsImporter = true }.buttonStyle(.bordered)
                Spacer()
                Button("Create canvas") {
                    guard let w = size.pixelWidth, let h = size.pixelHeight, let ppi = size.pixelsPerInch else { return }
                    if let onCreate { onCreate((w, h, ppi)) }
                    else { session.createDocument(width: w, height: h, emptyLayer: true, resolution: ppi) }
                }
                .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
                .disabled(!valid).accessibilityIdentifier("createCanvas")
            }
        }
        .padding(28).frame(maxWidth: 500)
        .disabled(session.isImporting || session.showsBusy)
        .onAppear {
            if !suggestedClipboardSize {
                suggestedClipboardSize = true
                if session.skipsInitialClipboardCanvasSize {
                    session.skipsInitialClipboardCanvasSize = false
                } else if let clipboard = Self.clipboardDimensions() {
                    size.unit = .pixels
                    size.width = String(clipboard.width)
                    size.height = String(clipboard.height)
                }
            }
            focusedField = .width
        }
        // Shown with the window, the view appears before the window sets up its first responder, which can take the
        // focus back; ask again once it has, so Width is ready to type over.
        .task {
            await Task.yield()
            if focusedField == nil { focusedField = .width }
        }
    }
    /// The preset the fields match, or nil (Custom); choosing one fills them in, in pixels.
    private var preset: Binding<CanvasPreset?> {
        Binding(get: { CanvasPreset.all.first { $0.width == size.pixelWidth && $0.height == size.pixelHeight } },
                set: {
                    guard let chosen = $0 else { return }
                    size.unit = .pixels
                    size.width = String(chosen.width)
                    size.height = String(chosen.height)
                })
    }
    /// Pixels, inches, centimeters or millimeters, for both sides; changing it converts what the fields hold.
    private var unitMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Units").font(.callout.weight(.medium))
            Menu {
                Picker("Units", selection: Binding(get: { size.unit }, set: { size.convert(to: $0) })) {
                    ForEach(NewCanvasSize.units) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline).labelsHidden()
            } label: {
                HStack {
                    Text(size.unit.rawValue).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).contentShape(Rectangle())
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
            .accessibilityLabel("Units")
        }
    }

    static func clipboardDimensions(_ pasteboard: NSPasteboard = .general) -> (width: Int, height: Int)? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            guard let data = pasteboard.data(forType: type),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  var width = properties[kCGImagePropertyPixelWidth] as? Int,
                  var height = properties[kCGImagePropertyPixelHeight] as? Int else { continue }
            if let orientation = properties[kCGImagePropertyOrientation] as? Int, (5...8).contains(orientation) {
                swap(&width, &height)
            }
            guard CanvasDocument.validDimension(String(width)) != nil,
                  CanvasDocument.validDimension(String(height)) != nil else { continue }
            return (width, height)
        }
        return nil
    }
    private func dimension(_ title: String, text: Binding<String>, field: Field, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.callout.weight(.medium))
            HStack {
                TextField(title, text: text).textFieldStyle(.plain)
                    .focused($focusedField, equals: field)
                    .accessibilityIdentifier(title.lowercased() + "Input")
                Text(suffix).foregroundStyle(.secondary)
            }
            .padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

/// New Canvas sizes: common screens and resolutions, in pixels, upright as the device is usually held.
struct CanvasPreset: Identifiable, Hashable {
    let title: String
    let width: Int
    let height: Int
    var id: String { title }
    /// Resolutions, Apple screens, then social formats; the menu divides them.
    static let groups: [[CanvasPreset]] = [
        [
            CanvasPreset(title: "4K", width: 3840, height: 2160),
            CanvasPreset(title: "1440p", width: 2560, height: 1440),
            CanvasPreset(title: "1080p", width: 1920, height: 1080),
        ],
        [
            CanvasPreset(title: "iPhone 18 Pro", width: 1206, height: 2622),
            CanvasPreset(title: "iPhone 18 Pro Max", width: 1320, height: 2868),
            CanvasPreset(title: "MacBook Pro 14\"", width: 3024, height: 1964),
            CanvasPreset(title: "MacBook Pro 16\"", width: 3456, height: 2234),
            CanvasPreset(title: "Studio Display", width: 5120, height: 2880),
        ],
        [
            CanvasPreset(title: "Instagram Square", width: 1080, height: 1080),
            CanvasPreset(title: "Instagram Portrait", width: 1080, height: 1350),
            CanvasPreset(title: "Instagram Story", width: 1080, height: 1920),
            CanvasPreset(title: "YouTube Thumb", width: 1080, height: 608),
        ],
    ]
    static let all = groups.flatMap { $0 }
}
