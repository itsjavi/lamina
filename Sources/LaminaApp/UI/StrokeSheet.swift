import SwiftUI

/// Edit › Stroke…: a line along the selection's outline, in the foreground or background color.
struct StrokeSheet: View {
    let finish: (StrokeOptions?) -> Void
    @State private var options: StrokeOptions
    @State private var input: String
    @FocusState private var focused: Bool

    init(options: StrokeOptions, finish: @escaping (StrokeOptions?) -> Void) {
        self.finish = finish
        _options = State(initialValue: options)
        _input = State(initialValue: String(Int(options.width)))
    }

    private var maximum: Int { Int(StrokeOptions.widthRange.upperBound) }
    private var width: Int? {
        guard let value = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...maximum).contains(value) else { return nil }
        return value
    }

    var body: some View { sheet.roundedControls() }

    private var opacity: Binding<Int> {
        Binding(get: { Int((options.opacity * 100).rounded()) }, set: { options.opacity = Double(min(100, max(1, $0))) / 100 })
    }

    private var sheet: some View {
        DialogLayout(title: "Stroke", defaultDisabled: width == nil, confirm: {
            guard let width else { return }
            var result = options
            result.width = Double(width)
            finish(result)
        }, cancel: { finish(nil) }) {
            VStack(alignment: .leading, spacing: 12) {
                DialogGroup("Stroke") {
                    DialogRow("Width:", labelWidth: 60) {
                        TextField("Width", text: $input)
                            .frame(width: 56).textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing).focused($focused)
                        Text("px")
                            .scrubbable(sensitivity: 1, value: Binding<Int>(get: { width ?? 1 }, set: { input = String($0) }),
                                        range: 1...maximum)
                    }
                    DialogRow("Color:", labelWidth: 60) {
                        Picker("Color", selection: $options.source) {
                            Text("Foreground Color").tag(EditorSession.FillSource.foreground)
                            Text("Background Color").tag(EditorSession.FillSource.background)
                        }
                        .labelsHidden().fixedSize()
                    }
                }
                DialogGroup("Location") {
                    Picker("Location", selection: $options.location) {
                        ForEach(StrokeLocation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                DialogGroup("Blending") {
                    DialogRow("Opacity:", labelWidth: 60) {
                        TextField("Opacity", value: opacity, format: .number)
                            .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        Text("%").scrubbable(sensitivity: 1, value: opacity, range: 1...100)
                    }
                }
                Text("Enter a whole number from 1 to \(maximum) px.")
                    .font(.callout).foregroundStyle(.secondary)
                    .opacity(width == nil ? 1 : 0)
            }
            .frame(width: 280)
        }
        .onAppear { focused = true }
    }
}
