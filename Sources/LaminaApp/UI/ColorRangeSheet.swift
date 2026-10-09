import SwiftUI

/// Select › Color Range…: Fuzziness and the selection preview on the left; OK, Cancel, the eyedroppers and Invert in
/// the column on the right, with the selection updating on the canvas.
struct ColorRangeSheet: View {
    @Bindable var session: EditorSession
    private var edit: ColorRangeEdit? { session.colorRange }

    var body: some View {
        DialogLayout(confirm: { session.commitColorRange() }, cancel: { session.cancelColorRange() }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Fuzziness:")
                        .scrubbable(sensitivity: 1, value: fuzziness, range: ColorRangeEdit.fuzzinessRange)
                    TextField("Fuzziness", value: fuzziness, format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                }
                Slider(value: fuzziness, in: ColorRangeEdit.fuzzinessRange).accessibilityLabel("Fuzziness")
                preview.padding(.top, 4)
                Text(edit?.hasColors == true ? "Shift-click adds a color, Option-click takes one away."
                                             : "Click the image to pick the color to select.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let error = edit?.error {
                    Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }
            .help("How far a color may be from the picked ones and still be selected")
            .frame(width: ColorRangeEdit.previewSize.width, alignment: .leading)
        } extras: {
            HStack(spacing: 4) {
                ForEach(HueSampleMode.allCases, id: \.self) { mode in
                    Button { edit?.sampleMode = mode } label: { eyedropper(mode) }
                        .buttonStyle(.plain)
                        // Holding Shift or Option lights up the eyedropper a click will use.
                        .background(edit?.effectiveMode == mode ? ColorRole.activeTool.color : .clear,
                                    in: RoundedRectangle(cornerRadius: 4))
                        .help(help(mode))
                        .accessibilityLabel("\(mode.rawValue) color")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            Toggle("Invert", isOn: Binding(get: { edit?.invert ?? false }, set: { edit?.invert = $0; session.updateColorRange() }))
                .help("Select everything except those colors, such as all but a green screen")
                .padding(.top, 4)
        }
    }
    /// The selection in black and white, white where selected, shaped like the canvas: black until a color is picked.
    private var preview: some View {
        let image = edit?.image
        let size = image.map { CGSize(width: $0.width, height: $0.height) } ?? ColorRangeEdit.previewSize
        let scale = min(ColorRangeEdit.previewSize.width / size.width, ColorRangeEdit.previewSize.height / size.height)
        return ZStack {
            Color.black
            if let picture = edit?.preview { Image(decorative: picture, scale: 2).resizable() }
        }
        .frame(width: size.width * scale, height: size.height * scale)
        .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
        .frame(maxWidth: .infinity)
    }

    private var fuzziness: Binding<Double> {
        Binding(get: { edit?.fuzziness ?? 40 }, set: { value in
            let clamped = min(ColorRangeEdit.fuzzinessRange.upperBound, max(ColorRangeEdit.fuzzinessRange.lowerBound, value.rounded()))
            guard let edit, edit.fuzziness != clamped else { return }
            edit.fuzziness = clamped
            session.updateColorRange()
        })
    }

    private func help(_ mode: HueSampleMode) -> String {
        switch mode {
        case .replace: "Click the image to select that color"
        case .add: "Click the image to add that color to the selection"
        case .remove: "Click the image to take that color out of the selection"
        }
    }

    /// The eyedropper, with a plus or minus badge for Add and Remove, as Hue/Saturation's.
    private func eyedropper(_ mode: HueSampleMode) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: mode.symbol)
            if let badge = mode.badge {
                Image(systemName: badge).font(.system(size: 8, weight: .semibold)).offset(x: 3, y: 1)
            }
        }
        .frame(width: 24, height: 20)
    }
}
