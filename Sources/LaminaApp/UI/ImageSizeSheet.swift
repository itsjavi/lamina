import SwiftUI
import LaminaCore

struct ImageSizeSheet: View {
    let document: CanvasDocument
    let finish: (ImageSizeOptions?) -> Void
    @State private var width: Double
    @State private var height: Double
    @State private var resolution: Double
    /// The last usable resolution. Print sizes scale from it, so passing through a zero or negative entry
    /// doesn't lose them.
    @State private var lastResolution: Double
    @State private var locked = true
    @State private var resample = true
    @State private var unit = SizeUnit.pixels
    @State private var sampling: LayerSampling = .high

    init(document: CanvasDocument, finish: @escaping (ImageSizeOptions?) -> Void) {
        self.document = document
        self.finish = finish
        _width = State(initialValue: Double(document.width))
        _height = State(initialValue: Double(document.height))
        _resolution = State(initialValue: document.resolution)
        _lastResolution = State(initialValue: document.resolution)
    }

    private var valid: Bool {
        width.isFinite && height.isFinite && resolution.isFinite && (1...9600).contains(resolution)
            && (1...DocumentLimits.maxSideExtent).contains(width.rounded()) && (1...DocumentLimits.maxSideExtent).contains(height.rounded())
            && (!resample || width.rounded() * height.rounded() <= DocumentLimits.maxSurfaceExtent)
    }
    private func display(_ pixels: Double, original: Int) -> Double {
        unit.value(ofPixels: pixels, resolution: resolution, original: Double(original))
    }
    private func dimension(isWidth: Bool) -> Binding<Double> {
        Binding(get: { display(isWidth ? width : height, original: isWidth ? document.width : document.height) }, set: { value in
            guard value.isFinite, value > 0 else { return }
            if unit.isPrint, !(resolution.isFinite && resolution > 0) { return }
            if !resample {
                resolution = unit.resolution(printing: isWidth ? width : height, at: value)
                return
            }
            let pixels = unit.pixels(value, resolution: resolution, original: Double(isWidth ? document.width : document.height))
            if isWidth {
                if locked { height = pixels * height / width }
                width = pixels
            } else {
                if locked { width = pixels * width / height }
                height = pixels
            }
        })
    }

    private var canScrubDimensions: Bool {
        !unit.isPrint || (resolution.isFinite && resolution > 0)
    }

    private func scrubRange(isWidth: Bool) -> ClosedRange<Double> {
        guard canScrubDimensions else { return 0...0 }
        let pixels = isWidth ? width : height
        let other = isWidth ? height : width
        let original = Double(isWidth ? document.width : document.height)
        if !resample {
            return unit.value(ofPixels: pixels, resolution: 9600)...unit.value(ofPixels: pixels, resolution: 1)
        }
        let minimum = locked ? max(1, pixels / other) : 1.0
        let dimensionLimit = locked ? min(30_000, 30_000 * pixels / other) : 30_000.0
        let areaLimit = locked ? sqrt(100_000_000 * pixels / other) : 100_000_000 / other
        let maximum = max(minimum, min(dimensionLimit, areaLimit))
        func displayed(_ count: Double) -> Double { unit.value(ofPixels: count, resolution: resolution, original: original) }
        return displayed(minimum)...displayed(maximum)
    }

    private func scrubSensitivity(isWidth: Bool) -> Double {
        guard canScrubDimensions else { return 0 }
        // Without resampling, a step is what a pixel prints at 100 pixels/inch.
        if !resample { return unit.value(ofPixels: 1, resolution: 100) }
        return unit.value(ofPixels: 1, resolution: resolution, original: Double(isWidth ? document.width : document.height))
    }

    var body: some View { sheet.roundedControls() }

    private var unitPicker: some View {
        Picker("Units", selection: $unit) {
            ForEach(SizeUnit.allCases.filter { resample || $0.isPrint }) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden().frame(width: 120)
    }

    private func dimensionRow(_ name: String, isWidth: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name + ":").frame(width: Self.labelWidth, alignment: .trailing)
                .scrubbable(sensitivity: scrubSensitivity(isWidth: isWidth),
                            value: dimension(isWidth: isWidth), range: scrubRange(isWidth: isWidth), step: 1)
                .disabled(!canScrubDimensions)
            TextField(name, value: dimension(isWidth: isWidth), format: .number.precision(.fractionLength(0...3)))
                .frame(width: 80)
            unitPicker
        }
    }

    private static let labelWidth: CGFloat = 80

    private var sheet: some View {
        DialogLayout(placement: .bottom, title: "Image Size", defaultDisabled: !valid, confirm: {
            guard valid else { return }
            finish(ImageSizeOptions(width: Int(width.rounded()), height: Int(height.rounded()),
                resolution: resolution, sampling: sampling))
        }, cancel: { finish(nil) }) {
            VStack(alignment: .leading, spacing: 10) {
                DialogRow("Image Size:", labelWidth: Self.labelWidth) {
                    Text(valid ? ByteCountFormatter.string(fromByteCount: Int64(width.rounded()) * Int64(height.rounded()) * 4, countStyle: .memory) : "—")
                }
                DialogRow("Dimensions:", labelWidth: Self.labelWidth) {
                    Text(valid ? "\(Int(width.rounded())) px × \(Int(height.rounded())) px" : "—").monospacedDigit()
                    Text("was \(document.width) × \(document.height)").foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                dimensionRow("Width", isWidth: true)
                DialogRow("", labelWidth: Self.labelWidth) {
                    Toggle(isOn: $locked) { Image(systemName: "link") }
                        .toggleStyle(.button).disabled(!resample)
                        .help("Constrain aspect ratio")
                        .accessibilityLabel("Constrain aspect ratio")
                }
                dimensionRow("Height", isWidth: false)
                HStack(spacing: 8) {
                    Text("Resolution:").frame(width: Self.labelWidth, alignment: .trailing)
                        .scrubbable(sensitivity: 1, value: $resolution, range: 1...9600, step: 1)
                    TextField("Resolution", value: $resolution, format: .number.precision(.fractionLength(0...3)))
                        .frame(width: 80)
                        .onChange(of: resolution) { _, new in
                            guard new.isFinite, new > 0 else { return }
                            if resample, unit.isPrint {
                                width *= new / lastResolution
                                height *= new / lastResolution
                            }
                            lastResolution = new
                        }
                    Text("Pixels/Inch")
                }
                DialogRow("", labelWidth: Self.labelWidth) {
                    Toggle("Resample:", isOn: $resample).onChange(of: resample) { _, enabled in
                        if !enabled {
                            width = Double(document.width)
                            height = Double(document.height)
                            locked = true
                            if !unit.isPrint { unit = .inches }
                        }
                    }
                    Picker("Resample", selection: $sampling) {
                        ForEach(LayerSampling.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize().disabled(!resample)
                }
                // Lamina's own notes, after the familiar settings.
                Text(resample ? "Resizes layer pixels and applies existing transforms. Undo restores the originals."
                              : "Only print dimensions and resolution change. Pixels stay unchanged.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !valid {
                    Text("Use 1–\(DocumentLimits.maxSide.formatted()) pixels per side, up to \(DocumentLimits.maxSurfaceMegapixels) megapixels, and 1–9,600 pixels/inch.")
                        .foregroundStyle(.orange).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(width: 380, alignment: .leading)
        }
    }
}
