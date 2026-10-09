import SwiftUI

/// The selection tools' bar: New, Add and Subtract, then each tool's settings in the order familiar editors give them
/// (docs/DESIGN.md, Options bars). Select ▸ Modify covers Expand, Contract and feathering an existing selection.
struct LassoControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        OptionsBarRow {
            SelectionModeButtons(session: session)
            OptionsBarDivider()
            switch session.tool {
            case .objectSelection: objectSelectionControls
            case .magicWand: wandControls
            default: outlineControls
            }
        }
        .releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }

    /// The marquees and lassos: the feather of the next outline, and its anti-aliasing.
    @ViewBuilder private var outlineControls: some View {
        OptionsBarField(label: "Feather", value: $session.selectionToolFeather, range: 0...250, unit: "px")
            .help("Soften the edge of the next selection you draw by this many pixels. Select ▸ Modify ▸ Feather… softens the one there is.")
            .accessibilityIdentifier("selectionFeather")
        antialias
    }

    /// Rectangles snap to whole pixels, so smoothing doesn't apply (as in familiar editors) and the box is dimmed.
    private var antialias: some View {
        Toggle("Anti-alias", isOn: Binding(get: { session.tool != .rectangularMarquee && session.selectionAntialiased },
                                           set: { session.selectionAntialiased = $0 }))
            .toggleStyle(.checkbox)
            .disabled(session.tool == .rectangularMarquee)
            .help(session.tool == .objectSelection ? "Smooth the detected object outline; turn off for the raw pixel mask"
                  : "Smooth selection edges; turn off for hard pixel edges")
    }

    /// Sample Size, Tolerance, Anti-alias, Contiguous, Sample All Layers, then Select Subject.
    @ViewBuilder private var wandControls: some View {
        OptionsBarPicker(label: "Sample Size", selection: $session.wandSettings.sampleSize) {
            ForEach(WandSampleSize.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .help("Match the clicked pixel, or the average of the pixels around it")
        OptionsBarField(label: "Tolerance", value: $session.wandSettings.tolerance, range: 0...255, width: 40)
            .help("How far each color channel (0–255) can differ from the clicked color and still be selected")
        antialias
        Toggle("Contiguous", isOn: $session.wandSettings.contiguous).toggleStyle(.checkbox)
            .help("Select only similar pixels connected to the one you click; off selects them everywhere")
        Toggle("Sample All Layers", isOn: $session.wandSettings.sampleAllLayers).toggleStyle(.checkbox)
            .help("Read colors from every visible layer as shown; off reads the active layer only")
        OptionsBarDivider()
        selectSubject
    }

    /// Sample All Layers and Lamina's edge offset, then Select Subject.
    @ViewBuilder private var objectSelectionControls: some View {
        Toggle("Sample All Layers", isOn: $session.objectSelectionSettings.sampleAllLayers).toggleStyle(.checkbox)
            .help("Analyze every visible layer as shown; off analyzes the active layer only")
        OptionsBarField(label: "Edge", value: $session.objectSelectionSettings.edgeOffset, range: -10...10, unit: "px", width: 40)
            .help("Positive values tighten the detected mask inward; negative values expand it outward")
        antialias
        OptionsBarDivider()
        selectSubject
    }

    /// Select ▸ Subject, in the bar where familiar editors offer it too; Shift and Option add and subtract as they do
    /// for a click.
    private var selectSubject: some View {
        Button("Select Subject") { Task { await session.selectSubject(mode: session.displayedSelectionMode) } }
            .disabled(!session.canSelectSubject)
            .help("Select the main subject of the image, as Select ▸ Subject does")
            .accessibilityIdentifier("selectSubject")
    }
}

/// New, Add to and Subtract from Selection. The held Shift or Option key (or an outline being drawn) shows pressed
/// for as long as it applies; clicking sets the mode the tool goes back to.
struct SelectionModeButtons: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SelectionMode.allCases, id: \.self) { mode in
                OptionsBarIconButton(title: mode.title, symbol: mode.symbol, isPressed: session.displayedSelectionMode == mode) {
                    session.selectionModeChoice = mode
                }
            }
        }
        .help("Hold Shift to add or Option to subtract for one outline")
    }
}

extension SelectionMode {
    /// The button's name, as familiar editors have it.
    var title: String {
        switch self {
        case .replace: "New Selection"
        case .add: "Add to Selection"
        case .subtract: "Subtract from Selection"
        }
    }

    var symbol: String {
        switch self {
        case .replace: "square"
        case .add: "plus.square"
        case .subtract: "minus.square"
        }
    }
}

/// Tool-rail icon for the Polygonal Lasso: the lasso's loop and rope drawn as straight segments, in the
/// line weight of the SF Symbols beside it.
struct PolygonalLassoToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 18
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            // Laid out like the SF Symbol lasso: a wide loop, a knot below its right side, a short rope.
            var loop = Path()
            loop.addLines([point(1.2, 7.0), point(4.0, 2.4), point(11.8, 1.8), point(16.8, 5.2), point(15.6, 10.4), point(7.0, 11.6)])
            loop.closeSubpath()
            var knot = Path()
            knot.addLines([point(8.9, 10.9), point(13.3, 10.5), point(11.6, 14.5)])
            knot.closeSubpath()
            var rope = Path()
            rope.addLines([point(11.6, 14.5), point(12.9, 17.3)])
            let style = StrokeStyle(lineWidth: 1.4 * unit, lineCap: .round, lineJoin: .round)
            for part in [loop, knot, rope] { context.stroke(part, with: .foreground, style: style) }
        }
        .accessibilityHidden(true)
    }
}

/// Select › Modify › Expand…, Contract… and Feather…: one amount in pixels, in the dialogs' shared layout.
struct SelectionAmountSheet: View {
    let session: EditorSession
    let operation: EditorSession.SelectionAmountOperation
    @State private var input: String
    @FocusState private var focused: Bool

    init(session: EditorSession, operation: EditorSession.SelectionAmountOperation) {
        self.session = session
        self.operation = operation
        let amount: Int
        switch operation {
        case .expand: amount = session.selectionExpandAmount
        case .contract: amount = session.selectionContractAmount
        case .feather: amount = session.selectionFeatherAmount
        }
        _input = State(initialValue: String(amount))
    }

    private var maximum: Int { operation == .feather ? 250 : 500 }
    private var amount: Int? {
        guard let value = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...maximum).contains(value) else { return nil }
        return value
    }

    /// Photoshop's names for the one setting.
    private var label: String {
        switch operation {
        case .expand: "Expand By:"
        case .contract: "Contract By:"
        case .feather: "Feather Radius:"
        }
    }

    var body: some View {
        DialogLayout(defaultDisabled: amount == nil,
                     confirm: { if let amount { session.confirmSelectionAmount(amount) } },
                     cancel: { session.selectionAmountOperation = nil }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(label)
                        .scrubbable(sensitivity: 1,
                                    value: Binding<Int>(get: { amount ?? 1 }, set: { input = String($0) }),
                                    range: 1...maximum)
                    TextField(label, text: $input)
                        .frame(width: 56).textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing).focused($focused)
                    Text("pixels")
                }
                Text("Enter a whole number from 1 to \(maximum) pixels.")
                    .font(.callout).foregroundStyle(.secondary)
                    .opacity(amount == nil ? 1 : 0)
            }
            .frame(width: 250, alignment: .leading)
        }
        .onAppear { focused = true }
    }
}

struct ObjectSelectionToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 18
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            let style = StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round, lineJoin: .round)
            for corners in [
                [point(2, 6), point(2, 2), point(6, 2)],
                [point(12, 2), point(16, 2), point(16, 6)],
                [point(16, 12), point(16, 16), point(12, 16)],
                [point(6, 16), point(2, 16), point(2, 12)]
            ] {
                var corner = Path()
                corner.addLines(corners)
                context.stroke(corner, with: .foreground, style: style)
            }
            var cursor = Path()
            cursor.addLines([point(7, 5), point(7, 14), point(9.6, 11.7), point(11.3, 15.3),
                             point(13.2, 14.4), point(11.5, 10.9), point(14.5, 10.9)])
            cursor.closeSubpath()
            context.fill(cursor, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
