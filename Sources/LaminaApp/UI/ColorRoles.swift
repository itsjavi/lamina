import AppKit
import SwiftUI

/// The colors of everything Lamina draws itself, one role per use (docs/DESIGN.md, Colors and surfaces). Each is a
/// dynamic color with a light and a dark value, so it follows the window's appearance and switches live. Native
/// controls keep their system colors; document content and canvas overlays keep their own fixed colors.
/// Nonisolated: AppKit may resolve a dynamic color on any thread.
nonisolated enum ColorRole: CaseIterable, Sendable {
    case window, chrome, panel, panelHeader, field, control, hover, activeTool, edge, separator
    case text, secondaryText, tertiaryText, icon, accent, selection, pasteboard

    /// sRGB hex values from DESIGN.md, light then dark. The accent is the system's, so it has none.
    var values: (light: UInt32, dark: UInt32)? {
        switch self {
        case .window: (0xF5F5F7, 0x1D1D1F)
        case .chrome: (0xECECEE, 0x29292C)
        case .panel: (0xF6F6F8, 0x2B2B2E)
        case .panelHeader: (0xE3E3E6, 0x232326)
        case .field: (0xFFFFFF, 0x18181A)
        case .control: (0xE0E0E4, 0x3B3B40)
        case .hover: (0xDCDCE1, 0x38383C)
        case .activeTool: (0xC9C9CF, 0x55555B)
        case .edge: (0xC3C3C8, 0x111113)
        case .separator: (0xE2E2E6, 0x232326)
        case .text: (0x1D1D1F, 0xE6E6E9)
        case .secondaryText: (0x6E6E73, 0xA3A3AA)
        case .tertiaryText: (0xA1A1A6, 0x75757C)
        case .icon: (0x3A3A3E, 0xD6D6DB)
        case .accent: nil
        case .selection: (0xCFE0FB, 0x2A5596)
        case .pasteboard: (0xC6C6CB, 0x202022)
        }
    }

    var nsColor: NSColor { Self.colors[self] ?? .controlAccentColor }
    var color: Color { Color(nsColor: nsColor) }

    /// The role's color under `appearance`, in sRGB: for layers and Core Image, whose colors don't follow the
    /// appearance by themselves. Callers resolve again when `viewDidChangeEffectiveAppearance` says it changed.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var color = nsColor
        appearance.performAsCurrentDrawingAppearance { color = nsColor.usingColorSpace(.sRGB) ?? nsColor }
        return color
    }

    private static let colors: [ColorRole: NSColor] = Dictionary(uniqueKeysWithValues: allCases.compactMap { role in
        guard let values = role.values else { return nil }
        let light = srgb(values.light), dark = srgb(values.dark)
        return (role, NSColor(name: "Lamina.\(role)") { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    })

    private static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Lamina ▸ Settings… ▸ Appearance: follow the Mac, or keep Lamina light or dark whatever the Mac is set to.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    static let defaultsKey = "appearance"
    var id: Self { self }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    /// What `NSApp.appearance` takes: nil follows the Mac and switches with it.
    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    static func saved(in defaults: UserDefaults = .standard) -> AppearanceSetting {
        defaults.string(forKey: defaultsKey).flatMap(AppearanceSetting.init(rawValue:)) ?? .system
    }
    /// Every window, panel, sheet and alert takes it, open and save panels included.
    func apply() { NSApp.appearance = appearance }
}
