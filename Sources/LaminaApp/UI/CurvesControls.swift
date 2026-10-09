import SwiftUI
import LaminaCore

struct CurvesControls: View {
    @Binding var settings: CurvesSettings
    /// The graph's height: the dialog's, or Properties' shorter one.
    var graphHeight: CGFloat = 260
    @State private var selected: Int?
    @State private var dragging: Int?
    private var points: [CurvePoint] { settings.channels[settings.channel.index] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Channel:")
                Picker("Channel", selection: $settings.channel) {
                    ForEach(LevelsChannel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().fixedSize()
                .onChange(of: settings.channel) { _, _ in selected = nil; dragging = nil }
            }
            Canvas { context, size in
                func position(_ p: CurvePoint) -> CGPoint { CGPoint(x: p.x/255*size.width, y: (1-p.y/255)*size.height) }
                var grid = Path()
                for i in 0...4 {
                    let f = CGFloat(i)/4
                    grid.move(to: CGPoint(x: f*size.width, y: 0)); grid.addLine(to: CGPoint(x: f*size.width, y: size.height))
                    grid.move(to: CGPoint(x: 0, y: f*size.height)); grid.addLine(to: CGPoint(x: size.width, y: f*size.height))
                }
                context.stroke(grid, with: .color(ColorRole.separator.color), lineWidth: 1)
                var line = Path()
                for x in 0...255 {
                    let p = position(CurvePoint(x: Double(x), y: settings.value(Double(x), channel: settings.channel.index)))
                    if x == 0 { line.move(to: p) } else { line.addLine(to: p) }
                }
                context.stroke(line, with: .color(ColorRole.text.color), lineWidth: 2)
                for (i, point) in points.enumerated() {
                    let p = position(point)
                    context.fill(Path(ellipseIn: CGRect(x: p.x-4, y: p.y-4, width: 8, height: 8)), with: .color(selected == i ? .accentColor : ColorRole.text.color))
                }
            }
            .frame(height: graphHeight).background(ColorRole.field.color)
            .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
            .contentShape(Rectangle())
            .overlay { GeometryReader { geometry in
                Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    let x = min(255, max(0, Double(event.location.x/geometry.size.width)*255))
                    let y = min(255, max(0, 255-Double(event.location.y/geometry.size.height)*255))
                    var p = points
                    if dragging == nil {
                        if let index = p.indices.min(by: { hypot(p[$0].x-x,p[$0].y-y) < hypot(p[$1].x-x,p[$1].y-y) }), hypot(p[index].x-x,p[index].y-y) < 14 {
                            dragging = index
                        } else if p.count < 32, x > 1, x < 254, p.allSatisfy({ abs($0.x-x) > 1 }) {
                            p.append(CurvePoint(x: x, y: y)); p.sort { $0.x < $1.x }
                            settings.channels[settings.channel.index] = p
                            dragging = p.firstIndex { $0.x == x }
                        }
                    }
                    guard let i = dragging, p.indices.contains(i) else { return }
                    selected = i
                    p[i].y = y
                    if i > 0, i < p.count-1 { p[i].x = min(p[i+1].x-1, max(p[i-1].x+1, x)) }
                    settings.channels[settings.channel.index] = p
                }.onEnded { _ in dragging = nil })
            } }
            // The selected point's values, as Photoshop's Output and Input fields; empty until a point is picked.
            HStack(spacing: 8) {
                Text("Output:")
                pointField(\.y, name: "Output")
                Text("Input:").padding(.leading, 6)
                pointField(\.x, name: "Input")
                Spacer(minLength: 0)
                Button("Remove Point") {
                    if let selected, selected > 0, selected < points.count-1 { settings.channels[settings.channel.index].remove(at: selected); self.selected = nil }
                }.disabled(selected == nil || selected == 0 || selected == points.count-1)
            }
            Text("Click to add a point. Drag to adjust.").font(.caption).foregroundStyle(.secondary)
        }
    }

    /// One coordinate of the selected point. The end points keep their input at 0 and 255; a middle point stays
    /// between its neighbors.
    private func pointField(_ key: WritableKeyPath<CurvePoint, Double>, name: String) -> some View {
        let index = selected.flatMap { points.indices.contains($0) ? $0 : nil }
        let movable = index.map { key == \CurvePoint.y || ($0 > 0 && $0 < points.count - 1) } ?? false
        return TextField(name, value: Binding<Double?>(
            get: { index.map { points[$0][keyPath: key].rounded() } },
            set: { value in
                guard let value, let index, movable else { return }
                var p = points
                var clamped = min(255, max(0, value.rounded()))
                if key == \CurvePoint.x { clamped = min(p[index + 1].x - 1, max(p[index - 1].x + 1, clamped)) }
                p[index][keyPath: key] = clamped
                settings.channels[settings.channel.index] = p
            }), format: .number.precision(.fractionLength(0)))
            .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
            .disabled(!movable)
    }
}
