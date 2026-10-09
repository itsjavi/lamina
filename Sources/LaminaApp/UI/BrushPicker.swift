import SwiftUI

/// The painting tools' brush picker, first in their bars: the tip as it paints (hardness as a soft or hard edge) with
/// its size under it. A click opens Size and Hardness, and for the Brush the bristle presets to come.
struct BrushPicker: View {
    @Bindable var session: EditorSession
    @State private var isOpen = false

    var body: some View {
        let settings = session.brushSettings
        Button { isOpen.toggle() } label: {
            HStack(spacing: 3) {
                VStack(spacing: 1) {
                    BrushTipPreview(hardness: settings.hardness).frame(width: 15, height: 15)
                    Text(Int(settings.diameter.rounded()), format: .number.grouping(.never))
                        .font(.system(size: 9).monospacedDigit())
                }
                .frame(minWidth: 26)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .frame(height: 32).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Brush: size and hardness ([ and ] change the size, Shift-[ and Shift-] the hardness)")
        .accessibilityLabel("Brush, \(Int(settings.diameter.rounded())) pixels, \(Int((settings.hardness * 100).rounded())) percent hardness")
        .accessibilityIdentifier("brushPicker")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { BrushPickerPanel(session: session) }
    }
}

/// What the brush picker opens: Size and Hardness, each a slider and a field, then the Brush's bristle presets.
struct BrushPickerPanel: View {
    @Bindable var session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                GridRow {
                    Text("Size:").gridColumnAlignment(.trailing)
                    // Square-root steps, so the small sizes painted most often get most of the track.
                    Slider(value: Binding(get: { BrushPickerPanel.sliderPosition(diameter: session.brushSettings.diameter) },
                                          set: { session.brushSettings.diameter = BrushPickerPanel.diameter(sliderPosition: $0) }),
                           in: 0...1)
                        .frame(width: 150)
                        .accessibilityLabel("Size")
                    TextField("Size", value: Binding<Double>(get: { Double(session.brushSettings.diameter) },
                        set: { session.brushSettings.diameter = $0.isFinite ? CGFloat(min(2000, max(1, $0))) : 40 }),
                        format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        .arrowSteps(value: { Double(session.brushSettings.diameter) },
                                    change: { session.brushSettings.diameter = CGFloat(min(2000, max(1, $0))) })
                        .unitSuffix("px").fixedSize()
                }
                GridRow {
                    Text("Hardness:")
                    Slider(value: $session.brushSettings.hardness, in: 0...1).frame(width: 150)
                        .accessibilityLabel("Hardness")
                    TextField("Hardness", value: Binding<Double>(get: { Double(session.brushSettings.hardness * 100) },
                        set: { session.brushSettings.hardness = $0.isFinite ? CGFloat(min(100, max(0, $0)) / 100) : 1 }),
                        format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        .arrowSteps(value: { Double(session.brushSettings.hardness * 100) },
                                    change: { session.brushSettings.hardness = CGFloat(min(100, max(0, $0)) / 100) })
                        .unitSuffix("%").fixedSize()
                }
            }
            if session.tool == .brush {
                Divider()
                BristlePresetList(session: session)
            }
        }
        .padding(14)
        .releasesFocusOnCommit(session)
    }

    /// The slider's 0–1 position for a diameter of 1–2000 px.
    static func sliderPosition(diameter: CGFloat) -> CGFloat {
        ((min(2000, max(1, diameter)) - 1) / 1999).squareRoot()
    }

    static func diameter(sliderPosition: CGFloat) -> CGFloat {
        (1 + 1999 * min(1, max(0, sliderPosition)) * min(1, max(0, sliderPosition))).rounded()
    }
}

/// The tip, drawn in the bar's text color: solid to the hardness, then fading to its edge.
struct BrushTipPreview: View {
    let hardness: CGFloat

    var body: some View {
        let color = ColorRole.text.color
        let solid = min(0.98, max(0, hardness))
        Circle()
            .fill(RadialGradient(stops: [.init(color: color, location: 0), .init(color: color, location: solid),
                                         .init(color: color.opacity(0), location: 1)],
                                 center: .center, startRadius: 0, endRadius: 7.5))
            .accessibilityHidden(true)
    }
}
