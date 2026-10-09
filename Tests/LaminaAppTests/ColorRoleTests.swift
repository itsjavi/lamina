import AppKit
import Foundation
import Testing
@testable import LaminaApp

@MainActor
struct ColorRoleTests {
    private let light = NSAppearance(named: .aqua)!
    private let dark = NSAppearance(named: .darkAqua)!

    private func hex(_ color: NSColor) -> UInt32 {
        let rgb = color.usingColorSpace(.sRGB)!
        func byte(_ value: CGFloat) -> UInt32 { UInt32((value * 255).rounded()) }
        return byte(rgb.redComponent) << 16 | byte(rgb.greenComponent) << 8 | byte(rgb.blueComponent)
    }

    /// The roles' values, read from docs/DESIGN.md's Colors table: the spec and the code can't drift apart.
    private func specValues() throws -> [String: (light: UInt32, dark: UInt32)] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../docs/DESIGN.md")
        let design = try String(contentsOf: url, encoding: .utf8)
        let section = try #require(design.components(separatedBy: "## Colors and surfaces").last?
            .components(separatedBy: "\n## ").first)
        var values: [String: (light: UInt32, dark: UInt32)] = [:]
        let pattern = try Regex("#([0-9A-Fa-f]{6})")
        for line in section.split(separator: "\n") where line.hasPrefix("| ") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 4 else { continue }
            func hexes(_ cell: String) -> [UInt32] {
                cell.matches(of: pattern).compactMap { $0.output[1].substring.flatMap { UInt32($0, radix: 16) } }
            }
            let roles = cells[0].components(separatedBy: " / ")
            let lights = hexes(cells[2]), darks = hexes(cells[3])
            guard lights.count == roles.count, darks.count == roles.count else { continue }
            for (index, role) in roles.enumerated() { values[role] = (lights[index], darks[index]) }
        }
        return values
    }

    @Test func everyRoleTakesTheSpecsLightAndDarkValues() throws {
        let spec = try specValues()
        for role in ColorRole.allCases where role != .accent {
            let values = try #require(spec["\(role)"], "\(role) is in DESIGN.md's Colors table")
            #expect(hex(role.resolved(for: light)) == values.light, "\(role) in light")
            #expect(hex(role.resolved(for: dark)) == values.dark, "\(role) in dark")
            #expect(role.values?.light == values.light && role.values?.dark == values.dark)
        }
        #expect(spec.count == ColorRole.allCases.count - 1, "every role in the table has a ColorRole")
    }

    @Test func theAccentIsTheSystems() {
        #expect(ColorRole.accent.nsColor == .controlAccentColor)
    }

    @Test func theAppearanceSettingMapsToAnAppearanceAndIsRemembered() {
        let defaults = UserDefaults(suiteName: "ColorRoleTests-\(UUID().uuidString)")!
        #expect(AppearanceSetting.saved(in: defaults) == .system, "follows the Mac until changed")
        #expect(AppearanceSetting.system.appearance == nil)
        #expect(AppearanceSetting.light.appearance?.name == .aqua)
        #expect(AppearanceSetting.dark.appearance?.name == .darkAqua)
        defaults.set(AppearanceSetting.dark.rawValue, forKey: AppearanceSetting.defaultsKey)
        #expect(AppearanceSetting.saved(in: defaults) == .dark)
        defaults.set("sepia", forKey: AppearanceSetting.defaultsKey)
        #expect(AppearanceSetting.saved(in: defaults) == .system, "an unknown value falls back to System")
    }

    @Test func settingsIsOnCommandK() {
        let settings = ShortcutDefinition.all.first { $0.isMenu && $0.title == "Settings" }
        #expect(settings?.original == ShortcutChord("k", 1))
        #expect(ShortcutDefinition.all.filter { $0.original == ShortcutChord("k", 1) }.count == 1, "nothing else takes ⌘K")
    }

    /// The area around the document follows the canvas's appearance.
    @Test func thePasteboardFollowsTheAppearance() throws {
        let canvas = CanvasView(session: EditorSession())
        canvas.frame = CGRect(x: 0, y: 0, width: 40, height: 30)
        for appearance in [light, dark] {
            canvas.appearance = appearance
            let context = try #require(CGContext(data: nil, width: 40, height: 30, bitsPerComponent: 8, bytesPerRow: 160,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            canvas.allowsGPU = false
            canvas.draw(canvas.bounds)
            NSGraphicsContext.restoreGraphicsState()
            let pixel = context.data!.assumingMemoryBound(to: UInt8.self)
            let drawn = UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
            let expected = appearance == light ? ColorRole.pasteboard.values!.light : ColorRole.pasteboard.values!.dark
            #expect(drawn == expected, "pasteboard in \(appearance.name.rawValue)")
        }
    }
}
