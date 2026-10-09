import SwiftUI

/// The Crop tool's bar: the Ratio pop-up, its W ⇄ H and Clear, then Cancel and Commit while a crop is pending. A view
/// of its own because dragging the crop frame changes `cropRect` on every mouse move: read here, only this bar
/// re-renders, not the whole editor and its Layers panel.
struct CropControls: View {
    @Bindable var session: EditorSession
    var ratios: CustomCropRatios = .shared
    @State private var width = ""
    @State private var height = ""

    var body: some View {
        OptionsBarRow(commit: commitButtons) {
            Picker("Ratio", selection: $session.cropRatioChoice) {
                ForEach(CropRatio.builtIn, id: \.self) { Text(CropRatio.title($0)).tag($0) }
                if !ratios.ratios.isEmpty {
                    Divider()
                    ForEach(ratios.ratios, id: \.self) { Text($0).tag($0) }
                }
            }
            .labelsHidden().frame(width: 130)
            .help("Keep the crop to a ratio; Ratio leaves it free. Type your own in W and H.")
            .accessibilityIdentifier("cropRatio")
            .onChange(of: session.cropRatioChoice) {
                session.changeCropRatio()
                syncSides()
            }
            HStack(spacing: 4) {
                side("W", text: $width)
                OptionsBarIconButton(title: "Swap height and width", symbol: "arrow.left.arrow.right") {
                    session.swapCropRatio(remembering: ratios)
                }
                .disabled(session.cropRatioSides == nil)
                side("H", text: $height)
            }
            Button("Clear") { session.clearCropRatio() }
                .disabled(session.cropRatioChoice == "Free")
                .help("Clear the ratio, so the crop can take any shape")
            if let rect = session.cropRect {
                Text("\(Int(rect.width)) × \(Int(rect.height)) px").monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .disabled(session.showsBusy || session.document == nil)
        .onAppear { syncSides() }
    }

    /// Cancel ⊘ and Commit ✓ while a crop waits; Return and Escape do the same on the canvas.
    private var commitButtons: OptionsBarCommitButtons? {
        guard session.cropRect != nil else { return nil }
        return OptionsBarCommitButtons(cancelTitle: "Cancel Crop (Escape)", commitTitle: "Commit Crop (Return)",
                                       cancel: { session.cancelCrop() }, commit: { Task { await session.commitCrop() } })
    }

    /// One side of a typed ratio. Text, not a number field, so an empty side reads as no ratio rather than 0; both
    /// sides given and Return (or leaving the field) choose it.
    private func side(_ name: String, text: Binding<String>) -> some View {
        TextField(name, text: text, prompt: Text(name))
            .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
            .accessibilityLabel(name == "W" ? "Ratio width" : "Ratio height")
            .onSubmit { useTypedSides() }
            .onExitCommand { syncSides() }
    }

    private func useTypedSides() {
        func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
        guard let w = number(width), let h = number(height) else { return }
        session.useCustomCropRatio(width: w, height: h, remembering: ratios)
        syncSides()
        session.canvasFocusRequest += 1
    }

    private func syncSides() {
        let sides = session.cropRatioSides
        width = sides.map { NumberLabel.upToTwoDecimals($0.width) } ?? ""
        height = sides.map { NumberLabel.upToTwoDecimals($0.height) } ?? ""
    }
}
