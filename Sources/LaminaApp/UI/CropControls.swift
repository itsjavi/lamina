import SwiftUI

/// The Crop tool's header. A view of its own because dragging the crop frame changes `cropRect` on
/// every mouse move: read here, only this bar re-renders, not the whole editor and its Layers panel.
struct CropControls: View {
    @Bindable var session: EditorSession
    var ratios: CustomCropRatios = .shared
    @State private var asksForRatio = false

    var body: some View {
        // Cancel and Apply sit by the ratio, where the eye already is, rather than across the bar; the size comes
        // after them, so its changing width never moves them.
        HStack(spacing: 14) {
            Picker("Ratio", selection: $session.cropRatioChoice) {
                ForEach(CropRatio.builtIn, id: \.self) { Text($0) }
                if !ratios.ratios.isEmpty {
                    Divider()
                    ForEach(ratios.ratios, id: \.self) { Text($0) }
                }
                Divider()
                Text(CropRatio.customTag).tag(CropRatio.customTag)
            }.frame(width: 170)
                .onChange(of: session.cropRatioChoice) { old, new in
                    // Custom… isn't a ratio: it asks for one, and the choice stays as it was until one is given.
                    if new == CropRatio.customTag { session.cropRatioChoice = old; asksForRatio = true }
                    else { session.changeCropRatio() }
                }
                .popover(isPresented: $asksForRatio, arrowEdge: .bottom) {
                    CustomCropRatioForm { width, height in
                        asksForRatio = false
                        session.useCustomCropRatio(width: width, height: height, remembering: ratios)
                    } cancel: { asksForRatio = false }
                }
            Button("Cancel") { session.cancelCrop() }.disabled(session.cropRect == nil)
            Button("Apply Crop") { Task { await session.commitCrop() } }
                .disabled(session.cropRect == nil)
            if let rect = session.cropRect {
                Text("\(Int(rect.width)) × \(Int(rect.height)) px").monospacedDigit()
            }
            Spacer()
        }.padding(.horizontal, 18).toolHeaderBar().disabled(session.showsBusy || session.document == nil)
    }
}

/// Custom…'s width and height, as Photoshop's crop bar takes them.
struct CustomCropRatioForm: View {
    let add: (Double, Double) -> Void
    let cancel: () -> Void
    // Text, not number fields: those only take a value on Return, so Add would stay dimmed until then.
    @State private var width = ""
    @State private var height = ""

    private var ratio: (Double, Double)? {
        func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
        guard let width = number(width), let height = number(height),
              CropRatio.text(width: width, height: height) != nil else { return nil }
        return (width, height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Ratio").font(.headline)
            HStack(spacing: 6) {
                TextField("W", text: $width).frame(width: 64)
                    .accessibilityLabel("Ratio width")
                Text(":")
                TextField("H", text: $height).frame(width: 64)
                    .accessibilityLabel("Ratio height")
            }
            .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Add") { if let ratio { add(ratio.0, ratio.1) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(ratio == nil)
            }
        }
        .padding(14)
        .frame(width: 210)
    }
}
