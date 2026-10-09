import SwiftUI

/// A tool's icon, the one place that maps tools to icons: the toolbar and the options bar both draw it. Its own drawing
/// where SF Symbols has none that reads as the tool, else its symbol. Planned tools (`PlannedFeature`) have icons too,
/// drawn like the others, since their placeholders look like shipping tools.
struct ToolIcon: View {
    let item: SlotItem
    /// The square the icon fills: 18 pt in the toolbar, 16 pt in the options bar.
    var size: CGFloat = 18

    init(tool: NavigationTool, size: CGFloat = 18) { self.init(item: .tool(tool), size: size) }
    init(item: SlotItem, size: CGFloat = 18) { self.item = item; self.size = size }

    var body: some View {
        Group {
            switch item {
            case .tool(.gradient): GradientToolIcon()
            case .tool(.paintBucket): PaintBucketToolIcon()
            case .tool(.cloneStamp): CloneStampToolIcon()
            case .tool(.polygonalLasso): PolygonalLassoToolIcon()
            case .tool(.objectSelection): ObjectSelectionToolIcon()
            case .tool(let tool): Image(systemName: tool.symbol).font(.system(size: size - 1))
            case .planned(.paletteKnifeTool): PaletteKnifeToolIcon()
            case .planned(let feature): Image(systemName: feature.symbol).font(.system(size: size - 1))
            }
        }
        .frame(width: size, height: size)
    }
}

/// A palette knife for the toolbar (SF Symbols has none): a handle, a cranked neck and a flat rounded blade.
struct PaletteKnifeToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var handle = Path()
            handle.move(to: CGPoint(x: w * 0.08, y: h * 0.92))
            handle.addLine(to: CGPoint(x: w * 0.36, y: h * 0.64))
            context.stroke(handle, with: .foreground, style: StrokeStyle(lineWidth: w * 0.16, lineCap: .round))
            var neck = Path()
            neck.move(to: CGPoint(x: w * 0.36, y: h * 0.64))
            neck.addLine(to: CGPoint(x: w * 0.46, y: h * 0.62))
            neck.addLine(to: CGPoint(x: w * 0.52, y: h * 0.50))
            context.stroke(neck, with: .foreground, style: StrokeStyle(lineWidth: w * 0.07, lineCap: .round, lineJoin: .round))
            // The blade: a long teardrop from the neck up to the top right.
            var blade = Path()
            blade.move(to: CGPoint(x: w * 0.50, y: h * 0.52))
            blade.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.06), control: CGPoint(x: w * 0.60, y: h * 0.18))
            blade.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.52), control: CGPoint(x: w * 0.86, y: h * 0.42))
            blade.closeSubpath()
            context.fill(blade, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
