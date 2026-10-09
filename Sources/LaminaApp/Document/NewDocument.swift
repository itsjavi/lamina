import AppKit
import ImageIO
import LaminaCore

/// What New Document's Create asks for.
nonisolated struct NewDocumentRequest: Equatable, Sendable {
    var name: String
    var width: Int
    var height: Int
    var resolution: Double = 72
    /// The Background layer's color; nil for Transparent.
    var background: PaletteColor?
}

extension EditorSession {
    /// New Document's Create in this session (see `createNewProject(width:height:resolution:background:name:)`).
    func createNewProject(_ request: NewDocumentRequest) {
        createNewProject(width: request.width, height: request.height, resolution: request.resolution,
                         background: request.background, name: request.name)
    }
}

/// What New Document's Resolution is counted in.
nonisolated enum ResolutionUnit: String, CaseIterable, Identifiable, Sendable {
    case perInch = "Pixels/Inch", perCentimeter = "Pixels/Centimeter"
    var id: String { rawValue }
    /// Pixels per inch for `value` of this unit.
    func pixelsPerInch(_ value: Double) -> Double { self == .perInch ? value : value * 2.54 }
    /// `pixelsPerInch` in this unit.
    func value(ofPixelsPerInch pixelsPerInch: Double) -> Double { self == .perInch ? pixelsPerInch : pixelsPerInch / 2.54 }
}

/// New Document's Background Contents. Transparent is Lamina's default: the canvas starts with just a blank layer.
nonisolated enum BackgroundContents: String, CaseIterable, Identifiable, Sendable {
    case transparent = "Transparent", white = "White", black = "Black", backgroundColor = "Background Color"
    var id: String { rawValue }
    /// The color the Background layer is filled with (nil: no Background layer), `background` being the
    /// toolbar's background color.
    func color(background: PaletteColor) -> PaletteColor? {
        switch self {
        case .transparent: nil
        case .white: .white
        case .black: .black
        case .backgroundColor: background
        }
    }
}

/// What New Document's fields hold: a width and height in `unit`, and a resolution in `resolutionUnit`, as typed.
nonisolated struct NewCanvasSize: Equatable {
    var width = "1920"
    var height = "1080"
    var unit = SizeUnit.pixels
    var resolution = "72"
    var resolutionUnit = ResolutionUnit.perInch
    /// The resolution exactly, while the field still shows what switching its unit wrote, so going to pixels per
    /// centimeter and back keeps 300 at 300 rather than 299.999.
    private var convertedResolution: (text: String, pixelsPerInch: Double)?

    init(width: String = "1920", height: String = "1080", unit: SizeUnit = .pixels, resolution: String = "72",
         resolutionUnit: ResolutionUnit = .perInch) {
        self.width = width
        self.height = height
        self.unit = unit
        self.resolution = resolution
        self.resolutionUnit = resolutionUnit
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && lhs.unit == rhs.unit && lhs.resolution == rhs.resolution
            && lhs.resolutionUnit == rhs.resolutionUnit
    }

    /// The units a new document can be measured in: Percent has nothing to be a percentage of.
    static let units: [SizeUnit] = [.pixels, .inches, .centimeters, .millimeters]

    /// A typed number, with either decimal separator.
    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil }
    }
    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)).grouping(.never))
    }
    /// Pixels per inch, when the field holds a resolution that comes to 1…9,600 of them.
    var pixelsPerInch: Double? {
        if let convertedResolution, convertedResolution.text == resolution { return convertedResolution.pixelsPerInch }
        return Self.number(resolution).map(resolutionUnit.pixelsPerInch).flatMap { (1...9600).contains($0) ? $0 : nil }
    }
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
            return Self.text(newUnit.value(ofPixels: pixels, resolution: pixelsPerInch))
        }
        width = converted(width)
        height = converted(height)
        unit = newUnit
    }

    /// The same resolution shown in `newUnit`.
    mutating func convert(to newUnit: ResolutionUnit) {
        guard newUnit != resolutionUnit else { return }
        guard let pixelsPerInch else { resolutionUnit = newUnit; return }
        resolutionUnit = newUnit
        resolution = Self.text(newUnit.value(ofPixelsPerInch: pixelsPerInch))
        convertedResolution = (resolution, pixelsPerInch)
    }

    /// Taller than wide (Portrait), wider than tall (Landscape), or nil for a square or a size not filled in.
    var isPortrait: Bool? {
        guard let width = Self.number(width), let height = Self.number(height), width != height else { return nil }
        return height > width
    }
    /// Orientation's buttons: swaps the sides when the other orientation is chosen.
    mutating func setOrientation(portrait: Bool) {
        guard let current = isPortrait, current != portrait else { return }
        swap(&width, &height)
    }

    /// Fills the fields in from a preset, in its unit, keeping the resolution's unit.
    mutating func apply(_ preset: DocumentPreset) {
        unit = preset.unit
        width = Self.text(preset.width)
        height = Self.text(preset.height)
        resolution = Self.text(resolutionUnit.value(ofPixelsPerInch: preset.resolution))
        convertedResolution = resolutionUnit == .perInch ? nil : (resolution, preset.resolution)
    }

    /// Whether the fields come to `preset`, either way up: the same pixels, and for print sizes the same resolution.
    func matches(_ preset: DocumentPreset) -> Bool {
        guard let pixelWidth, let pixelHeight, let pixelsPerInch else { return false }
        let sides = [preset.pixelWidth, preset.pixelHeight]
        guard sides == [pixelWidth, pixelHeight] || sides == [pixelHeight, pixelWidth] else { return false }
        return preset.unit == .pixels || abs(pixelsPerInch - preset.resolution) < 0.01
    }

    /// The fields as a preset of their own, for Recent.
    func preset(titled title: String) -> DocumentPreset? {
        guard let pixelsPerInch, isValid, let width = Self.number(width), let height = Self.number(height) else { return nil }
        return DocumentPreset(title: title, width: width, height: height, unit: unit, resolution: pixelsPerInch)
    }
}

nonisolated extension SizeUnit: Codable {}

/// A New Document preset card: a size in a unit, at a resolution in pixels per inch.
nonisolated struct DocumentPreset: Identifiable, Hashable, Codable, Sendable {
    var title: String
    var width: Double
    var height: Double
    var unit: SizeUnit = .pixels
    var resolution: Double = 72
    var id: String { "\(title) \(width)×\(height) \(unit.rawValue) \(resolution)" }
    var pixelWidth: Int { Int(unit.pixels(width, resolution: resolution).rounded()) }
    var pixelHeight: Int { Int(unit.pixels(height, resolution: resolution).rounded()) }
    /// "1920 × 1080 px" or "8.5 × 11 in", as the card shows it.
    var sizeLabel: String { "\(NewCanvasSize.text(width)) × \(NewCanvasSize.text(height)) \(unit.abbreviation)" }
    /// The size with the resolution of a print size, "8.5 × 11 in · 300 ppi", for the card's help and VoiceOver.
    var fullLabel: String { unit == .pixels ? sizeLabel : "\(sizeLabel) · \(NewCanvasSize.text(resolution)) ppi" }

    static let defaultSize = DocumentPreset(title: "Default Lamina Size", width: 1920, height: 1080)

    /// The image on the clipboard, at its own size, if it holds one a document can be.
    @MainActor static func clipboard(_ pasteboard: NSPasteboard = .general) -> DocumentPreset? {
        clipboardDimensions(pasteboard).map { DocumentPreset(title: "Clipboard", width: Double($0.width), height: Double($0.height)) }
    }

    @MainActor static func clipboardDimensions(_ pasteboard: NSPasteboard = .general) -> (width: Int, height: Int)? {
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
}

/// New Document's preset tabs, in Photoshop's order (it has no Lamina-only ones).
nonisolated enum DocumentPresetCategory: String, CaseIterable, Identifiable, Sendable {
    case recent = "Recent", photo = "Photo", print = "Print", web = "Web", mobile = "Mobile", film = "Film & Video"
    var id: String { rawValue }

    /// The cards of every tab but Recent, upright as the format is usually used. Recent is made from what was last
    /// created (`RecentDocumentSizes.cards`).
    var presets: [DocumentPreset] {
        func inches(_ title: String, _ width: Double, _ height: Double) -> DocumentPreset {
            DocumentPreset(title: title, width: width, height: height, unit: .inches, resolution: 300)
        }
        func millimeters(_ title: String, _ width: Double, _ height: Double) -> DocumentPreset {
            DocumentPreset(title: title, width: width, height: height, unit: .millimeters, resolution: 300)
        }
        func pixels(_ title: String, _ width: Double, _ height: Double) -> DocumentPreset {
            DocumentPreset(title: title, width: width, height: height)
        }
        switch self {
        case .recent: return []
        case .photo:
            return [inches("Landscape 4 × 6", 6, 4), inches("Portrait 4 × 6", 4, 6), inches("Landscape 5 × 7", 7, 5),
                    inches("Portrait 5 × 7", 5, 7), inches("Landscape 8 × 10", 10, 8), inches("Portrait 8 × 10", 8, 10),
                    inches("Square 8 × 8", 8, 8)]
        case .print:
            return [inches("Letter", 8.5, 11), inches("Legal", 8.5, 14), inches("Tabloid", 11, 17),
                    millimeters("A3", 297, 420), millimeters("A4", 210, 297), millimeters("A5", 148, 210)]
        case .web:
            return [pixels("Web Most Common", 1366, 768), pixels("Web Medium", 1440, 900), pixels("Web Large", 1920, 1080),
                    pixels("Instagram Square", 1080, 1080), pixels("Instagram Portrait", 1080, 1350),
                    pixels("Instagram Story", 1080, 1920), pixels("YouTube Thumbnail", 1280, 720),
                    pixels("Open Graph Image", 1200, 630)]
        case .mobile:
            return [pixels("iPhone 18 Pro", 1206, 2622), pixels("iPhone 18 Pro Max", 1320, 2868),
                    pixels("iPad Pro 13\"", 2064, 2752), pixels("Android 1080p", 1080, 1920),
                    pixels("MacBook Pro 14\"", 3024, 1964), pixels("MacBook Pro 16\"", 3456, 2234),
                    pixels("Studio Display", 5120, 2880)]
        case .film:
            return [pixels("HDV/HDTV 720p", 1280, 720), pixels("HDTV 1080p", 1920, 1080), pixels("QHD 1440p", 2560, 1440),
                    pixels("DCI 2K", 2048, 1080), pixels("UHD 4K", 3840, 2160), pixels("DCI 4K", 4096, 2160),
                    pixels("UHD 8K", 7680, 4320)]
        }
    }
}

/// The sizes New Document last created, newest first, which its Recent tab lists after the clipboard's.
nonisolated enum RecentDocumentSizes {
    static let key = "newDocumentRecent"
    static let limit = 8

    static func load(from store: (any ToolDefaultsStore)? = ToolDefaults.store) -> [DocumentPreset] {
        guard let data = store?.object(forKey: key) as? Data,
              let saved = try? JSONDecoder().decode([DocumentPreset].self, from: data) else { return [] }
        return saved.filter { (1...DocumentLimits.maxSide).contains($0.pixelWidth) && (1...DocumentLimits.maxSide).contains($0.pixelHeight) }
    }

    /// Puts `preset` first, dropping an older card of the same size.
    static func record(_ preset: DocumentPreset, in store: (any ToolDefaultsStore)? = ToolDefaults.store) {
        let size = NewCanvasSize(width: NewCanvasSize.text(preset.width), height: NewCanvasSize.text(preset.height),
                                 unit: preset.unit, resolution: NewCanvasSize.text(preset.resolution))
        let others = load(from: store).filter { !size.matches($0) }
        guard let data = try? JSONEncoder().encode(Array(([preset] + others).prefix(limit))) else { return }
        store?.set(data, forKey: key)
    }

    /// Recent's cards: the clipboard's image, the sizes last created, then the default size if it isn't one of them.
    static func cards(clipboard: DocumentPreset?, from store: (any ToolDefaultsStore)? = ToolDefaults.store) -> [DocumentPreset] {
        var cards = (clipboard.map { [$0] } ?? []) + load(from: store)
        if !cards.contains(where: { $0.title != "Clipboard" && $0.pixelWidth == DocumentPreset.defaultSize.pixelWidth
            && $0.pixelHeight == DocumentPreset.defaultSize.pixelHeight }) {
            cards.append(.defaultSize)
        }
        return cards
    }
}
