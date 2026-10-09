import SwiftUI

/// A tool's icon, the one place that maps tools to icons: the toolbar and the options bar both draw it. Its own drawing
/// where SF Symbols has none that reads as the tool, else its symbol.
struct ToolIcon: View {
    let tool: NavigationTool
    /// The square the icon fills: 18 pt in the toolbar, 16 pt in the options bar.
    var size: CGFloat = 18

    var body: some View {
        Group {
            switch tool {
            case .gradient: GradientToolIcon()
            case .paintBucket: PaintBucketToolIcon()
            case .cloneStamp: CloneStampToolIcon()
            case .polygonalLasso: PolygonalLassoToolIcon()
            case .objectSelection: ObjectSelectionToolIcon()
            default: Image(systemName: tool.symbol).font(.system(size: size - 1))
            }
        }
        .frame(width: size, height: size)
    }
}
