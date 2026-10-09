import AppKit
import SwiftUI

/// "<name> is in progress", floating over the top center of the canvas while a placeholder's message shows
/// (`EditorSession.showInProgress`). It takes no clicks: the next click anywhere in the app goes where it was aimed and
/// takes the message away on its way.
struct InProgressNoticeView: View {
    let session: EditorSession
    @State private var clickMonitor: Any?

    var body: some View {
        ZStack {
            if let notice = session.inProgressNotice {
                Text(notice.feature.message)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorRole.text.color)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    // A system material, so Reduce Transparency makes it opaque.
                    .background(.regularMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("inProgressNotice")
                    .onAppear(perform: watchClicks)
                    .onDisappear(perform: stopWatchingClicks)
            }
        }
        .animation(.easeOut(duration: 0.15), value: session.inProgressNotice)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func watchClicks() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [session] event in
            session.dismissInProgressNotice()
            return event
        }
    }

    private func stopWatchingClicks() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}
