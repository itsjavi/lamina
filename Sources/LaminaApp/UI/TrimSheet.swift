import SwiftUI

/// Image › Trim…: what to trim away, based on transparency or a corner pixel's color.
struct TrimSheet: View {
    let finish: (TrimOptions?) -> Void
    @State private var basedOn: TrimBasedOn = .transparentPixels
    @State private var trimTop: Bool = true
    @State private var trimBottom: Bool = true
    @State private var trimLeft: Bool = true
    @State private var trimRight: Bool = true

    var body: some View { sheet.roundedControls() }

    private var sheet: some View {
        DialogLayout(title: "Trim", defaultDisabled: !trimTop && !trimBottom && !trimLeft && !trimRight, confirm: {
            finish(TrimOptions(basedOn: basedOn, top: trimTop, bottom: trimBottom, left: trimLeft, right: trimRight))
        }, cancel: { finish(nil) }) {
            VStack(alignment: .leading, spacing: 12) {
                DialogGroup("Based On") {
                    Picker("Based On", selection: $basedOn) {
                        ForEach(TrimBasedOn.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
                DialogGroup("Trim Away") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            Toggle("Top", isOn: $trimTop)
                            Toggle("Left", isOn: $trimLeft)
                        }
                        GridRow {
                            Toggle("Bottom", isOn: $trimBottom)
                            Toggle("Right", isOn: $trimRight)
                        }
                    }
                }
            }
            .frame(width: 240)
        }
    }
}
