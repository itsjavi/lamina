import SwiftUI
import LaminaCore

/// Reads and writes the open edit's settings, so sampling from the canvas and the panel's
/// own controls always agree.
struct HueSaturationSheet: View {
    @Bindable var session: EditorSession

    private var edit: HueSaturationEdit? { session.hueSaturation }
    private var current: HueSaturationSettings { edit?.settings ?? HueSaturationSettings() }
    private var showsSpectrum: Bool { current.showsSpectrum }

    private var settings: Binding<HueSaturationSettings> {
        Binding(get: { current },
                set: { session.updateHueSaturation($0, preview: session.hueSaturation?.preview ?? true) })
    }
    private var preview: Binding<Bool> {
        Binding(get: { session.hueSaturation?.preview ?? true },
                set: { session.updateHueSaturation(current, preview: $0) })
    }

    var body: some View {
        DialogLayout(preview: preview, confirm: { Task { await session.commitHueSaturation() } },
                     cancel: { session.cancelHueSaturation() }) {
            VStack(alignment: .leading, spacing: 8) {
                // A field's own submit swallows Return, so it confirms the window itself, as OK does.
                HueSaturationControls(settings: settings, submit: { Task { await session.commitHueSaturation() } }) {
                    samplingControls
                }
                if session.selection != nil {
                    Text("Limited to the selection").font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(width: 320, alignment: .leading)
        } extras: {
            DialogButton("Reset") { settings.wrappedValue = current.colorize ? .colorizeStart : HueSaturationSettings() }
        }
    }
    /// Eyedroppers set the selected range from the image; the targeted tool drags on it.
    private var samplingControls: some View {
        HStack(spacing: 6) {
            // Only shown once they do something: a color range is selected, and not Colorize.
            if showsSpectrum {
                ForEach(HueSampleMode.allCases, id: \.self) { mode in
                    Button {
                        session.hueTargeting = false
                        session.hueSampleMode = session.hueSampleMode == mode ? nil : mode
                    } label: {
                        eyedropper(mode)
                    }
                    .buttonStyle(.plain)
                    .background(session.hueSampleMode == mode ? ColorRole.activeTool.color : .clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .help(mode.help)
                    .accessibilityLabel("\(mode.rawValue) color")
                }
                Divider().frame(height: 16)
            }
            if !current.colorize {
                Button {
                    session.hueSampleMode = nil
                    session.hueTargeting.toggle()
                } label: {
                    Image(systemName: "hand.point.up.left").frame(width: 24, height: 20)
                }
                .buttonStyle(.plain)
                .background(session.hueTargeting ? ColorRole.activeTool.color : .clear,
                            in: RoundedRectangle(cornerRadius: 4))
                .help("Targeted adjustment: drag on the image to change that color's saturation, or its hue with Command held")
                .accessibilityLabel("Targeted adjustment")
            }
        }
    }

    /// The eyedropper, with a plus or minus badge for Add and Remove.
    private func eyedropper(_ mode: HueSampleMode) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: mode.symbol)
            if let badge = mode.badge {
                Image(systemName: badge)
                    .font(.system(size: 8, weight: .semibold))
                    .offset(x: 3, y: 1)
            }
        }
        .frame(width: 24, height: 20)
    }
}

/// Hue/Saturation's settings: the range, Hue, Saturation and Lightness, the spectrum for a color range, Colorize, and
/// Lamina's Apply outside this range. Image ▸ Adjustments ▸ Hue/Saturation… shows them with its eyedroppers
/// (`accessory`, beside Colorize); a Hue/Saturation layer's Properties shows them on their own.
struct HueSaturationControls<Accessory: View>: View {
    @Binding var settings: HueSaturationSettings
    /// Return in a field: the dialog confirms.
    var submit: () -> Void = {}
    @ViewBuilder var accessory: Accessory

    private var current: HueSaturationSettings { settings }
    private var hueRange: ClosedRange<Double> { current.colorize ? 0...360 : -180...180 }
    private var saturationRange: ClosedRange<Double> { current.colorize ? 0...100 : -100...100 }
    /// What a double-click puts a slider back to: Photoshop's colorize start, or no change.
    private var resetValues: HueSaturationSettings { current.colorize ? .colorizeStart : HueSaturationSettings() }
    /// The middle of the selected color range; Master centers on red.
    private var rangeHue: Double { Double(max(0, ColorRange.colorRanges.firstIndex(of: current.range) ?? 0)) * 60 }
    /// Colorizing picks an absolute hue, red to red; otherwise the track shows the shift around the range's color.
    private var hueTrack: CameraRawSliderTrack { .spectrum(current.colorize ? 180 : rangeHue) }
    private var saturationTrack: CameraRawSliderTrack {
        if current.colorize { return .saturation(current.hue) }
        return current.range == .master ? .chroma : .saturation(rangeHue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $settings.range) {
                ForEach(ColorRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu).labelsHidden().fixedSize().disabled(current.colorize)
            .help("The colors the adjustment changes: Master is all of them")
            slider("Hue", value: $settings.hue, range: hueRange, unit: "°", track: hueTrack, reset: resetValues.hue)
            slider("Saturation", value: $settings.saturation, range: saturationRange, unit: "", track: saturationTrack,
                   reset: resetValues.saturation)
            slider("Lightness", value: $settings.lightness, range: -100...100, unit: "",
                   track: .opposing(.black, .white), reset: resetValues.lightness)
            if current.showsSpectrum { SpectrumEditor(settings: $settings).padding(.top, 8) }
            HStack(spacing: 8) {
                Toggle("Colorize", isOn: Binding(get: { current.colorize }, set: { colorize in
                    // Photoshop starts colorizing at hue 0, saturation 25.
                    settings = colorize ? .colorizeStart : HueSaturationSettings()
                }))
                Spacer(minLength: 0)
                accessory
            }
            .padding(.top, 8)
            // Lamina's own, after the familiar settings.
            if current.showsSpectrum { Toggle("Apply outside this range instead", isOn: $settings.invertRange) }
        }
    }

    /// Photoshop's layout: the title above, then a colored slider paired with an exact field. A double-click on the
    /// title or knob resets that one value.
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String,
                        track: CameraRawSliderTrack, reset: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title + ":")
                .onTapGesture(count: 2) { value.wrappedValue = reset }
                .scrubbable(sensitivity: 1, value: value, range: range)
            HStack(spacing: 8) {
                CameraRawSlider(value: value.wrappedValue, range: range, track: track, help: "\(title). Double-click to reset.",
                                onChange: { value.wrappedValue = $0.rounded() }, onReset: { value.wrappedValue = reset })
                HStack(spacing: 2) {
                    TextField(title, value: value, format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        // A field's own submit swallows Return, so it confirms the window itself, as OK does.
                        .onSubmit {
                            value.wrappedValue = min(range.upperBound, max(range.lowerBound, value.wrappedValue))
                            submit()
                        }
                    Text(unit).frame(width: 12, alignment: .leading)
                }
            }
        }
        .padding(.top, 6)
    }
}

extension HueSaturationControls where Accessory == EmptyView {
    init(settings: Binding<HueSaturationSettings>) { self.init(settings: settings, accessory: { EmptyView() }) }
}

extension HueSaturationSettings {
    /// A color range is chosen, and not Colorize: the spectrum, its eyedroppers and Apply outside this range show.
    var showsSpectrum: Bool { range != .master && !colorize }
}

/// Photoshop's two spectrum bars: the hues as they are, the handles for the selected
/// range's band, and the hues as the adjustment leaves them.
struct SpectrumEditor: View {
    @Binding var settings: HueSaturationSettings
    @State private var dragging: Int?
    private let slices = 72

    var body: some View {
        VStack(spacing: 5) {
            spectrum(after: false)
            handles
            spectrum(after: true)
            Text(settings.band.handles.map { "\(NumberLabel.whole($0))°" }.joined(separator: "   "))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func spectrum(after: Bool) -> some View {
        Canvas { context, size in
            let width = size.width / CGFloat(slices)
            for slice in 0..<slices {
                let hue = Double(slice) / Double(slices) * 360
                let shown = after ? HueSaturationFilter.shiftedHue(hue, settings: settings) : hue
                context.fill(Path(CGRect(x: CGFloat(slice) * width, y: 0, width: width + 0.5, height: size.height)),
                             with: .color(Color(hue: shown / 360, saturation: 1, brightness: 1)))
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    /// Outer marks are the falloff shoulders; inner bars are the full-strength range.
    private var handles: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            Canvas { context, size in
                for (index, degrees) in settings.band.handles.enumerated() {
                    let x = CGFloat(degrees / 360) * width
                    let isInner = index == 1 || index == 2
                    let rect = isInner ? CGRect(x: x - 1, y: 0, width: 2, height: size.height)
                                       : CGRect(x: x - 3.5, y: size.height / 2 - 2.5, width: 7, height: 5)
                    context.fill(Path(rect), with: .color(.primary))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard width > 0 else { return }
                    let degrees = Double(min(max(0, value.location.x), width) / width) * 360
                    let index = dragging ?? nearestHandle(to: degrees)
                    dragging = index
                    settings.band.setHandle(index, to: degrees)
                }
                .onEnded { _ in dragging = nil })
        }
        .frame(height: 12)
    }

    private func nearestHandle(to degrees: Double) -> Int {
        let distances = settings.band.handles.map { handle -> Double in
            let gap = abs(handle - degrees).truncatingRemainder(dividingBy: 360)
            return min(gap, 360 - gap)
        }
        return distances.firstIndex(of: distances.min() ?? 0) ?? 0
    }
}
