import SwiftUI
import LaminaCore

/// Layer ▸ Layer Style: Blending Options and every effect listed on the left, each effect with its checkbox; the
/// selected page's settings in the middle; OK, Cancel, Preview and a swatch of the style on the right
/// (docs/DESIGN.md, Dialogs). Every change previews on the canvas; OK applies them as one step.
struct LayerStyleDialog: View {
    @Bindable var session: EditorSession

    static let listWidth: CGFloat = 170
    static let pageWidth: CGFloat = 372
    /// Tall enough for the longest page, so the dialog keeps its size as pages change.
    static let height: CGFloat = 262
    private static let labelWidth: CGFloat = 70

    var body: some View {
        if let edit = session.layerStyle {
            DialogLayout(confirm: { session.finishLayerStyle(commit: true) },
                         cancel: { session.finishLayerStyle(commit: false) }) {
                HStack(alignment: .top, spacing: 14) {
                    list(edit)
                    Divider()
                    page(edit).frame(width: Self.pageWidth, alignment: .topLeading)
                }
                .frame(height: Self.height, alignment: .top)
            } extras: {
                DialogPreviewToggle(isOn: Binding(get: { edit.preview }, set: { session.setLayerStylePreview($0) }))
                    .padding(.top, 4)
                LayerStyleSwatch(values: edit.preview ? edit.working : edit.original).padding(.top, 2)
            }
            // The picker previews its working color on the layer while it is open.
            .onChange(of: session.colorPicker?.color) { _, _ in session.previewEffectColor() }
        }
    }

    // MARK: - List

    private func list(_ edit: LayerStyleEdit) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(LayerStylePage.all, id: \.self) { page in
                row(page, edit: edit)
                if page == .blendingOptions { Divider().padding(.vertical, 4) }
            }
        }
        .frame(width: Self.listWidth, alignment: .topLeading)
    }

    private func row(_ page: LayerStylePage, edit: LayerStyleEdit) -> some View {
        let selected = edit.page == page
        return HStack(spacing: 6) {
            if let kind = page.kind {
                Toggle(kind.rawValue, isOn: Binding(get: { edit.working.effects.isEnabled(kind) },
                                                    set: { session.setLayerStyleEffect(kind, enabled: $0) }))
                    .toggleStyle(.checkbox).labelsHidden()
            }
            // The name selects the page; the checkbox only turns the effect on or off, as in Photoshop.
            HStack(spacing: 0) {
                Text(page.title).fontWeight(page == .blendingOptions ? .semibold : .regular)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { session.selectLayerStylePage(page) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { session.selectLayerStylePage(page) }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(selected ? ColorRole.selection.color : .clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Pages

    private func page(_ edit: LayerStyleEdit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(edit.page.title).font(.system(size: 13, weight: .semibold))
            switch edit.page {
            case .blendingOptions: blendingOptions(edit.working)
            case .effect(let kind): effect(kind, edit.working.effects)
            }
        }
    }

    @ViewBuilder private func blendingOptions(_ values: LayerStyleValues) -> some View {
        DialogGroup("General Blending") {
            DialogRow("Blend Mode:", labelWidth: Self.labelWidth) {
                Picker("Blend Mode", selection: Binding(get: { values.blendMode },
                                                        set: { mode in session.changeLayerStyle { $0.blendMode = mode } })) {
                    ForEach(LayerBlendMode.groups.indices, id: \.self) { group in
                        if group > 0 { Divider() }
                        ForEach(LayerBlendMode.groups[group], id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                .labelsHidden().fixedSize()
            }
            percent("Opacity:", values.opacity) { value in session.changeLayerStyle { $0.opacity = value } }
        }
    }

    @ViewBuilder private func effect(_ kind: LayerEffectKind, _ effects: LayerEffects) -> some View {
        switch kind {
        case .stroke:
            if let stroke = effects.stroke {
                DialogGroup("Structure") {
                    pixels("Size:", stroke.size, slider: 0...50, limit: StrokeEffect.maxSize) { value in
                        session.changeLayerStyle { $0.effects.stroke?.size = value }
                    }
                    DialogRow("Position:", labelWidth: Self.labelWidth) {
                        Picker("Position", selection: Binding(get: { stroke.inside }, set: { inside in
                            session.changeLayerStyle { $0.effects.stroke?.inside = inside }
                        })) {
                            Text("Outside").tag(false)
                            Text("Inside").tag(true)
                        }
                        .labelsHidden().fixedSize()
                    }
                    percent("Opacity:", stroke.opacity) { value in session.changeLayerStyle { $0.effects.stroke?.opacity = value } }
                    colorRow(kind)
                }
            }
        case .innerShadow:
            if let shadow = effects.innerShadow {
                DialogGroup("Structure") {
                    percent("Opacity:", shadow.opacity) { value in session.changeLayerStyle { $0.effects.innerShadow?.opacity = value } }
                    angle(shadow.angle) { value in session.changeLayerStyle { $0.effects.innerShadow?.angle = value } }
                    pixels("Distance:", shadow.distance, slider: 0...50, limit: 5000) { value in
                        session.changeLayerStyle { $0.effects.innerShadow?.distance = value }
                    }
                    pixels("Size:", shadow.blur, slider: 0...100, limit: 500) { value in
                        session.changeLayerStyle { $0.effects.innerShadow?.blur = value }
                    }
                    colorRow(kind)
                }
            }
        case .innerGlow:
            if let glow = effects.innerGlow {
                DialogGroup("Structure") {
                    percent("Opacity:", glow.opacity) { value in session.changeLayerStyle { $0.effects.innerGlow?.opacity = value } }
                    colorRow(kind)
                }
                DialogGroup("Elements") {
                    pixels("Size:", glow.size, slider: 0...100, limit: 500) { value in
                        session.changeLayerStyle { $0.effects.innerGlow?.size = value }
                    }
                }
            }
        case .colorOverlay:
            if let overlay = effects.colorOverlay {
                DialogGroup("Color") {
                    colorRow(kind)
                    percent("Opacity:", overlay.opacity) { value in session.changeLayerStyle { $0.effects.colorOverlay?.opacity = value } }
                }
            }
        case .outerGlow:
            if let glow = effects.outerGlow {
                DialogGroup("Structure") {
                    percent("Opacity:", glow.opacity) { value in session.changeLayerStyle { $0.effects.outerGlow?.opacity = value } }
                    colorRow(kind)
                }
                DialogGroup("Elements") {
                    pixels("Size:", glow.size, slider: 0...100, limit: 500) { value in
                        session.changeLayerStyle { $0.effects.outerGlow?.size = value }
                    }
                }
            }
        case .shadow:
            if let shadow = effects.shadow {
                DialogGroup("Structure") {
                    percent("Opacity:", shadow.opacity) { value in session.changeLayerStyle { $0.effects.shadow?.opacity = value } }
                    angle(shadow.angle) { value in session.changeLayerStyle { $0.effects.shadow?.angle = value } }
                    pixels("Distance:", shadow.distance, slider: 0...100, limit: 5000) { value in
                        session.changeLayerStyle { $0.effects.shadow?.distance = value }
                    }
                    pixels("Size:", shadow.blur, slider: 0...100, limit: 500) { value in
                        session.changeLayerStyle { $0.effects.shadow?.blur = value }
                    }
                    colorRow(kind)
                }
            }
        }
    }

    // MARK: - Rows

    /// A 0–1 setting shown as a percentage.
    private func percent(_ label: String, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        slider(label, value * 100, slider: 0...100, limit: 0...100, unit: "%") { set($0 / 100) }
    }

    private func pixels(_ label: String, _ value: CGFloat, slider range: ClosedRange<Double>, limit: CGFloat,
                        set: @escaping (CGFloat) -> Void) -> some View {
        slider(label, Double(value), slider: range, limit: 0...Double(limit), unit: "px") { set(CGFloat($0)) }
    }

    /// A slider, its exact field and its unit. A typed value past the slider's end is kept (up to `limit`); the
    /// knob just waits at the end.
    private func slider(_ label: String, _ value: Double, slider range: ClosedRange<Double>, limit: ClosedRange<Double>,
                        unit: String, set: @escaping (Double) -> Void) -> some View {
        let name = String(label.dropLast())
        let change: (Double) -> Void = { amount in
            guard amount.isFinite else { return }
            set(min(limit.upperBound, max(limit.lowerBound, amount.rounded())))
        }
        return DialogRow(label, labelWidth: Self.labelWidth) {
            Slider(value: Binding(get: { min(range.upperBound, max(range.lowerBound, value)) }, set: change), in: range)
                .frame(width: 170).accessibilityLabel(name)
            TextField(name, value: Binding(get: { value }, set: change), format: .number.precision(.fractionLength(0)))
                .frame(width: 52).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .arrowSteps(value: { value }, change: change)
            Text(unit).frame(width: 22, alignment: .leading)
                .scrubbable(sensitivity: 1, value: Binding(get: { value }, set: change), range: limit)
        }
    }

    /// Photoshop's Angle: a dial pointing where the light comes from, and the exact degrees.
    private func angle(_ value: CGFloat, set: @escaping (CGFloat) -> Void) -> some View {
        let change: (Double) -> Void = { amount in
            guard amount.isFinite else { return }
            // Kept in -180…180, the dial's own range, whatever was typed.
            var degrees = amount.rounded().truncatingRemainder(dividingBy: 360)
            if degrees > 180 { degrees -= 360 } else if degrees < -180 { degrees += 360 }
            set(CGFloat(degrees))
        }
        return DialogRow("Angle:", labelWidth: Self.labelWidth) {
            AngleDial(degrees: Double(value), change: change)
            TextField("Angle", value: Binding(get: { Double(value) }, set: change), format: .number.precision(.fractionLength(0)))
                .frame(width: 52).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .arrowSteps(value: { Double(value) }, change: change)
            Text("°").frame(width: 22, alignment: .leading)
        }
    }

    /// The effect's color well, opened in the app's own picker.
    private func colorRow(_ kind: LayerEffectKind) -> some View {
        let color = session.layerStyle?.working.effects.color(kind) ?? .black
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        return DialogRow("Color:", labelWidth: Self.labelWidth) {
            Button { session.openEffectColorPicker(kind) } label: {
                shape.fill(Color(.sRGB, red: Double(color.red), green: Double(color.green), blue: Double(color.blue)))
                    .overlay { shape.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                    .frame(width: 44, height: 20)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help("Choose the \(kind.rawValue.lowercased()) color")
            .accessibilityLabel(kind.rawValue + " color")
        }
    }
}

/// A round dial for an angle in degrees, counterclockwise from the right as Photoshop's is: the line points at the
/// light. Dragging anywhere in it sets the angle.
struct AngleDial: View {
    let degrees: Double
    let change: (Double) -> Void
    static let size: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let circle = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
            context.fill(circle, with: .color(ColorRole.field.color))
            context.stroke(circle, with: .color(ColorRole.edge.color), lineWidth: 1)
            let radians = degrees * .pi / 180, reach = size.width / 2 - 3
            var line = Path()
            line.move(to: center)
            line.addLine(to: CGPoint(x: center.x + cos(radians) * reach, y: center.y - sin(radians) * reach))
            context.stroke(line, with: .color(ColorRole.text.color), lineWidth: 1.5)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)),
                         with: .color(ColorRole.text.color))
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            let dx = drag.location.x - Self.size / 2, dy = Self.size / 2 - drag.location.y
            guard dx * dx + dy * dy >= 4 else { return }
            change(atan2(dy, dx) * 180 / .pi)
        })
        .help("Drag to set the angle of the light")
        .accessibilityElement()
        .accessibilityLabel("Angle")
        .accessibilityValue("\(Int(degrees)) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(degrees + 1)
            case .decrement: change(degrees - 1)
            @unknown default: break
            }
        }
    }
}

/// The Layer Style dialog's swatch: its style drawn on a sample square, the sizes scaled down when they would
/// overflow the swatch, so every effect stays readable.
struct LayerStyleSwatch: View {
    let values: LayerStyleValues
    static let height: CGFloat = 64
    /// Points the effects may reach past the square on each side.
    private static let room: CGFloat = 12
    /// Drawn at twice the points, for Retina screens.
    private static let scale: CGFloat = 2
    private static let sample: CGImage? = {
        let side = Int(32 * scale)
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0.73, green: 0.73, blue: 0.73, alpha: 1))
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: 6, cornerHeight: 6,
                               transform: nil))
        context.fillPath()
        return context.makeImage()
    }()

    var body: some View {
        ZStack {
            Rectangle().fill(.white)
            if let image = Self.image(for: values.effects) {
                Image(decorative: image, scale: Self.scale).opacity(values.opacity)
            }
        }
        .frame(maxWidth: .infinity).frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(ColorRole.edge.color, lineWidth: 1) }
        .accessibilityHidden(true)
    }

    static func image(for effects: LayerEffects) -> CGImage? {
        guard let sample else { return nil }
        let margin = LayerEffectsRenderer.margin(for: effects)
        let fit = min(1, room / max(1, margin))
        return LayerEffectsRenderer.cached(sample, mask: nil, effects: effects.scaled(by: fit * scale))?.image ?? sample
    }
}
