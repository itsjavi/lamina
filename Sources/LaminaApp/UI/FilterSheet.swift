import AppKit
import SwiftUI
import LaminaCore

/// The open filter's dialog (docs/DESIGN.md, Dialogs). Filters show a preview of the layer with zoom, then their
/// settings; Image adjustments show only the settings; both put OK, Cancel and Preview in the column on the right.
/// Camera Raw keeps its own full-height panel docked to the window, with Cancel and OK at the bottom right.
struct FilterSheet: View {
    @Bindable var session: EditorSession
    private var edit: FilterEdit? { session.filterEdit }
    private var settings: FilterSettings { edit?.settings ?? FilterSettings() }
    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: edit?.preview ?? true)
    }

    private var kind: FilterKind { edit?.kind ?? .gaussianBlur }
    /// Editing an adjustment layer previews in the composite, not on a layer of its own, so there's nothing to crop.
    private var showsPreviewWell: Bool { kind.showsDialogPreview && session.adjustmentOriginal == nil }
    /// The widest slider title in the dialog, so every slider starts and ends in the same place.
    @State private var labelWidth: CGFloat = 60
    static let settingsWidth: CGFloat = 340

    private var preview: Binding<Bool> {
        Binding(get: { edit?.preview ?? true }, set: { session.updateFilter(settings, preview: $0) })
    }
    // While the preview is being worked out (Remove Background's mask, Content-Aware Fill) OK waits, so the dialog
    // says what it is waiting for rather than showing a disabled button and nothing else. Only the slow filters say
    // so: a quick preview (Dither, a blur) showing this at every slider step would flicker.
    private var status: String? {
        if edit?.committing == true { return "Applying…" }
        if edit?.preparing == true && kind.isAutomatic { return "Working…" }
        return nil
    }
    private var okDisabled: Bool { kind.isAutomatic && (edit?.preparing == true || edit?.previewError != nil) }

    var body: some View {
        Group {
            if kind == .cameraRaw { cameraRaw } else { dialog }
        }
        .disabled(edit?.committing == true)
        // Filter colors preview live while the app's color picker is open.
        .onChange(of: session.colorPicker?.color) { _, _ in
            session.previewGradientMapColor()
            session.previewVignetteColor()
            session.previewDitherColor()
        }
    }

    private var dialog: some View {
        DialogLayout(defaultDisabled: okDisabled, preview: preview, status: status, reservesStatus: kind.isAutomatic,
                     confirm: { Task { await session.commitFilter() } }, cancel: { session.cancelFilter() }) {
            VStack(alignment: .leading, spacing: 12) {
                if showsPreviewWell { FilterPreview(session: session).padding(.bottom, 4) }
                controls
                notes
            }
            .frame(width: Self.settingsWidth, alignment: .leading)
            .onPreferenceChange(LabelWidthKey.self) { labelWidth = max(60, $0) }
        } extras: {
            if kind == .curves {
                DialogButton("Reset") { update { $0.curves.channels[$0.curves.channel.index] = [CurvePoint(x: 0, y: 0), CurvePoint(x: 255, y: 255)] } }
                    .help("Put the channel's curve back to a straight line")
            }
        }
    }

    private var cameraRaw: some View {
        VStack(alignment: .leading, spacing: 16) {
            CameraRawControls(session: session)
                .frame(maxHeight: .infinity, alignment: .top)
            Toggle("Preview", isOn: preview).configuredNativeShortcut("p", modifiers: .option)
            notes
            Divider()
            // Cancel and OK at the bottom right, as Camera Raw puts them.
            HStack {
                Spacer()
                if edit?.committing == true {
                    ProgressView().controlSize(.small)
                    Text("Applying…").font(.callout).foregroundStyle(.secondary)
                }
                Button("Cancel") { session.cancelFilter() }.configuredNativeShortcut(.escape)
                Button("OK") { Task { await session.commitFilter() } }
                    .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: FloatingPanelController.dockedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var notes: some View {
        if let error = edit?.previewError {
            Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        if session.adjustmentOriginal == nil && session.selection != nil {
            Text("Limited to the selection").font(.callout).foregroundStyle(.secondary)
        }
    }

    /// Each filter's settings, familiar ones first and Lamina's own after them.
    @ViewBuilder private var controls: some View {
        switch kind {
        case .curves:
            CurvesControls(settings: Binding(get: { settings.curves }, set: { new in update { $0.curves = new } }))
        case .exposure:
            control("Exposure", \.exposure.exposure, range: ExposureSettings.exposureRange, unit: "", decimals: 2, logarithmic: false)
            control("Offset", \.exposure.offset, range: ExposureSettings.offsetRange, unit: "", decimals: 4, logarithmic: false)
            control("Gamma Correction", \.exposure.gamma, range: ExposureSettings.gammaRange, unit: "", decimals: 2, logarithmic: true)
        case .gradientMap:
            GradientMapControls(settings: Binding(get: { settings.gradientMap }, set: { new in update { $0.gradientMap = new } }),
                                pick: { session.openGradientMapColorPicker(highlights: $0) })
        case .blackWhite:
            // Each slider says how bright that family of colors becomes, as Photoshop's do.
            control("Reds", \.blackWhite.reds, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(0))
            control("Yellows", \.blackWhite.yellows, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(60))
            control("Greens", \.blackWhite.greens, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(120))
            control("Cyans", \.blackWhite.cyans, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(180))
            control("Blues", \.blackWhite.blues, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(240))
            control("Magentas", \.blackWhite.magentas, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(300))
            Toggle("Tint", isOn: flag(\.blackWhite.tint))
                .help("Color the result while keeping its tones, for a sepia or a cyanotype")
            if settings.blackWhite.tint {
                control("Hue", \.blackWhite.tintHue, range: 0...360, unit: "°", decimals: 0, logarithmic: false, track: .plain)
                control("Saturation", \.blackWhite.tintSaturation, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        track: .saturation(settings.blackWhite.tintHue))
            }
        case .cameraRaw:
            EmptyView()
        case .colorBalance:
            Text("Shadows").font(.headline)
            control("Cyan / Red", \.colorBalance.shadowCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
            control("Magenta / Green", \.colorBalance.shadowMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
            control("Yellow / Blue", \.colorBalance.shadowYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
            Text("Midtones").font(.headline)
            control("Cyan / Red", \.colorBalance.midCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
            control("Magenta / Green", \.colorBalance.midMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
            control("Yellow / Blue", \.colorBalance.midYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
            Text("Highlights").font(.headline)
            control("Cyan / Red", \.colorBalance.highlightCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
            control("Magenta / Green", \.colorBalance.highlightMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
            control("Yellow / Blue", \.colorBalance.highlightYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
            Toggle("Preserve Luminosity", isOn: flag(\.colorBalance.preserveLuminosity))
                .help("Put each pixel's brightness back afterwards, so only the color moves")
        case .grain:
            control("Amount", \.grain.amount, range: GrainSettings.amountRange, unit: "", decimals: 0, logarithmic: false)
            control("Size", \.grain.size, range: GrainSettings.sizeRange, unit: "Pixels", decimals: 1, logarithmic: true)
            control("Roughness", \.grain.roughness, range: GrainSettings.roughnessRange, unit: "", decimals: 0, logarithmic: false)
        case .removeBackground:
            Text("Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.")
                .fixedSize(horizontal: false, vertical: true)
            labeled("Quality") {
                Picker("Quality", selection: Binding(get: { settings.backgroundQuality },
                                                     set: { new in update { $0.backgroundQuality = new } })) {
                    ForEach(BackgroundQuality.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur")
            }
            if settings.backgroundQuality == .advanced {
                control("Refine", \.refineEdges, range: 0...40, unit: "Pixels", decimals: 0, logarithmic: false,
                        help: "Pull the mask onto the image's own edges, which recovers hair and fur")
                control("Contrast", \.matteContrast, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Clear the haze that leaves background showing through thin areas")
                control("Shift Edge", \.shiftEdge, range: -10...10, unit: "Pixels", decimals: 0, logarithmic: false,
                        help: "Shrink the mask to drop the rim of background color around the subject, or grow it")
            }
        case .contentAwareFill:
            Text("Fill the selection using surrounding pixels from this layer.")
                .fixedSize(horizontal: false, vertical: true)
        case .gaussianBlur:
            control("Radius", \.radius, range: 0.1...250, unit: "Pixels", decimals: 1, logarithmic: true)
        case .motionBlur:
            control("Angle", \.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
            control("Distance", \.distance, range: 1...2000, unit: "Pixels", decimals: 0, logarithmic: true)
        case .unsharpMask:
            control("Amount", \.sharpenAmount, range: 1...500, unit: "%", decimals: 0, logarithmic: false)
            control("Radius", \.sharpenRadius, range: 0.1...1000, unit: "Pixels", decimals: 1, logarithmic: true,
                    help: "How wide an edge the sharpening reaches across")
            control("Threshold", \.sharpenThreshold, range: 0...255, unit: "levels", decimals: 0, logarithmic: false,
                    help: "Leave alone anything this close to its surroundings, such as skin or sky, so it isn't made grainy")
        case .highPass:
            control("Radius", \.highPassRadius, range: 0.1...1000, unit: "Pixels", decimals: 1, logarithmic: true,
                    help: "Keep detail finer than this and turn the rest middle gray; set the layer to Overlay to sharpen with it")
        case .addNoise:
            control("Amount", \.amount, range: 0.1...400, unit: "%", decimals: 1, logarithmic: true)
            DialogGroup("Distribution") {
                Picker("Distribution", selection: flag(\.gaussian)) {
                    Text("Uniform").tag(false)
                    Text("Gaussian").tag(true)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
            Toggle("Monochromatic", isOn: flag(\.monochromatic))
        case .dither:
            ditherControls
        case .vignette:
            labeled("Color") {
                Button { session.openVignetteColorPicker() } label: {
                    let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                    shape.fill(Color(.sRGB, red: settings.vignetteColor.red,
                                     green: settings.vignetteColor.green, blue: settings.vignetteColor.blue))
                        .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                        .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                        .frame(width: 24, height: 24)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .help("Choose the vignette color")
                .accessibilityLabel("Vignette color")
            }
            control("Amount", \.vignetteAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                    help: "Blend the chosen color into the edges while keeping the center unchanged")
            control("Midpoint", \.vignetteMidpoint, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            control("Roundness", \.vignetteRoundness, range: -100...100, unit: "", decimals: 0, logarithmic: false)
            control("Feather", \.vignetteFeather, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            control("Highlights", \.vignetteHighlights, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                    help: "Protect bright areas near the edge")
        case .bloomGlow:
            control("Amount", \.bloomAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            control("Radius", \.bloomRadius, range: 1...150, unit: "Pixels", decimals: 0, logarithmic: true)
        case .tonalContrast:
            control("Amount", \.tonalAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
            control("Shadows", \.tonalShadows, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
            control("Midtones", \.tonalMidtones, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
            control("Highlights", \.tonalHighlights, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
            control("Radius", \.tonalRadius, range: 1...100, unit: "Pixels", decimals: 0, logarithmic: true)
        case .lensCorrection:
            control("Remove Distortion", \.distortion, range: -100...100, unit: "", decimals: 0, logarithmic: false)
            Text("Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A row whose label lines up with the sliders' titles.
    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) {
            label(title)
            content()
            Spacer(minLength: 0)
        }
    }

    /// A setting's title with its colon, right-aligned in the dialog's label column.
    private func label(_ title: String) -> some View {
        Text(title + ":").fixedSize()
            .background(GeometryReader { Color.clear.preference(key: LabelWidthKey.self, value: $0.size.width) })
            .frame(width: labelWidth, alignment: .trailing)
    }

    @ViewBuilder private var ditherControls: some View {
        let dither = settings.dither
        labeled("Style") {
            Picker("Style", selection: Binding(get: { dither.style }, set: { new in update { $0.dither.style = new } })) {
                ForEach(DitherStyle.groups.indices, id: \.self) { group in
                    if group > 0 { Divider() }
                    ForEach(DitherStyle.groups[group], id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            .labelsHidden().fixedSize()
        }
        if dither.style.usesPixelSize {
            control("Pixel Size", \.dither.pixelSize, range: DitherSettings.pixelSizeRange, unit: "Pixels", decimals: 0, logarithmic: false,
                    help: "Make each dithered pixel this many pixels across, for a chunky old-screen look")
        }
        if dither.style == .ascii {
            control("Text Size", \.dither.textSize, range: DitherSettings.textSizeRange, unit: "Pixels", decimals: 0, logarithmic: false,
                    help: "The height of each line of characters")
        }
        if dither.style == .scanlines {
            control("Line Spacing", \.dither.lineSpacing, range: DitherSettings.lineSpacingRange, unit: "Pixels", decimals: 0, logarithmic: false,
                    help: "How far apart the screen's lines are")
            control("Glow", \.dither.glow, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                    help: "Light blooming around the lines, like a CRT's phosphors")
            control("Dots", \.dither.dots, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                    help: "Break the lines into glowing beads")
            control("Wobble", \.dither.wobble, range: DitherSettings.wobbleRange, unit: "Pixels", decimals: 0, logarithmic: false,
                    help: "Make the lines waver sideways down the screen, like a CRT losing sync")
        }
        if dither.style.isHalftone {
            control("Cell Size", \.dither.cellSize, range: DitherSettings.cellSizeRange, unit: "Pixels", decimals: 0, logarithmic: false)
            control("Angle", \.dither.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
        }
        if dither.style == .ascii {
            labeled("Characters") {
                TextField("Characters", text: Binding(get: { dither.characters }, set: { new in update { $0.dither.characters = new } }))
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
            }
            .help("The characters to draw with, in any order: each spot gets the one whose ink best matches its tone")
        }
        if dither.style.hasTones {
            control("Tones", \.dither.levels, range: DitherSettings.levelsRange, unit: "", decimals: 0, logarithmic: false,
                    help: "Tones per channel: 2 is pure black and white")
        }
        if dither.style.diffuses {
            control("Diffusion", \.dither.diffusion, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                    help: "How much of each pixel's error spreads to its neighbors. Less gives flatter areas")
        }
        control("Density", \.dither.density, range: -100...100, unit: "", decimals: 0, logarithmic: false,
                help: "More ink (darker) or less before dithering")
        control("Contrast", \.dither.contrast, range: -100...100, unit: "", decimals: 0, logarithmic: false)
        // A menu, like Style: the three choices as segments are wider than the dialog, which then flips between
        // squeezing the row and wrapping it, resizing itself at every slider step.
        labeled("Colors") {
            Picker("Colors", selection: Binding(get: { dither.colors }, set: { new in update { $0.dither.colors = new } })) {
                ForEach(DitherColors.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
        if dither.colors == .twoColors {
            labeled("Dark") {
                swatch(dither.dark, help: "Choose the dark color") { session.openDitherColorPicker(light: false) }
                Text("Light:").padding(.leading, 10)
                swatch(dither.light, help: "Choose the light color") { session.openDitherColorPicker(light: true) }
            }
        }
        if dither.pixelSize > 1, dither.style.usesPixelSize {
            labeled("Pixel Shape") {
                Picker("Pixel Shape", selection: Binding(get: { dither.pixelShape }, set: { new in update { $0.dither.pixelShape = new } })) {
                    ForEach(DitherPixelShape.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            .help("Draw each chunky pixel as a solid square, or as a round dot like a dot-matrix screen")
        }
        if dither.style.drawsMarks {
            Toggle("Light on Dark", isOn: flag(\.dither.lightOnDark))
                .help("Draw the marks for the light tones on the dark color, like a glowing screen")
        }
    }

    private func swatch(_ color: AdjustmentColor, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape.fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue))
                .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                .frame(width: 24, height: 24)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func flag(_ key: WritableKeyPath<FilterSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } })
    }

    /// The setting put back to its filter's default, as a double-click on a colored slider does.
    static func resetting(_ key: WritableKeyPath<FilterSettings, Double>, in settings: FilterSettings) -> FilterSettings {
        var value = settings
        value[keyPath: key] = FilterSettings()[keyPath: key]
        return value
    }

    static let cyanRedTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.10, green: 0.72, blue: 0.80, alpha: 1),
                                                            NSColor(srgbRed: 0.86, green: 0.18, blue: 0.20, alpha: 1))
    static let magentaGreenTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.80, green: 0.22, blue: 0.70, alpha: 1),
                                                                 NSColor(srgbRed: 0.24, green: 0.70, blue: 0.30, alpha: 1))
    static let yellowBlueTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.95, green: 0.82, blue: 0.18, alpha: 1),
                                                               NSColor(srgbRed: 0.22, green: 0.40, blue: 0.92, alpha: 1))

    /// Units get a column of their own, so every slider and field in a dialog lines up whatever its unit.
    private static let unitWidth: CGFloat = 40

    /// A slider paired with an exact field. Logarithmic sliders give the small values used most most of the travel.
    /// A colored track draws the slider as Camera Raw's, where a double-click on the title or knob resets it.
    private func control(_ title: String, _ key: WritableKeyPath<FilterSettings, Double>, range: ClosedRange<Double>,
                         unit: String, decimals: Int, logarithmic: Bool, track: CameraRawSliderTrack? = nil,
                         help: String? = nil) -> some View {
        let step = pow(10, Double(decimals))
        let reset = { update { $0 = Self.resetting(key, in: $0) } }
        return HStack(spacing: 8) {
            label(title)
                .onTapGesture(count: 2) { if track != nil { reset() } }
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                            range: range)
            if let track {
                CameraRawSlider(value: settings[keyPath: key], range: range, track: track,
                                help: "\(title). Double-click to reset.",
                                onChange: { value in update { $0[keyPath: key] = (value * step).rounded() / step } },
                                onReset: reset)
            } else {
                Slider(value: Binding(get: { logarithmic ? log(settings[keyPath: key]) : settings[keyPath: key] },
                                      set: { value in update { $0[keyPath: key] = ((logarithmic ? exp(value) : value) * step).rounded() / step } }),
                       in: logarithmic ? log(range.lowerBound)...log(range.upperBound) : range)
                    .accessibilityLabel(title)
            }
            HStack(spacing: 4) {
                TextField(title, value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                          format: .number.precision(.fractionLength(0...decimals)))
                    .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                Text(unit).frame(width: Self.unitWidth, alignment: .leading)
            }
        }
        .help(help ?? "")
    }
}

/// Gradient Map's two colors, the gradient they make, and Reverse. The colors are swatches like the
/// tool rail's, and open the app's own color picker.
struct GradientMapControls: View {
    @Binding var settings: GradientMapSettings
    /// Opens the color picker on an end: false for Shadows, true for Highlights.
    let pick: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let ends = settings.ends
            LinearGradient(colors: [color(ends.dark), color(ends.light)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(ColorRole.edge.color) }
                .accessibilityHidden(true)
            HStack(spacing: 20) {
                swatch("Shadows", settings.shadows) { pick(false) }
                swatch("Highlights", settings.highlights) { pick(true) }
                Spacer()
            }
            Toggle("Reverse", isOn: $settings.reversed)
        }
    }

    private func color(_ value: AdjustmentColor) -> Color { Color(.sRGB, red: value.red, green: value.green, blue: value.blue) }

    private func swatch(_ title: String, _ value: AdjustmentColor, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return HStack(spacing: 8) {
            Button(action: action) {
                shape
                    .fill(color(value))
                    .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                    .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                    .frame(width: 24, height: 24)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help("Choose the \(title.lowercased()) color")
            .accessibilityLabel("\(title) color")
            Text(title)
        }
    }
}

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
