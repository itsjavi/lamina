import SwiftUI
import LaminaCore

struct LevelsSheet: View {
    @Bindable var session: EditorSession
    private var edit: LevelsEdit? { session.levels }
    private var settings: LevelsSettings { edit?.settings ?? LevelsSettings() }
    private var current: LevelRange { settings.current }
    private func update(_ change: (inout LevelsSettings) -> Void) {
        var value = settings; change(&value)
        session.updateLevels(value, preview: edit?.preview ?? true)
    }
    private func value(_ key: WritableKeyPath<LevelRange, Double>) -> Binding<Double> {
        Binding(get: { current[keyPath: key] }, set: { newValue in
            update { var range = $0.current; range[keyPath: key] = newValue; $0.current = range }
        })
    }
    var body: some View {
        DialogLayout(preview: Binding(get: { edit?.preview ?? true }, set: { session.updateLevels(settings, preview: $0) }),
                     status: edit?.committing == true ? "Applying…" : nil,
                     confirm: { Task { await session.commitLevels() } }, cancel: { session.cancelLevels() }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Channel:")
                    Picker("Channel", selection: Binding(get: { settings.channel }, set: { channel in update { $0.channel = channel } })) {
                        ForEach(LevelsChannel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                Text("Input Levels:").padding(.top, 4)
                VStack(spacing: 0) {
                    histogram.frame(height: 130).background(ColorRole.field.color)
                        .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
                        .overlay(alignment: .topLeading) {
                            if edit?.histogramReady != true { Text("Loading histogram…").font(.caption).padding(8) }
                        }
                    handles(output: false).frame(height: 20)
                }
                HStack {
                    field("Input black", value(\.black), decimals: 0)
                    Spacer()
                    field("Gamma", value(\.gamma), decimals: 2)
                    Spacer()
                    field("Input white", value(\.white), decimals: 0)
                }
                Text("Output Levels:").padding(.top, 6)
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing).frame(height: 14)
                        .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
                    handles(output: true).frame(height: 20)
                }
                HStack {
                    field("Output black", value(\.outputBlack), decimals: 0)
                    Spacer()
                    field("Output white", value(\.outputWhite), decimals: 0)
                }
                // Lamina's own: what the eyedroppers do and what the histogram counts.
                if let mode = edit?.sampleMode {
                    Text("Click the original layer to set the \(mode.rawValue.lowercased()) point. Click the eyedropper again to stop.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Text(session.adjustmentOriginal != nil ? "Underlying pixels · alpha-weighted histogram" : session.selection == nil ? "Original pixels · alpha-weighted histogram" : "Original pixels · selection and alpha-weighted histogram")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 300)
        } extras: {
            // Auto applies the contrast stretch, as Photoshop's Auto does; its menu offers Lamina's other methods.
            Menu {
                ForEach(LevelsAuto.allCases, id: \.self) { mode in
                    Button(mode.rawValue) { session.autoLevels(mode) }
                }
            } label: { Text("Auto") } primaryAction: { session.autoLevels(.contrast) }
                .frame(maxWidth: .infinity)
                .disabled(edit?.histogramReady != true)
                .help("Stretch the tones to fill the range. Hold the arrow for other methods.")
            DialogButton("Reset") { edit?.sampleMode = nil; update { $0 = LevelsSettings() } }
            HStack(spacing: 4) {
                ForEach(LevelsSample.allCases, id: \.self) { mode in
                    Button {
                        edit?.sampleMode = edit?.sampleMode == mode ? nil : mode
                        session.brushRevision += 1
                    } label: { eyedropper(mode) }
                    .buttonStyle(.plain)
                    .background(edit?.sampleMode == mode ? ColorRole.activeTool.color : .clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .help("Sample in image to set the \(mode.rawValue.lowercased()) point")
                    .accessibilityLabel("Set \(mode.rawValue) Point")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .disabled(edit?.committing == true)
    }
    /// Photoshop's black, gray and white point eyedroppers: the dropper filled with the tone it sets.
    private func eyedropper(_ mode: LevelsSample) -> some View {
        let tone: Color = switch mode { case .black: .black; case .gray: .gray; case .white: .white }
        return ZStack {
            Image(systemName: "eyedropper.full").foregroundStyle(tone)
            Image(systemName: "eyedropper").foregroundStyle(ColorRole.icon.color)
        }
        .frame(width: 26, height: 22)
    }
    /// A level's exact value under its slider, as Photoshop's: the handle above it is what drags.
    private func field(_ name: String, _ binding: Binding<Double>, decimals: Int) -> some View {
        TextField(name, value: binding, format: .number.precision(.fractionLength(decimals)))
            .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 56)
            .help(name)
            .accessibilityIdentifier("levels\(name.replacingOccurrences(of: " ", with: ""))")
    }
    private var histogram: some View {
        Canvas { context, size in
            let bins = edit?.histogram[settings.channel.index] ?? Array(repeating: 0, count: 256)
            let peak = LevelsHistogramDisplay.scale(for: bins)
            guard peak > 0 else { return }
            var path = Path()
            for index in 0..<256 {
                let height = size.height * min(1, max(0, bins[index] / peak))
                path.addRect(CGRect(x: CGFloat(index) * size.width / 256, y: size.height - height,
                                    width: size.width / 256 + 0.1, height: height))
            }
            let color: Color = switch settings.channel { case .rgb: ColorRole.secondaryText.color; case .red: .red; case .green: .green; case .blue: .blue }
            context.fill(path, with: .color(color))
        }.accessibilityLabel("Original \(settings.channel.rawValue) histogram")
        .help("Linear histogram with automatic vertical scaling. Tall spikes may extend beyond the graph; all tones from 0 to 255 remain included.")
    }
    private func handles(output: Bool) -> some View {
        GeometryReader { geometry in
            let gammaPosition = current.black + (current.white - current.black) * pow(0.5, current.gamma)
            let positions = output ? [current.outputBlack, current.outputWhite] : [current.black, gammaPosition, current.white]
            ForEach(positions.indices, id: \.self) { index in
                let names = output ? ["Output black", "Output white"] : ["Input black", "Gamma", "Input white"]
                Image(systemName: "triangle.fill").font(.system(size: 12))
                    .foregroundStyle(index == 0 ? Color.black : index == positions.count - 1 ? .white : .gray)
                    .shadow(color: .gray, radius: 0.5)
                    .frame(width: 22, height: 20).contentShape(Rectangle())
                    .position(x: positions[index] / 255 * geometry.size.width, y: 9)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(output ? "levelsOutput" : "levelsInput"))
                        .onChanged { drag in
                            let x = min(255, max(0, drag.location.x / geometry.size.width * 255))
                            update {
                                var range = $0.current
                                if output {
                                    if index == 0 { range.outputBlack = x.rounded() } else { range.outputWhite = x.rounded() }
                                } else if index == 0 { range.black = min(range.white - 1, x.rounded()) }
                                else if index == 2 { range.white = max(range.black + 1, x.rounded()) }
                                else {
                                    let fraction = min(0.999, max(0.001, (x - range.black) / (range.white - range.black)))
                                    range.gamma = log(fraction) / log(0.5)
                                }
                                $0.current = range
                            }
                        })
                    .accessibilityLabel(names[index])
            }
        }.coordinateSpace(name: output ? "levelsOutput" : "levelsInput")
    }
}
