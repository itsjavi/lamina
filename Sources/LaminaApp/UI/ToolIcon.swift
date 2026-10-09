import SwiftUI

/// A tool's icon, the one place that maps tools to icons: the toolbar, its flyouts and the options bar all draw it. Its
/// own drawing where SF Symbols has none that reads as the tool (docs/DESIGN.md, Iconography), else its symbol. Planned
/// tools (`PlannedFeature`) have icons too, drawn like the others, since their placeholders look like shipping tools.
struct ToolIcon: View {
    let item: SlotItem
    /// The square the icon fills: 18 pt in the toolbar, 16 pt in the options bar and flyouts.
    var size: CGFloat = 18

    init(tool: NavigationTool, size: CGFloat = 18) { self.init(item: .tool(tool), size: size) }
    init(item: SlotItem, size: CGFloat = 18) { self.item = item; self.size = size }

    var body: some View {
        Group {
            if let symbol = Self.symbol(for: item) {
                Image(systemName: symbol).font(.system(size: size - 1))
            } else {
                switch item {
                case .tool(.gradient): GradientToolIcon()
                case .tool(.paintBucket): PaintBucketToolIcon()
                case .tool(.cloneStamp): CloneStampToolIcon()
                case .tool(.polygonalLasso): PolygonalLassoToolIcon()
                case .tool(.objectSelection): ObjectSelectionToolIcon()
                case .tool(.dodge): DodgeToolIcon()
                case .tool(.burn): BurnToolIcon()
                case .tool(.type): TypeToolIcon()
                case .planned(.paletteKnifeTool): PaletteKnifeToolIcon()
                default: EmptyView()
                }
            }
        }
        .frame(width: size, height: size)
    }

    /// The SF Symbol an item shows, nil for the ones drawn here.
    static func symbol(for item: SlotItem) -> String? {
        switch item {
        case .tool(let tool):
            switch tool {
            case .move: "arrow.up.and.down.and.arrow.left.and.right"
            case .rectangularMarquee: "rectangle.dashed"
            case .ellipticalMarquee: "circle.dashed"
            case .lasso: "lasso"
            case .magicWand: "wand.and.stars"
            case .crop: "crop"
            case .eyedropper: "eyedropper"
            case .spotHealing: "bandage"
            case .brush: "paintbrush.pointed"
            case .eraser: "eraser"
            case .blur: "drop"
            case .smudge: "hand.point.up.left"
            case .rectangle: "rectangle.fill"
            case .ellipse: "oval.fill"
            case .line: "line.diagonal"
            case .hand: "hand.raised"
            case .zoom: "magnifyingglass"
            case .liquify: "water.waves"
            case .idle: "circle.slash"
            case .polygonalLasso, .objectSelection, .cloneStamp, .gradient, .paintBucket, .dodge, .burn, .type: nil
            }
        case .planned(let feature):
            switch feature {
            case .penTool: "pencil.tip"
            case .pathSelectionTool: "cursorarrow"
            case .directSelectionTool: "point.topleft.down.to.point.bottomright.curvepath"
            case .mixerBrushTool: "paintbrush"
            case .polygonTool: "hexagon.fill"
            case .starTool: "star.fill"
            default: nil
            }
        }
    }

    /// The icon as a template image for a native menu (the toolbar's flyouts): a symbol as itself, a drawing rendered.
    @MainActor static func menuImage(for item: SlotItem, size: CGFloat = 16) -> NSImage? {
        if let symbol = symbol(for: item) {
            return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: size - 2, weight: .regular))
        }
        let renderer = ImageRenderer(content: ToolIcon(item: item, size: size).foregroundStyle(.black))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}

/// Strokes in the weight of the SF Symbols beside them: 1.5 pt at 18 pt, on a 24-unit grid that `draw` lays out in.
private struct StrokeIcon: View {
    let draw: (_ unit: CGFloat) -> [Path]
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 24
            let style = StrokeStyle(lineWidth: 2 * unit, lineCap: .round, lineJoin: .round)
            for path in draw(unit) { context.stroke(path, with: .foreground, style: style) }
        }
        .accessibilityHidden(true)
    }
}

/// The Dodge tool: a round paddle on a stick, the darkroom tool that holds light back. The paddle is solid, so it
/// doesn't read as the Zoom tool's magnifier.
struct DodgeToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 24
            context.fill(Path(ellipseIn: CGRect(x: 10.4 * unit, y: 3 * unit, width: 10 * unit, height: 10 * unit)), with: .foreground)
            var stick = Path()
            stick.addLines([CGPoint(x: 12.4 * unit, y: 11.6 * unit), CGPoint(x: 4 * unit, y: 20 * unit)])
            context.stroke(stick, with: .foreground, style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The Burn tool: a hand cupped under a spot of light, the darkroom way to give one place more exposure.
struct BurnToolIcon: View {
    var body: some View {
        StrokeIcon { unit in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            let light = Path(ellipseIn: CGRect(x: 5.6 * unit, y: 2.8 * unit, width: 6.4 * unit, height: 6.4 * unit))
            // Two curled fingers, then the last one running into the palm, the heel of the hand and the thumb.
            var first = Path()
            first.move(to: point(12, 9.5))
            first.addCurve(to: point(14, 10.7), control1: point(13, 9.1), control2: point(14, 9.7))
            first.addLine(to: point(14, 11.7))
            var second = Path()
            second.addArc(center: point(15.3, 10.8), radius: 1.3 * unit, startAngle: .degrees(180), endAngle: .degrees(360),
                          clockwise: false)
            second.addLine(to: point(16.6, 12))
            var hand = Path()
            hand.addArc(center: point(17.9, 11.5), radius: 1.3 * unit, startAngle: .degrees(180), endAngle: .degrees(360),
                        clockwise: false)
            hand.addLine(to: point(19.2, 15))
            hand.addCurve(to: point(13.6, 21), control1: point(19.2, 18.3), control2: point(16.9, 21))
            hand.addLine(to: point(12, 21))
            hand.addCurve(to: point(6.6, 16.7), control1: point(9.4, 21), control2: point(7.4, 19.2))
            hand.addLine(to: point(5.6, 13.4))
            hand.addQuadCurve(to: point(8, 12.5), control: point(6.1, 11))
            hand.addLine(to: point(9, 14.2))
            return [light, first, second, hand]
        }
    }
}

/// The Horizontal Type tool: a serif capital T, in the system's serif face.
struct TypeToolIcon: View {
    var body: some View {
        GeometryReader { proxy in
            Text(verbatim: "T")
                .font(.system(size: proxy.size.height * 1.05, weight: .regular, design: .serif))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
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
