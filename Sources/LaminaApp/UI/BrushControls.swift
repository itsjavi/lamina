import SwiftUI

/// The painting tools' bars: the brush picker, then each tool's settings in the order familiar editors give them
/// (docs/DESIGN.md, Options bars). Color comes from the toolbar's swatches, for masks too, so there is no swatch here.
struct BrushControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        OptionsBarRow(commit: liquifyCommit) {
            BrushPicker(session: session)
            OptionsBarDivider()
            settings
            if session.tool == .cloneStamp, session.cloneSource == nil {
                Text("Option-click to set the source").foregroundStyle(.secondary)
            }
            if session.isMaskSelected { Text("Mask").foregroundStyle(.secondary) }
        }
        .releasesFocusOnCommit(session)
        .disabled(session.showsBusy)
    }

    @ViewBuilder private var settings: some View {
        switch session.tool {
        case .brush:
            opacity
            pressureForOpacity
            flow
            OptionsBarDivider()
            smoothing
            OptionsBarDivider()
            pressureForSize
        case .eraser:
            opacity
            pressureForOpacity
            flow
            smoothing
            OptionsBarDivider()
            pressureForSize
        case .spotHealing:
            HStack(spacing: 4) {
                Text("Type:")
                Picker("Type", selection: $session.spotHealingMode) {
                    ForEach(SpotHealingMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .accessibilityIdentifier("spotHealingType")
            }
            OptionsBarDivider()
            opacity
        case .cloneStamp:
            opacity
            OptionsBarDivider()
            Toggle("Aligned", isOn: $session.cloneSettings.aligned).toggleStyle(.checkbox)
                .help("Keep the source moving with the brush between strokes; off starts every stroke at the source point")
            OptionsBarPicker(label: "Sample", selection: $session.cloneSettings.sampleAllLayers) {
                Text("Current Layer").tag(false)
                Text("All Layers").tag(true)
            }
            .help("Copy from the active layer only, or from every visible layer as shown")
        case .blur:
            strength
            OptionsBarField(label: "Radius", value: $session.brushSettings.blurRadius, range: 0.5...50, unit: "px", width: 42,
                            decimals: 1, sensitivity: 0.1)
                .help("How far the blur softens, in pixels")
        case .smudge, .liquify:
            strength
        case .dodge, .burn:
            OptionsBarPicker(label: "Range", selection: $session.toneRange) {
                ForEach(ToneRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .help("Work mostly on the dark, middle or light tones; the rest are touched less the further they are")
            PercentField(label: "Exposure", value: $session.toneExposure, range: 0...1)
                .help("How far a full-strength stroke moves the pixels toward white or black. Press 1–9 for 10–90%, 0 for 100%")
            OptionsBarDivider()
            pressureForSize
        default:
            EmptyView()
        }
    }

    private var opacity: some View {
        PercentField(label: "Opacity", value: $session.brushSettings.opacity)
            .help("Press 1–9 for 10–90%, 0 for 100%")
    }

    /// Blur, Smudge and Liquify lay their effect down as strongly as this; the number keys set it.
    private var strength: some View {
        PercentField(label: "Strength", value: $session.brushSettings.opacity)
            .help("Press 1–9 for 10–90%, 0 for 100%")
    }

    /// Photoshop's Flow: how much each dab lays down, building up toward Opacity as the stroke goes over itself.
    private var flow: some View {
        PercentField(label: "Flow", value: $session.brushSettings.flow)
            .help("How much paint each dab lays down. Going over the same place in one stroke builds it up, up to the Opacity")
    }

    private var smoothing: some View {
        PercentField(label: "Smoothing", value: Binding(get: { session.brushSettings.smoothing / 100 },
                                                        set: { session.brushSettings.smoothing = ($0 * 100).rounded() }),
                     range: 0...1)
            .help("The brush trails the pointer on a string this long, so a shaky hand still draws a smooth line")
    }

    /// A pen's pressure, as familiar editors' two buttons: one after Opacity, one at the end.
    private var pressureForOpacity: some View {
        OptionsBarIconButton(title: "Always use pressure for opacity", symbol: "drop.halffull",
                             isPressed: session.brushSettings.pressureOpacity) {
            session.brushSettings.pressureOpacity.toggle()
        }
    }

    private var pressureForSize: some View {
        OptionsBarIconButton(title: "Always use pressure for size", symbol: "scribble.variable",
                             isPressed: session.brushSettings.pressureSize) {
            session.brushSettings.pressureSize.toggle()
        }
    }

    /// Liquify is a stop on the way back to the tool it was chosen from (Filter ▸ Liquify…).
    private var liquifyCommit: OptionsBarCommitButtons? {
        guard session.tool == .liquify else { return nil }
        return OptionsBarCommitButtons(cancelTitle: "Cancel Liquify (Escape)", commitTitle: "Commit Liquify (Return)",
                                       cancel: { session.cancelLiquify() }, commit: { session.finishLiquify() })
    }
}

/// A rubber stamp for the tool rail (SF Symbols has none): round handle, neck, body, and pad.
struct CloneStampToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var stamp = Path()
            stamp.addEllipse(in: CGRect(x: w * 0.33, y: h * 0.02, width: w * 0.34, height: h * 0.30))
            stamp.addRect(CGRect(x: w * 0.43, y: h * 0.28, width: w * 0.14, height: h * 0.28))
            stamp.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.54, width: w * 0.76, height: h * 0.22),
                                 cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
            stamp.addRect(CGRect(x: w * 0.06, y: h * 0.82, width: w * 0.88, height: h * 0.12))
            context.fill(stamp, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
