import SwiftUI

/// Select › Load Selection…: a layer's transparency or a mask as the selection, inverted or not, replacing it,
/// adding to it or taking from it, as Photoshop's Load Selection dialog has it.
struct LoadSelectionSheet: View {
    let session: EditorSession
    private let channels: [(channel: SelectionChannel, name: String)]
    private let hasSelection: Bool
    @State private var options: LoadSelectionOptions

    init(session: EditorSession, channels: [(channel: SelectionChannel, name: String)], initial: SelectionChannel) {
        self.session = session
        self.channels = channels
        hasSelection = session.selection?.isEmpty == false
        _options = State(initialValue: LoadSelectionOptions(channel: initial))
    }

    var body: some View {
        DialogLayout(confirm: { session.finishLoadSelection(options) }, cancel: { session.finishLoadSelection(nil) }) {
            VStack(alignment: .leading, spacing: 12) {
                DialogGroup("Source") {
                    DialogRow("Document:", labelWidth: 70) {
                        // Only the document in front: its own layers are the channels.
                        Picker("Document", selection: .constant(0)) { Text(session.documentName).tag(0) }
                            .labelsHidden().fixedSize().frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DialogRow("Channel:", labelWidth: 70) {
                        Picker("Channel", selection: $options.channel) {
                            ForEach(channels, id: \.channel) { Text($0.name).tag($0.channel) }
                        }
                        .labelsHidden().fixedSize().frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DialogRow("", labelWidth: 70) {
                        Toggle("Invert", isOn: $options.invert).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                DialogGroup("Operation") {
                    Picker("Operation", selection: $options.operation) {
                        Text("New Selection").tag(SelectionMode.replace)
                        Text("Add to Selection").tag(SelectionMode.add)
                        Text("Subtract from Selection").tag(SelectionMode.subtract)
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    // Adding to or taking from a selection needs one; without, New Selection is the only way.
                    .disabled(!hasSelection)
                }
            }
            .frame(width: 330, alignment: .leading)
        }
    }
}
