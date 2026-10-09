import AppKit
import SwiftUI

/// Lamina ▸ Settings… (⌘K).
struct SettingsView: View {
    @AppStorage(AppearanceSetting.defaultsKey) private var appearance = AppearanceSetting.system

    var body: some View {
        Form {
            Picker("Appearance:", selection: $appearance) {
                ForEach(AppearanceSetting.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("appearanceSetting")
            Text("System follows the Mac’s appearance.").font(.callout).foregroundStyle(.secondary)
        }
        .onChange(of: appearance) { _, setting in setting.apply() }
        .padding(20)
        .frame(width: 360)
    }
}

/// The Settings window, made on first use. Not a SwiftUI scene: a `Settings` scene keeps its own Settings… ⌘, item
/// beside the ⌘K one, and a `Window` scene opens along with the editor when the app is launched to open a file.
@MainActor final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        let window = self.window ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Lamina Settings"
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
            return window
        }()
        window.makeKeyAndOrderFront(nil)
    }
}
