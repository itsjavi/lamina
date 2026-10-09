import AppKit

/// Keeps the menu bar in the order docs/DESIGN.md (Menus) gives it where SwiftUI alone can't:
/// - View after Filter, as familiar editors have it. SwiftUI places menus an app makes (`CommandMenu`) after the
///   system's View menu, so Lamina makes its own View menu after Filter, and AppKit still keeps the system's for its
///   Enter Full Screen item. That one goes; Lamina's View menu has its own Enter Full Screen (`FullScreenState`).
/// - Minimize and Zoom first in Window. Lamina makes them itself, without ⌘M (Curves…), and AppKit puts its window
///   tiling items (Fill, Center, Move & Resize) above any Minimize it doesn't know as its own.
/// SwiftUI builds the menu bar again as commands change and AppKit adds its items late, so a change to either menu
/// is followed by a look at a dozen titles.
@MainActor
enum MenuBarOrder {
    private static var observers: [NSObjectProtocol] = []
    private static var pending = false

    static func install() {
        guard observers.isEmpty else { return }
        for name in [NSMenu.didAddItemNotification, NSApplication.didFinishLaunchingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                MainActor.assumeIsolated {
                    guard let menu = note.object as? NSMenu ?? NSApp.mainMenu, menu === NSApp.mainMenu
                            || menu.supermenu === NSApp.mainMenu else { return }
                    scheduleCheck()
                }
            })
        }
    }

    /// Once the menus have settled: AppKit and SwiftUI add items one at a time.
    private static func scheduleCheck() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                pending = false
                removeSystemViewMenu()
                putWindowSizeFirst()
            }
        }
    }

    /// The first of two View menus, when it holds nothing of Lamina's.
    static func removeSystemViewMenu(in menu: NSMenu? = NSApp.mainMenu) {
        guard let menu else { return }
        let views = menu.items.filter { $0.title == "View" }
        guard views.count > 1, let system = views.first,
              system.submenu?.items.allSatisfy({ $0.isSeparatorItem || $0.action == #selector(NSWindow.toggleFullScreen(_:)) }) != false
        else { return }
        menu.removeItem(system)
    }

    /// Minimize then Zoom at the top of the Window menu, ahead of the tiling items AppKit adds.
    static func putWindowSizeFirst(in menu: NSMenu? = NSApp.mainMenu) {
        guard let window = menu?.items.first(where: { $0.title == "Window" })?.submenu,
              let minimize = window.items.first(where: { $0.title == "Minimize" }),
              let zoom = window.items.first(where: { $0.title == "Zoom" }),
              window.index(of: minimize) != 0 || window.index(of: zoom) != 1 else { return }
        window.removeItem(minimize)
        window.removeItem(zoom)
        window.insertItem(minimize, at: 0)
        window.insertItem(zoom, at: 1)
    }
}

/// Whether a window is in full screen, so View › Enter Full Screen can read Exit Full Screen while it is.
@MainActor @Observable
final class FullScreenState {
    static let shared = FullScreenState()
    private(set) var isFullScreen = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        for (name, value) in [(NSWindow.didEnterFullScreenNotification, true), (NSWindow.didExitFullScreenNotification, false)] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isFullScreen = value }
            })
        }
    }
}
