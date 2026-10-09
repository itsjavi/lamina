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
