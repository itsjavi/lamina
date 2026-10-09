import SwiftUI

/// The Adjustments panel: adds adjustment layers, in the dock's top group beside Properties (docs/DESIGN.md, Dock and
/// panels). Until it lists them, it points to the menu that does.
struct AdjustmentsPanel: View {
    @Bindable var session: EditorSession

    var body: some View {
        DockEmptyState(symbol: "circle.lefthalf.filled", title: "Add an adjustment",
                       message: "Choose one from Layer › New Adjustment Layer.")
    }
}
