import SwiftUI
import LaminaCore

/// Edit › Fill…: the selection, or the whole layer or mask without one, filled with a color, Content-Aware or a gray,
/// at an opacity, as Photoshop's Fill dialog has it.
struct FillSheet: View {
    let session: EditorSession
    @State private var options: FillOptions
    /// Content-Aware Fill needs a selection on an image's pixels.
    private let contentAware: Bool

    init(session: EditorSession) {
        self.session = session
        _options = State(initialValue: session.fillOptions)
        contentAware = session.canContentAwareFill
    }

    private var opacity: Binding<Int> {
        Binding(get: { Int((options.opacity * 100).rounded()) }, set: { options.opacity = Double(min(100, max(1, $0))) / 100 })
    }

    var body: some View {
        DialogLayout(confirm: { Task { await session.finishFill(options) } },
                     cancel: { Task { await session.finishFill(nil) } }) {
            VStack(alignment: .leading, spacing: 12) {
                DialogRow("Contents:", labelWidth: 64) {
                    Picker("Contents", selection: $options.contents) {
                        ForEach(FillContents.allCases, id: \.self) { contents in
                            Text(contents.rawValue).tag(contents)
                                .disabled(contents == .contentAware && !contentAware)
                        }
                    }
                    .labelsHidden().fixedSize()
                    if options.contents == .color {
                        DialogColorSwatch(title: "Fill Color", color: $options.color, session: session)
                    }
                }
                DialogGroup("Blending") {
                    DialogRow("Opacity:", labelWidth: 56) {
                        TextField("Opacity", value: opacity, format: .number)
                            .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        Text("%").scrubbable(sensitivity: 1, value: opacity, range: 1...100)
                    }
                }
                // Content-Aware Fill has its own dialog, with its own preview, where it is applied.
                .disabled(options.contents == .contentAware)
            }
            .frame(width: 280, alignment: .leading)
        }
        // Choosing Color… asks for the color straight away, as in Photoshop.
        .onChange(of: options.contents) { _, contents in
            guard contents == .color else { return }
            let color = $options.color
            session.openDialogColorPicker(title: "Fill Color", color: options.color) { color.wrappedValue = $0 }
        }
        .onDisappear { DialogColorSwatch.closePicker(session) }
    }
}
