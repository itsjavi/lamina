import SwiftUI
import LaminaCore

/// The bar that takes the Move bar's place while a layer, several layers or selected pixels are being transformed
/// (Edit ▸ Free Transform, ⌘T, a handle dragged, Edit ▸ Transform ▸ Distort): the reference point, X and Y, W and H
/// in percent, the angle and Interpolation, then Cancel and Commit. What it changes waits for Commit (Return) or
/// Cancel (Escape) with the rest of the transform, one undo step.
struct FreeTransformBar: View {
    @Bindable var session: EditorSession
    private var value: LayerTransform {
        session.transformEdit?.draft ?? LayerTransform(origin: .zero, size: CGSize(width: 1, height: 1))
    }
    private var reference: CGPoint { session.transformReference }
    /// What W and H measure against, 100%: the layer's pixels drawn 1:1 (a group's box when the edit began).
    private var pixelSize: CGSize { session.transformPixelSize ?? session.activeLayer?.size ?? value.size }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ReferencePointPicker(selection: $session.transformReference)
                    OptionsBarDivider()
                    TransformValueField(label: "X", suffix: "px", value: value.point(reference).x, range: -30_000...30_000,
                                        finish: session.finishTransformValues) { number in
                        change { $0 = $0.moving(reference, to: CGPoint(x: number, y: $0.point(reference).y)) }
                    }
                    TransformValueField(label: "Y", suffix: "px", value: value.point(reference).y, range: -30_000...30_000,
                                        finish: session.finishTransformValues) { number in
                        change { $0 = $0.moving(reference, to: CGPoint(x: $0.point(reference).x, y: number)) }
                    }
                    OptionsBarDivider()
                    TransformValueField(label: "W", suffix: "%", value: value.size.width / max(1, pixelSize.width) * 100,
                                        range: 0.1...100_000, finish: session.finishTransformValues) { resize(percent: $0, width: true) }
                    // Shift flips the link while dragging a handle, and the button shows it flipped.
                    Toggle(isOn: Binding(get: { session.locksTransformRatio != held.contains(.shift) },
                                         set: { session.locksTransformRatio = $0 != held.contains(.shift) })) {
                        Image(systemName: "link")
                    }
                        .toggleStyle(.button).buttonStyle(.borderless)
                        .help("Maintain aspect ratio. Hold Shift while dragging a handle to turn it the other way.")
                        .accessibilityLabel("Maintain Aspect Ratio")
                    TransformValueField(label: "H", suffix: "%", value: value.size.height / max(1, pixelSize.height) * 100,
                                        range: 0.1...100_000, finish: session.finishTransformValues) { resize(percent: $0, width: false) }
                    OptionsBarDivider()
                    TransformValueField(label: "Angle", symbol: "angle", suffix: "°", value: value.rotation, range: -360...360,
                                        finish: session.finishTransformValues) { number in
                        change { $0 = $0.rotated(to: number.truncatingRemainder(dividingBy: 360), about: reference) }
                    }
                    OptionsBarDivider()
                    Picker("Interpolation", selection: Binding(get: { value.sampling }, set: { sampling in
                        change { $0.sampling = sampling }
                    })) {
                        ForEach(LayerSampling.allCases, id: \.self) { Text($0.interpolationName).tag($0) }
                    }
                        .fixedSize()
                        .help("How the pixels are resampled where the layer is drawn larger, smaller or turned")
                }
                // The numbers describe an ordinary transform; while distorting, the corner handles are the controls.
                .disabled(session.transformEdit?.corners != nil)
                .padding(.horizontal, 12)
            }.scrollIndicators(.hidden)
            OptionsBarDivider()
            HStack(spacing: 4) {
                OptionsBarIconButton(title: "Cancel Transform (Escape)", symbol: "nosign") { session.cancelTransform() }
                    .configuredNativeShortcut(.escape)
                    .accessibilityIdentifier("cancelTransform")
                OptionsBarIconButton(title: "Commit Transform (Return)", symbol: "checkmark") { session.commitTransform() }
                    .configuredNativeShortcut(.return)
                    .accessibilityIdentifier("commitTransform")
            }.padding(.horizontal, 8)
        }.toolHeaderBar().releasesFocusOnCommit(session)
    }

    private var held: NSEvent.ModifierFlags { HeldModifiers.shared.flags }
    private func change(_ update: (inout LayerTransform) -> Void) { session.changeTransformValue(update) }
    /// W or H as a percentage of the pixels, keeping the reference point in place; linked, the other side follows.
    private func resize(percent: CGFloat, width: Bool) {
        change { value in
            let pixels = pixelSize
            var size = value.size
            if width {
                size.width = pixels.width * percent / 100
                if session.locksTransformRatio { size.height = value.size.height * size.width / value.size.width }
            } else {
                size.height = pixels.height * percent / 100
                if session.locksTransformRatio { size.width = value.size.width * size.height / value.size.height }
            }
            guard size.width >= 1, size.height >= 1 else { return }
            value = value.resized(to: size, keeping: reference)
        }
    }
}

/// The reference point, a 3 × 3 grid of the box's corners, edge middles and center: X and Y give that point's
/// position, and typed sizes and angles (and rotation drags) keep it where it is.
struct ReferencePointPicker: View {
    @Binding var selection: CGPoint

    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        cell(LayerTransform.referencePoints[row * 3 + column])
                    }
                }
            }
        }
        .help("Reference point: X and Y give its position, and sizes and angles keep it in place")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reference Point")
        .accessibilityIdentifier("transformReferencePoint")
    }

    private func cell(_ point: CGPoint) -> some View {
        let chosen = selection == point
        return Button { selection = point } label: {
            Rectangle()
                .fill(chosen ? ColorRole.text.color : ColorRole.field.color)
                .overlay(Rectangle().strokeBorder(ColorRole.secondaryText.color, lineWidth: 1))
                .frame(width: 5, height: 5)
                .frame(width: 7, height: 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.name(of: point))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// "Top Left", "Middle Right", "Center" and so on.
    static func name(of point: CGPoint) -> String {
        if point == LayerTransform.centerReference { return "Center" }
        let vertical = ["Top", "Middle", "Bottom"][Int((point.y * 2).rounded())]
        let horizontal = ["Left", "Center", "Right"][Int((point.x * 2).rounded())]
        return vertical + " " + horizontal
    }
}

/// A transform number: its label (or symbol), which can be dragged to change it, the field, and its unit.
struct TransformValueField: View {
    let label: String
    var symbol: String? = nil
    var suffix: String? = nil
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    /// Shown in place of 0, which the field then leaves empty: Leading's "Auto".
    var prompt: String? = nil
    /// The field is done with its value: a drag on its label let go, or the field left.
    let finish: () -> Void
    let change: (CGFloat) -> Void
    @State private var text = ""
    @State private var stepper = ArrowStepper()
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) } else { Text(label) }
            }
            .foregroundStyle(.secondary)
            .scrubbable(sensitivity: 1, value: Binding(get: { value }, set: { newValue in
                change(newValue)
                text = Self.formatted(Double(newValue))
            }), range: range, step: 1, onEnd: finish)
            TextField(label, text: $text, prompt: prompt.map { Text($0) })
                .textFieldStyle(.roundedBorder).focused($focused)
                .frame(width: 58)
                .accessibilityLabel(label)
                .accessibilityIdentifier("transform\(label)")
                .onAppear { sync() }
                .onChange(of: value) { if !focused { sync() } }
                .onChange(of: focused) { if !focused { finish(); sync() } }
                .onChange(of: text) {
                    if focused, let number = Double(text), number.isFinite { change(CGFloat(number)) }
                    else if focused, prompt != nil, text.trimmingCharacters(in: .whitespaces).isEmpty { change(0) }
                }
                // The field holds off syncing while it has focus, so as not to fight what is being typed; a step
                // is not typing, so it writes the number it applied.
                .arrowSteps(editing: focused, stepper: stepper, value: { Double(value) },
                            change: { stepped in
                                change(CGFloat(stepped))
                                text = Self.formatted(stepped)
                            })
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
    }
    private func sync() { text = prompt != nil && value == 0 ? "" : Self.formatted(Double(value)) }
    /// No trailing zeros on a whole number, two decimals otherwise.
    static func formatted(_ value: Double) -> String { NumberLabel.upToTwoDecimals(value) }
}
