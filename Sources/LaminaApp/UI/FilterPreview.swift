import SwiftUI
import LaminaCore

/// A filter dialog's preview (docs/DESIGN.md, Dialogs): part of the layer at a chosen zoom, with zoom out, the
/// percentage and zoom in under it. It shows the image the canvas previews (the filter's own render of the layer, at
/// most `FilterEdit.previewLimit` pixels on its longest side) cropped to what fits, so it costs no extra rendering.
/// Dragging pans; holding the mouse down shows the layer as it was.
struct FilterPreview: View {
    @Bindable var session: EditorSession
    /// Points per layer pixel.
    @State private var zoom = 1.0
    /// The middle of what's shown, in the layer's own pixels; nil until the person pans.
    @State private var center: CGPoint?
    @State private var dragStart: CGPoint?

    static let size = CGSize(width: 340, height: 220)
    static let zoomSteps: [Double] = [1 / 16, 1 / 8, 1 / 4, 1 / 3, 1 / 2, 2 / 3, 1, 2, 3, 4, 8, 16]

    var body: some View {
        // The preview image is observation-ignored; a new render bumps `brushRevision`.
        let _ = session.brushRevision
        let edit = session.filterEdit
        let frame = edit.flatMap { visibleFrame(of: $0) }
        VStack(spacing: 4) {
            Canvas { context, size in
                guard let frame else { return }
                Self.draw(frame, in: &context, size: size)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .background(ColorRole.pasteboard.color)
            .overlay { Rectangle().strokeBorder(ColorRole.edge.color) }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard let edit else { return }
                    let start = dragStart ?? currentCenter(edit)
                    dragStart = start
                    center = clamped(CGPoint(x: start.x - drag.translation.width / zoom,
                                             y: start.y - drag.translation.height / zoom), in: edit)
                }
                .onEnded { _ in dragStart = nil })
            .help("Drag to see another part of the layer. Hold to see it before the filter.")
            .accessibilityLabel("Filter preview")
            HStack(spacing: 12) {
                Button { step(-1) } label: { Image(systemName: "minus.magnifyingglass") }
                    .disabled(zoom <= Self.zoomSteps[0]).help("Zoom out").accessibilityLabel("Zoom out")
                Text(zoom, format: .percent.precision(.significantDigits(1...3)).grouping(.never))
                    .monospacedDigit().frame(minWidth: 52)
                    .accessibilityLabel("Preview zoom")
                Button { step(1) } label: { Image(systemName: "plus.magnifyingglass") }
                    .disabled(zoom >= Self.zoomSteps[Self.zoomSteps.count - 1]).help("Zoom in").accessibilityLabel("Zoom in")
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity)
        }
    }

    private func step(_ direction: Int) {
        let next = direction > 0 ? Self.zoomSteps.first { $0 > zoom + 0.0001 } : Self.zoomSteps.last { $0 < zoom - 0.0001 }
        if let next { zoom = next }
    }

    /// Where the preview opens: the middle of the selection when there is one on the layer, else the layer's.
    private func currentCenter(_ edit: FilterEdit) -> CGPoint {
        if let center { return center }
        let width = edit.original.image.width, height = edit.original.image.height
        let middle = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        guard let bounds = session.selection?.path.boundingBoxOfPath, !bounds.isNull, !bounds.isEmpty else { return middle }
        let toLayer = edit.transform.pixelToDocument(width: width, height: height).inverted()
        let point = CGPoint(x: bounds.midX, y: bounds.midY).applying(toLayer)
        return clamped(point, in: edit)
    }

    /// Anywhere on the layer, and on the room a blur has grown around it.
    private func clamped(_ point: CGPoint, in edit: FilterEdit) -> CGPoint {
        let margin = edit.grownMargin
        return CGPoint(x: min(max(point.x, -margin), CGFloat(edit.original.image.width) + margin),
                       y: min(max(point.y, -margin), CGFloat(edit.original.image.height) + margin))
    }

    /// What to draw: the filtered preview, or the layer as it was while the mouse is down (and before the first
    /// render arrives), cropped to the part that shows.
    private func visibleFrame(of edit: FilterEdit) -> PreviewFrame? {
        let showsOriginal = dragStart != nil || edit.preparedPreview == nil
        let image = showsOriginal ? edit.previewSource : edit.preparedPreview ?? edit.previewSource
        // The preview source sits on the grown grid; the render on the grid it was made from.
        let placed = showsOriginal ? edit.grownTransform ?? edit.transform
                                   : edit.preparedTransform ?? edit.grownTransform ?? edit.transform
        let width = edit.original.image.width, height = edit.original.image.height
        let layerToImage = edit.transform.pixelToDocument(width: width, height: height)
            .concatenating(placed.pixelToDocument(width: image.width, height: image.height).inverted())
        let middle = currentCenter(edit)
        let shown = CGRect(x: middle.x - Self.size.width / 2 / zoom, y: middle.y - Self.size.height / 2 / zoom,
                           width: Self.size.width / zoom, height: Self.size.height / zoom)
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let crop = shown.applying(layerToImage).integral.intersection(imageBounds)
        guard !crop.isNull, !crop.isEmpty, let cropped = image.cropping(to: crop) else { return nil }
        // Back to the view: layer pixels from the shown rect's corner, times the zoom.
        let imageToView = layerToImage.inverted()
            .concatenating(CGAffineTransform(translationX: -shown.minX, y: -shown.minY))
            .concatenating(CGAffineTransform(scaleX: zoom, y: zoom))
        let layer = CGRect(x: 0, y: 0, width: width, height: height)
            .applying(CGAffineTransform(translationX: -shown.minX, y: -shown.minY).scaledBy(x: zoom, y: zoom))
        // Pixels enlarged two times or more stay square, so fine detail reads as pixels rather than blur.
        let pointsPerPixel = zoom / hypot(layerToImage.a, layerToImage.b)
        return PreviewFrame(image: cropped, destination: crop.applying(imageToView), layer: layer, pixelated: pointsPerPixel >= 2)
    }

    private struct PreviewFrame {
        let image: CGImage
        let destination: CGRect
        /// The layer's own bounds in the view, where the checkerboard shows through its transparency.
        let layer: CGRect
        let pixelated: Bool
    }

    /// The canvas's checkerboard behind the layer, then the pixels. Both are fixed colors (DESIGN.md, Colors).
    private static func draw(_ frame: PreviewFrame, in context: inout GraphicsContext, size: CGSize) {
        let area = frame.layer.union(frame.destination).intersection(CGRect(origin: .zero, size: size))
        if !area.isNull, !area.isEmpty {
            context.fill(Path(area), with: .color(Color(white: 0.35)))
            let tile: CGFloat = 10
            var squares = Path()
            let firstColumn = Int(((area.minX - frame.layer.minX) / tile).rounded(.down))
            let firstRow = Int(((area.minY - frame.layer.minY) / tile).rounded(.down))
            let columns = Int((area.width / tile).rounded(.up)) + 1, rows = Int((area.height / tile).rounded(.up)) + 1
            for row in firstRow..<(firstRow + rows) {
                for column in firstColumn..<(firstColumn + columns) where !(row + column).isMultiple(of: 2) {
                    squares.addRect(CGRect(x: frame.layer.minX + CGFloat(column) * tile,
                                           y: frame.layer.minY + CGFloat(row) * tile, width: tile, height: tile))
                }
            }
            var clipped = context
            clipped.clip(to: Path(area))
            clipped.fill(squares, with: .color(Color(white: 0.30)))
        }
        context.draw(Image(decorative: frame.image, scale: 1).interpolation(frame.pixelated ? .none : .high),
                     in: frame.destination)
    }
}
