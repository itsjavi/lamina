import SwiftUI

/// The Gradient tool's bar: the gradient preset picker, Linear and Radial, Opacity and Reverse, then Cancel and Commit
/// while a gradient waits to be applied.
struct GradientControls: View {
    @Bindable var session: EditorSession
    @State private var choosesPreset = false

    var body: some View {
        OptionsBarRow(commit: commitButtons) {
            presetPicker
            HStack(spacing: 2) {
                ForEach(GradientShape.allCases, id: \.self) { shape in
                    OptionsBarIconButton(title: shape.rawValue + " Gradient", isPressed: session.gradientSettings.shape == shape,
                                         action: { session.gradientSettings.shape = shape }) {
                        GradientShapeIcon(shape: shape)
                    }
                }
            }
            .help("Linear runs along the line; Radial spreads out from the start point")
            OptionsBarDivider()
            PercentField(label: "Opacity", value: $session.gradientSettings.opacity)
                .help("Press 1–9 for 10–90%, 0 for 100%")
            Toggle("Reverse", isOn: $session.gradientSettings.reversed).toggleStyle(.checkbox)
            if session.isMaskSelected { Text("Mask").foregroundStyle(.secondary) }
        }
        .releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }

    private var commitButtons: OptionsBarCommitButtons? {
        guard session.gradientEdit != nil else { return nil }
        return OptionsBarCommitButtons(cancelTitle: "Cancel Gradient (Escape)", commitTitle: "Commit Gradient (Return)",
                                       cancel: { session.cancelGradient() }, commit: { Task { await session.commitGradient() } })
    }

    /// The gradient as it will draw, and a pop-over of the presets: Foreground to Background, Foreground to Transparent.
    private var presetPicker: some View {
        Button { choosesPreset.toggle() } label: {
            HStack(spacing: 3) {
                GradientSwatch(colors: session.gradientColors(mask: false).map { Color(cgColor: $0) })
                    .frame(width: 56, height: 18)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Gradient: " + session.gradientSettings.style.rawValue)
        .accessibilityLabel("Gradient, " + session.gradientSettings.style.rawValue)
        .accessibilityIdentifier("gradientPreset")
        .popover(isPresented: $choosesPreset, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(GradientStyle.allCases, id: \.self) { style in
                    Button {
                        session.gradientSettings.style = style
                        choosesPreset = false
                    } label: {
                        HStack(spacing: 8) {
                            GradientSwatch(colors: colors(style)).frame(width: 56, height: 18)
                            Text(style.rawValue)
                            Spacer(minLength: 0)
                        }
                        .padding(4)
                        .background(session.gradientSettings.style == style ? ColorRole.selection.color : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(session.gradientSettings.style == style ? .isSelected : [])
                }
            }
            .padding(8).frame(width: 260)
        }
    }

    /// A preset's colors from the swatches, as it would draw unreversed.
    private func colors(_ style: GradientStyle) -> [Color] {
        let foreground = Color(nsColor: session.paletteColor(background: false).nsColor)
        return style == .foregroundToBackground
            ? [foreground, Color(nsColor: session.paletteColor(background: true).nsColor)]
            : [foreground, foreground.opacity(0)]
    }
}

/// Gradient colors over a checkerboard, so transparency reads as transparency.
struct GradientSwatch: View {
    let colors: [Color]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        Canvas { context, size in
            let tile: CGFloat = 4
            for row in 0..<Int(ceil(size.height / tile)) {
                for column in 0..<Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)),
                                 with: .color(.gray.opacity(0.45)))
                }
            }
        }
        .background(.white)
        .overlay { LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing) }
        .clipShape(shape)
        .overlay { shape.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

/// Linear and Radial as icons: a square fading across, or out from its middle, in the icon's one color.
struct GradientShapeIcon: View {
    let shape: GradientShape

    var body: some View {
        let frame = RoundedRectangle(cornerRadius: 2.5, style: .continuous)
        let ink = ColorRole.icon.color
        Group {
            switch shape {
            case .linear: frame.fill(LinearGradient(colors: [ink, ink.opacity(0)], startPoint: .leading, endPoint: .trailing))
            case .radial: frame.fill(RadialGradient(colors: [ink, ink.opacity(0)], center: .center, startRadius: 0, endRadius: 8))
            }
        }
        .overlay { frame.strokeBorder(ink, lineWidth: 1.2) }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

/// One-color tool-rail icon: a Floyd–Steinberg dithered fade from empty to solid, so it
/// reads as a gradient in the same monochrome style as the SF Symbols beside it.
struct GradientToolIcon: View {
    /// 16×16 so each dot is exactly 1 pt inside the icon's 16 pt frame.
    private static let pattern: [[Bool]] = {
        let size = 16
        var ramp = (0..<size).map { _ in (0..<size).map { CGFloat($0) / CGFloat(size - 1) } }
        var result = Array(repeating: Array(repeating: false, count: size), count: size)
        for y in 0..<size {
            for x in 0..<size {
                let on = ramp[y][x] >= 0.5
                result[y][x] = on
                let error = ramp[y][x] - (on ? 1 : 0)
                if x + 1 < size { ramp[y][x + 1] += error * 7 / 16 }
                guard y + 1 < size else { continue }
                if x > 0 { ramp[y + 1][x - 1] += error * 3 / 16 }
                ramp[y + 1][x] += error * 5 / 16
                if x + 1 < size { ramp[y + 1][x + 1] += error / 16 }
            }
        }
        return result
    }()
    var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let shape = Path(roundedRect: frame, cornerRadius: 3.5)
            let cell = frame.width / CGFloat(Self.pattern.count)
            var dots = Path()
            for (row, line) in Self.pattern.enumerated() {
                for (column, on) in line.enumerated() where on {
                    dots.addRect(CGRect(x: frame.minX + CGFloat(column) * cell, y: frame.minY + CGFloat(row) * cell,
                                        width: cell, height: cell))
                }
            }
            context.clip(to: shape)
            context.fill(dots, with: .foreground)
            context.stroke(shape, with: .foreground, lineWidth: 1.4)
        }
        .accessibilityHidden(true)
    }
}
