import SwiftUI
import LaminaCore

/// Layer › Lock Layers… (⌘/): Photoshop's Lock dialog for the selected layers. Transparency is in progress (TASK-93);
/// Prevent auto-nest is left out, as Lamina has no artboards or frames.
struct LockLayersSheet: View {
    let session: EditorSession
    @State private var locks: LayerLocks

    init(session: EditorSession) {
        self.session = session
        _locks = State(initialValue: session.commonLocks)
    }

    var body: some View {
        DialogLayout(confirm: { session.finishLockLayers(locks) }, cancel: { session.finishLockLayers(nil) }) {
            DialogGroup("Lock") {
                Toggle("Transparency", isOn: Binding(get: { false }, set: { _ in session.showInProgress(.lockTransparentPixels) }))
                    .help(PlannedFeature.lockTransparentPixels.helpTag)
                Toggle("Image", isOn: lock(.imagePixels))
                Toggle("Position", isOn: lock(.position))
                Toggle("All", isOn: lock(.all))
            }
            .frame(width: 200, alignment: .leading)
        }
    }

    private func lock(_ lock: LayerLock) -> Binding<Bool> {
        Binding(get: { lock.isOn(in: locks) }, set: { lock.set($0, in: &locks) })
    }
}
