import SwiftUI

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
    @ViewBuilder private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Image Size").font(.title2.bold())
            Text("Current: \(document.width) × \(document.height) pixels").foregroundStyle(.secondary)
            Picker("Units", selection: $unit) {
                ForEach(SizeUnit.allCases.filter { resample || $0.isPrint }) { Text($0.rawValue).tag($0) }
            }
            HStack {
                Text("Width").frame(width: 75, alignment: .leading)
                    .scrubbable(sensitivity: scrubSensitivity(isWidth: true),
                                value: dimension(isWidth: true), range: scrubRange(isWidth: true), step: 1)
                    .disabled(!canScrubDimensions)
                TextField("Width", value: dimension(isWidth: true), format: .number.precision(.fractionLength(0...3)))
            }
            HStack {
                Text("Height").frame(width: 75, alignment: .leading)
                    .scrubbable(sensitivity: scrubSensitivity(isWidth: false),
                                value: dimension(isWidth: false), range: scrubRange(isWidth: false), step: 1)
                    .disabled(!canScrubDimensions)
                TextField("Height", value: dimension(isWidth: false), format: .number.precision(.fractionLength(0...3)))
            }
            Toggle("Lock aspect ratio", isOn: $locked).disabled(!resample)
            HStack {
                Text("Resolution").scrubbable(sensitivity: 1, value: $resolution, range: 1...9600, step: 1)
                TextField("Resolution", value: $resolution, format: .number.precision(.fractionLength(0...3)))
                    .onChange(of: resolution) { _, new in
                        guard new.isFinite, new > 0 else { return }
                        if resample, unit.isPrint {
                            width *= new / lastResolution
                            height *= new / lastResolution
                        }
                        lastResolution = new
                    }
                Text("pixels/inch").foregroundStyle(.secondary)
            }
            Toggle("Resample", isOn: $resample).onChange(of: resample) { _, enabled in
                if !enabled {
                    width = Double(document.width)
                    height = Double(document.height)
                    locked = true
                    if !unit.isPrint { unit = .inches }
                }
            }
            if resample {
                Picker("Sampling", selection: $sampling) {
                    ForEach(LayerSampling.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text("Resizes layer pixels and applies existing transforms. Undo restores the originals.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Only print dimensions and resolution change. Pixels stay unchanged.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text(valid ? "Result: \(Int(width.rounded())) × \(Int(height.rounded())) pixels" : "Use 1–\(DocumentLimits.maxSide.formatted()) pixels per side, up to \(DocumentLimits.maxSurfaceMegapixels) megapixels, and 1–9,600 pixels/inch.")
                .foregroundStyle(valid ? Color.secondary : Color.orange).font(.callout)
            HStack {
                Button("Cancel") { finish(nil) }.configuredNativeShortcut(.escape)
                Spacer()
                Button("Resize") {
                    guard valid else { return }
                    finish(ImageSizeOptions(width: Int(width.rounded()), height: Int(height.rounded()),
                        resolution: resolution, sampling: sampling))
                }.configuredNativeShortcut(.return).disabled(!valid)
            }
        }.textFieldStyle(.roundedBorder).padding(24).frame(width: 430)
    }
}
