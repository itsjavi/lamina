import SwiftUI

/// The Hand and Zoom tools' bar: 100%, Fit Screen and Fill Screen, after Zoom In, Zoom Out and Scrubby Zoom for the
/// Zoom tool. The zoom field lives in the status bar.
struct NavigationToolHeader: View {
    @Bindable var session: EditorSession

    var body: some View {
        OptionsBarRow {
            if session.tool == .zoom {
                HStack(spacing: 2) {
                    OptionsBarIconButton(title: "Zoom In", symbol: "plus.magnifyingglass", isPressed: !session.zoomToolZoomsOut) {
                        session.zoomToolZoomsOut = false
                    }
                    .accessibilityIdentifier("zoomIn")
                    OptionsBarIconButton(title: "Zoom Out", symbol: "minus.magnifyingglass", isPressed: session.zoomToolZoomsOut) {
                        session.zoomToolZoomsOut = true
                    }
                    .accessibilityIdentifier("zoomOut")
                }
                .help("What a click does; hold Option for the other")
                OptionsBarDivider()
                Toggle("Scrubby Zoom", isOn: $session.scrubbyZoom).toggleStyle(.checkbox)
                    .help("Drag right to zoom in and left to zoom out. Off, a drag zooms one step, as a click does.")
                    .accessibilityIdentifier("scrubbyZoom")
                OptionsBarDivider()
            }
            Group {
                Button("100%") { session.zoom(to: 1) }.help("Actual pixels (⌘1)")
                    .accessibilityIdentifier("actualPixels")
                Button("Fit Screen") { session.fit() }.help("Fit the canvas in the window (⌘0)")
                    .accessibilityIdentifier("fitCanvas")
                Button("Fill Screen") { session.fillScreen() }.help("Zoom so the canvas fills the window")
                    .accessibilityIdentifier("fillScreen")
            }
            .disabled(session.document == nil)
        }
        .disabled(session.showsBusy)
    }
}
