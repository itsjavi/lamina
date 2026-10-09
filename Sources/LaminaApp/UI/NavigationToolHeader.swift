import SwiftUI

/// The Hand and Zoom tools' bar: 100%, Fit Screen and Fill Screen. The zoom field lives in the status bar.
struct NavigationToolHeader: View {
    @Bindable var session: EditorSession

    var body: some View {
        HStack(spacing: 8) {
            Button("100%") { session.zoom(to: 1) }.help("Actual pixels (⌘1)")
                .accessibilityIdentifier("actualPixels")
            Button("Fit Screen") { session.fit() }.help("Fit the canvas in the window (⌘0)")
                .accessibilityIdentifier("fitCanvas")
            Button("Fill Screen") { session.fillScreen() }.help("Zoom so the canvas fills the window")
                .accessibilityIdentifier("fillScreen")
            Spacer()
        }
        .disabled(session.document == nil || session.showsBusy)
        .padding(.horizontal, 18).toolHeaderBar()
    }
}
