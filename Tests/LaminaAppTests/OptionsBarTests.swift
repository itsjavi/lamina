import AppKit
import SwiftUI
import Testing
@testable import LaminaApp

/// The options bar in a narrow window (docs/DESIGN.md, Options bars): the settings keep their size and scroll
/// sideways, Cancel and Commit stay in view, and at 1500 pt no tool's bar needs to scroll.
@MainActor
struct OptionsBarTests {
    /// Lays `view` out as a `width` × 36 bar in a window that is never shown (a scroll view sizes its content only in
    /// a window, once drawn) and returns its host.
    private func host(_ view: some View, width: CGFloat) -> NSHostingView<some View> {
        let host = NSHostingView(rootView: view.frame(width: width, height: ToolHeaderStyle.height))
        host.frame = NSRect(x: 0, y: 0, width: width, height: ToolHeaderStyle.height)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) { host.cacheDisplay(in: host.bounds, to: rep) }
        host.layoutSubtreeIfNeeded()
        return host
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    /// A setting's width, as laid out.
    private final class Widths { var probe: CGFloat = 0 }

    @Test func aNarrowBarScrollsAndKeepsCommitInView() throws {
        let widths = Widths()
        let session = EditorSession()
        let commit = OptionsBarCommitButtons(cancelTitle: "Cancel", commitTitle: "Commit", cancel: {}, commit: {})
        let bar = OptionsBar(session: session) {
            OptionsBarRow(commit: commit) {
                Color.clear.frame(width: 900, height: 22)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths.probe = $0 }
            }
        }
        let width: CGFloat = 400
        let view = host(bar, width: width)
        #expect(widths.probe == 900, "the settings keep their size")
        let scroll = try #require(scrollViews(in: view).first)
        let document = try #require(scroll.documentView)
        #expect(document.frame.width > scroll.contentView.bounds.width, "the settings scroll")
        #expect(!scroll.hasHorizontalScroller, "without a scroller")
        // Cancel and Commit (two 24 pt buttons, 4 apart, 8 in from each side, after a 1 pt divider) sit to its right.
        #expect(scroll.convert(scroll.bounds, to: view).maxX <= width - 69)
    }

    @Test func everyToolFitsAt1500Points() throws {
        let session = EditorSession()
        session.createDocument(width: 64, height: 64)
        for tool in NavigationTool.allCases {
            session.tool = tool
            let view = host(OptionsBar(session: session) { ToolSettings(session: session) }, width: 1500)
            for scroll in scrollViews(in: view) {
                let document = try #require(scroll.documentView)
                #expect(document.frame.width > 0, "\(tool)'s settings were laid out")
                #expect(document.frame.width <= scroll.contentView.bounds.width, "\(tool) scrolls at 1500 pt")
            }
        }
    }
}
