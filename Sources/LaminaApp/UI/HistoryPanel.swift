import SwiftUI

/// The undo steps by name, oldest first, as Photoshop's History panel lists them. Clicking one goes back or forward
/// to it; the steps after it stay, dimmed, until a new edit replaces them.
struct HistoryPanel: View {
    @Bindable var session: EditorSession
    /// The first row: the document before the oldest step kept.
    static let startName = "Initial State"

    var body: some View {
        let names = session.history.stepNames
        let position = session.history.position
        // The panel's name is on its tab (HistoryFlyout), so the steps start at the top.
        VStack(alignment: .leading, spacing: 0) {
            if session.document == nil && names.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 25, weight: .light))
                    Text("No history yet").font(.callout.weight(.medium))
                    Text("Each change to the project is listed here.")
                        .font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary).padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0...names.count, id: \.self) { index in
                                row(index == 0 ? Self.startName : names[index - 1], index: index, position: position)
                            }
                        }
                    }
                    .onAppear { proxy.scrollTo(position, anchor: .center) }
                    .onChange(of: position) { _, now in proxy.scrollTo(now, anchor: .center) }
                }
            }
            Divider()
            HStack(spacing: 0) {
                Button { session.undo() } label: { Image(systemName: "arrow.uturn.backward").footerHitArea() }
                    .help("Undo (⌘Z)").accessibilityLabel("Undo").disabled(!session.canUndo)
                Button { session.redo() } label: { Image(systemName: "arrow.uturn.forward").footerHitArea() }
                    .help("Redo (⇧⌘Z)").accessibilityLabel("Redo").disabled(!session.canRedo)
                Spacer()
                Text("\(names.count)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    .padding(.trailing, 6).help("Steps kept")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
    }

    /// A state: current is highlighted, those after it (what Redo would bring back) are dimmed.
    private func row(_ name: String, index: Int, position: Int) -> some View {
        Button { session.jumpToHistory(index) } label: {
            HStack(spacing: 8) {
                Image(systemName: index == position ? "circle.inset.filled" : "circle")
                    .font(.caption)
                    .foregroundStyle(index == position ? Color.accentColor : .secondary)
                Text(name).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .foregroundStyle(index > position ? .tertiary : .primary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(index == position ? ColorRole.selection.color : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!session.canUseHistory)
        .help(index == position ? "Where the project is now" : index == 0 ? "The project before the oldest step kept" : index > position ? "Redo up to this step" : "Go back to this step")
        .accessibilityLabel(index == 0 ? Self.startName : name)
        .accessibilityAddTraits(index == position ? .isSelected : [])
        .id(index)
    }
}
