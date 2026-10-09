import SwiftUI

struct BrushControls: View {
    @Bindable var session: EditorSession
    var body: some View {
        // With everything the Brush has (Flow, the pressure buttons, Smoothing) the bar is wider than
        // many windows. Where it doesn't fit, the sliders go and their fields stay, each still scrubbable by its label,
        // rather than the bar being cut off.
        ViewThatFits(in: .horizontal) {
            controls(sliders: true)
            controls(sliders: false)
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy)
    }

    private func controls(sliders: Bool) -> some View {
        HStack(spacing: 12) {
            Text(session.tool.title).font(ToolHeaderStyle.titleFont)
            if session.tool == .spotHealing {
                Picker("Type", selection: $session.spotHealingMode) {
                    ForEach(SpotHealingMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .accessibilityIdentifier("spotHealingType")
            }
            if session.tool == .cloneStamp {
                Toggle("Aligned", isOn: $session.cloneSettings.aligned)
                    .help("Keep the source moving with the brush between strokes; off starts every stroke at the source point")
                Picker("Sample", selection: $session.cloneSettings.sampleAllLayers) {
                    Text("This Layer").tag(false)
                    Text("All Layers").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("Copy from the active layer only, or from every visible layer as shown")
            }
            Text("Size").scrubbable(sensitivity: 1.0, value: $session.brushSettings.diameter, range: 1...2000)
            TextField("Size", value: Binding<Double>(get: { Double(session.brushSettings.diameter) },
                set: { session.brushSettings.diameter = $0.isFinite ? CGFloat(min(2000, max(1, $0))) : 40 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 48).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.diameter) },
                            change: { session.brushSettings.diameter = CGFloat(min(2000, max(1, $0))) })
                .onChange(of: session.brushSettings.diameter) { _, value in
                    session.brushSettings.diameter = value.isFinite ? min(2000, max(1, value)) : 40
                }
                .unitSuffix("px")
                // Fields keep their units whole: otherwise the bar squeezes a unit onto two lines, even with room to
                // spare at its end.
                .fixedSize()
            // A pen's pressure, as Photoshop's two buttons: one beside Size, one beside Opacity.
            if session.tool.usesBrushDynamics {
                Toggle(isOn: $session.brushSettings.pressureSize) { Image(systemName: "scribble.variable") }
                    .toggleStyle(.button)
                    .help("Pen pressure sets the size: a light touch paints a thinner line. A mouse or trackpad always paints full size.")
                    .accessibilityLabel("Pressure for size")
            }
            Text("Hardness").scrubbable(sensitivity: 0.01, value: $session.brushSettings.hardness, range: 0...1)
            if sliders { Slider(value: $session.brushSettings.hardness, in: 0...1).frame(width: 100) }
            TextField("Hardness", value: Binding<Double>(get: { Double(session.brushSettings.hardness * 100) },
                set: { session.brushSettings.hardness = $0.isFinite ? CGFloat(min(1, max(0, $0 / 100))) : 1 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 42).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.hardness * 100) },
                            change: { session.brushSettings.hardness = CGFloat(min(1, max(0, $0 / 100))) })
                .unitSuffix("%")
                .fixedSize()
            Text(session.tool.warps || session.tool == .blur ? "Strength" : "Opacity")
                .scrubbable(sensitivity: 0.01, value: $session.brushSettings.opacity, range: 0.01...1)
            if sliders { Slider(value: $session.brushSettings.opacity, in: 0.01...1).frame(width: 100) }
            TextField("Opacity", value: Binding<Double>(get: { Double(session.brushSettings.opacity * 100) },
                set: { session.brushSettings.opacity = $0.isFinite ? CGFloat(min(100, max(1, $0)) / 100) : 1 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 42).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.opacity * 100) },
                            change: { session.brushSettings.opacity = CGFloat(min(100, max(1, $0)) / 100) })
                .help("Press 1–9 for 10–90%, 0 for 100%")
                .unitSuffix("%")
                .fixedSize()
            if session.tool.usesBrushDynamics {
                Toggle(isOn: $session.brushSettings.pressureOpacity) { Image(systemName: "drop.halffull") }
                    .toggleStyle(.button)
                    .help("Pen pressure sets the opacity: a light touch paints fainter, up to the brush’s Opacity. A mouse or trackpad always paints at full opacity.")
                    .accessibilityLabel("Pressure for opacity")
                // Photoshop's Flow: how much each dab lays down, building up toward Opacity as the stroke goes over itself.
                // A field without a slider, like Size, so the bar stays narrow enough with everything the Brush has.
                Text("Flow").scrubbable(sensitivity: 0.01, value: $session.brushSettings.flow, range: 0.01...1)
                TextField("Flow", value: Binding<Double>(get: { Double(session.brushSettings.flow * 100) },
                    set: { session.brushSettings.flow = $0.isFinite ? CGFloat(min(100, max(1, $0)) / 100) : 1 }),
                    format: .number.precision(.fractionLength(0)))
                    .frame(width: 42).textFieldStyle(.roundedBorder)
                    .arrowSteps(value: { Double(session.brushSettings.flow * 100) },
                                change: { session.brushSettings.flow = CGFloat(min(100, max(1, $0)) / 100) })
                    .help("How much paint each dab lays down. Going over the same place in one stroke builds it up, up to the Opacity")
                    .unitSuffix("%")
                    .fixedSize()
            }
            // Blur softens by a radius of its own, apart from how strongly it lays the softening down.
            if session.tool == .blur {
                Text("Radius").scrubbable(sensitivity: 0.1, value: $session.brushSettings.blurRadius, range: 0.5...50)
                // The slider covers everyday radii; typing or scrubbing reaches up to 50.
                if sliders {
                    Slider(value: Binding(get: { min(20, session.brushSettings.blurRadius) },
                                          set: { session.brushSettings.blurRadius = $0 }), in: 0.5...20).frame(width: 100)
                }
                TextField("Radius", value: Binding<Double>(get: { Double(session.brushSettings.blurRadius) },
                    set: { session.brushSettings.blurRadius = $0.isFinite ? CGFloat(min(50, max(0.5, $0))) : 5 }),
                    format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 42).textFieldStyle(.roundedBorder)
                    .arrowSteps(value: { Double(session.brushSettings.blurRadius) },
                                change: { session.brushSettings.blurRadius = CGFloat(min(50, max(0.5, $0))) })
                    .help("How far the blur softens, in pixels")
                    .unitSuffix("px")
                    .fixedSize()
            }
            // Dodge and Burn: which tones they reach, and how far they move them.
            if session.tool.toneLightens != nil {
                Picker("Range", selection: $session.toneRange) {
                    ForEach(ToneRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .fixedSize()
                .help("Work mostly on the dark, middle or light tones; the rest are touched less the further they are")
                Text("Exposure").scrubbable(sensitivity: 0.01, value: $session.toneExposure, range: 0...1)
                TextField("Exposure", value: Binding<Double>(get: { Double(session.toneExposure * 100) },
                    set: { session.toneExposure = $0.isFinite ? CGFloat(min(100, max(0, $0)) / 100) : 0.5 }),
                    format: .number.precision(.fractionLength(0)))
                    .frame(width: 42).textFieldStyle(.roundedBorder)
                    .arrowSteps(value: { Double(session.toneExposure * 100) },
                                change: { session.toneExposure = CGFloat(min(100, max(0, $0)) / 100) })
                    .help("How far a full-strength stroke moves the pixels toward white or black")
                    .unitSuffix("%")
                    .fixedSize()
            }
            // The Brush and the tools that were its modes: healing, cloning and smearing have their own feel.
            if session.tool.usesBrushDynamics {
                Text("Smoothing")
                    .scrubbable(sensitivity: 1, value: $session.brushSettings.smoothing, range: 0...100)
                if sliders { Slider(value: $session.brushSettings.smoothing, in: 0...100).frame(width: 100) }
                TextField("Smoothing", value: Binding<Double>(get: { Double(session.brushSettings.smoothing) },
                    set: { session.brushSettings.smoothing = $0.isFinite ? CGFloat(min(100, max(0, $0))) : 0 }),
                    format: .number.precision(.fractionLength(0)))
                    .frame(width: 42).textFieldStyle(.roundedBorder)
                    .arrowSteps(value: { Double(session.brushSettings.smoothing) },
                                change: { session.brushSettings.smoothing = CGFloat(min(100, max(0, $0))) })
                    .help("The brush trails the pointer on a string this long, so a shaky hand still draws a smooth line")
            }
            if session.isMaskSelected {
                Picker("Paint", selection: $session.maskPaintWhite) {
                    Text("Black · Hide").tag(false)
                    Text("White · Reveal").tag(true)
                }.frame(width: 180)
            } else if session.tool == .brush || session.tool == .spotHealing {
                // Same foreground color and Color Picker as the tool-rail swatch.
                HStack(spacing: 6) {
                    Text("Color")
                    Button { session.openColorPicker(background: false) } label: {
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                        shape.fill(session.foregroundColor.swiftUI)
                            .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1) }
                            .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                            .frame(width: 34, height: 18)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canEditPalette)
                    .help("Foreground color")
                    .accessibilityLabel("Foreground color")
                }
            }
            Spacer(minLength: 0)
            if session.tool == .cloneStamp, session.cloneSource == nil {
                Text("Option-click to set the source").foregroundStyle(.secondary)
            }
            if session.isMaskSelected { Text("Mask").foregroundStyle(.secondary) }
            // Liquify is a stop on the way back to the tool it was chosen from (Filter ▸ Liquify…).
            if session.tool == .liquify {
                Button("Cancel") { session.cancelLiquify() }
                    .help("Take back the Liquify strokes and go back to the tool you were using (Escape)")
                Button("Done") { session.finishLiquify() }
                    .help("Keep the Liquify strokes and go back to the tool you were using (Return)")
            }
        }
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
