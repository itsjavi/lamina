import SwiftUI

/// The Layers panel's top row, as familiar editors lay it out: the blend mode menu, as wide as the row allows, then
/// "Opacity:" and its field, whose chevron pops up a slider. Dragging the label scrubs the opacity too.
struct LayerAppearanceControls: View {
    @Bindable var session: EditorSession
    let layerID: UUID?
    @State private var percentage = "100%"
    @State private var stepper = ArrowStepper()
    @State private var showsSlider = false
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 6) {
            BlendModePicker(session: session)
                .frame(maxWidth: .infinity)
                .disabled(!session.canEditAppearance)
            HStack(spacing: 4) {
                Text("Opacity:").foregroundStyle(.secondary)
                    .scrubbable(sensitivity: 1,
                                value: Binding<Double>(get: { (session.activeLayer?.opacity ?? 1) * 100 }, set: step),
                                range: 0...100,
                                onStart: { session.beginOpacityEdit() },
                                onEnd: { session.finishOpacityEdit() })
                HStack(spacing: 0) {
                    TextField("Opacity", text: $percentage)
                        .textFieldStyle(.roundedBorder).frame(width: 48).focused($focused)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { releaseFocus() }
                        .onExitCommand { releaseFocus() }
                        .onChange(of: focused) { _, isFocused in if !isFocused { applyPercentage() } }
                        .arrowSteps(editing: focused, stepper: stepper,
                                    value: { ((session.activeLayer?.opacity ?? 1) * 100).rounded() },
                                    change: { step($0) })
                    Button { showsSlider.toggle() } label: {
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                            .frame(width: 14, height: 22).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(ColorRole.icon.color)
                    .help("Opacity slider").accessibilityLabel("Opacity slider")
                    .popover(isPresented: $showsSlider, arrowEdge: .bottom) {
                        Slider(value: Binding(get: { session.activeLayer?.opacity ?? 1 },
                                              set: { session.setLayerOpacity($0) }), in: 0...1,
                               onEditingChanged: { if $0 { session.beginOpacityEdit() } else { session.finishOpacityEdit() } })
                            .labelsHidden().frame(width: 160).padding(12)
                            .accessibilityLabel("Opacity")
                    }
                }
            }
            .disabled(!session.canEditOpacity)
        }
        .font(.system(size: 12)).monospacedDigit()
        .padding(.horizontal, 8).padding(.vertical, 6)
        .onAppear { sync() }
        .onChange(of: session.activeLayer?.opacity) { _, _ in if !focused { sync() } }
        .onDisappear { session.finishOpacityEdit() }
    }
    /// Up and Down nudge the opacity by one percent, or ten with Shift.
    private func step(_ percent: Double) {
        guard session.activeLayerID == layerID else { return }
        session.setLayerOpacity(min(100, max(0, percent)) / 100)
        sync()
    }
    /// Losing focus applies the value; the canvas takes the focus back so a tool's key works straight away.
    private func releaseFocus() {
        focused = false
        session.canvasFocusRequest += 1
    }
    private func sync() { percentage = String(Int(((session.activeLayer?.opacity ?? 1) * 100).rounded())) + "%" }
    /// Takes "40", "40%" or "40 %".
    private func applyPercentage() {
        guard session.activeLayerID == layerID else { return }
        let typed = percentage.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(typed), value.isFinite { session.setLayerOpacity(min(100, max(0, value)) / 100) }
        sync()
    }
}
