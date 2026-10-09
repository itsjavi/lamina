import SwiftUI

/// A tool's icon in the toolbar: its own drawing where SF Symbols has none that reads as the tool, else its symbol.
struct ToolIcon: View {
    let tool: NavigationTool

    var body: some View {
        switch tool {
        case .gradient: GradientToolIcon().frame(width: 18, height: 18)
        case .paintBucket: PaintBucketToolIcon().frame(width: 18, height: 18)
        case .cloneStamp: CloneStampToolIcon().frame(width: 18, height: 18)
        case .polygonalLasso: PolygonalLassoToolIcon().frame(width: 18, height: 18)
        case .objectSelection: ObjectSelectionToolIcon().frame(width: 18, height: 18)
        default: Image(systemName: tool.symbol).font(.system(size: 17))
        }
    }
}
