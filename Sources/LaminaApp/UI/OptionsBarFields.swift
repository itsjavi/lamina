import SwiftUI

/// A number in a bar: its label with a colon ("Tolerance:"), which can be dragged to change it, the field, and its unit.
struct OptionsBarField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String? = nil
    var width: CGFloat = 44
    /// Decimals the field shows at most.
    var decimals = 0
    var sensitivity = 1.0

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":").scrubbable(sensitivity: sensitivity, value: clamped, range: range)
            HStack(spacing: 2) {
                TextField(label, value: clamped, format: .number.precision(.fractionLength(0...decimals)))
                    .frame(width: width).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .arrowSteps(value: { value }, change: { clamped.wrappedValue = $0 })
                if let unit { Text(unit) }
            }
        }
        // Text gives way before controls, so without this the label and unit would squeeze out of a full bar.
        .fixedSize()
    }

    private var clamped: Binding<Double> {
        Binding(get: { value }, set: { value = $0.isFinite ? min(range.upperBound, max(range.lowerBound, $0)) : value })
    }
}

extension OptionsBarField {
    /// The same for a whole number, such as the Magic Wand's tolerance.
    init(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String? = nil, width: CGFloat = 44) {
        self.init(label: label, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }),
                  range: Double(range.lowerBound)...Double(range.upperBound), unit: unit, width: width)
    }

    /// The same for a length kept as `CGFloat`, such as a radius in pixels.
    init(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, unit: String? = nil, width: CGFloat = 44,
         decimals: Int = 0, sensitivity: Double = 1) {
        self.init(label: label, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) }),
                  range: Double(range.lowerBound)...Double(range.upperBound), unit: unit, width: width, decimals: decimals,
                  sensitivity: sensitivity)
    }
}

/// A percentage in a bar (Opacity, Flow, Strength, Exposure): its label, the field with "%", and a small chevron that
/// opens a slider, as familiar editors' bars have them. `value` is a fraction, 0–1.
struct PercentField: View {
    let label: String
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0.01...1
    @State private var showsSlider = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":").scrubbable(sensitivity: 0.01, value: clamped, range: range)
            HStack(spacing: 2) {
                TextField(label, value: Binding<Double>(get: { Double(value * 100) }, set: { clamped.wrappedValue = CGFloat($0 / 100) }),
                          format: .number.precision(.fractionLength(0)))
                    .frame(width: 42).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(value * 100) }, change: { clamped.wrappedValue = CGFloat($0 / 100) })
                Text("%")
                Button { showsSlider.toggle() } label: {
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                        .frame(width: 14, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(label + " slider")
                .accessibilityLabel(label + " slider")
                .popover(isPresented: $showsSlider, arrowEdge: .bottom) {
                    Slider(value: clamped, in: range).frame(width: 160).padding(12)
                        .accessibilityLabel(label)
                }
            }
        }
        .fixedSize()
    }

    private var clamped: Binding<CGFloat> {
        Binding(get: { value }, set: { value = $0.isFinite ? min(range.upperBound, max(range.lowerBound, $0)) : value })
    }
}

/// A pop-up with its label outside it, with a colon ("Range:", "Sample:"), as bars label their menus.
struct OptionsBarPicker<Value: Hashable, Options: View>: View {
    let label: String
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
            Picker(label, selection: $selection) { options }.labelsHidden().fixedSize()
        }
    }
}
