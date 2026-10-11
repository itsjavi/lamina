import AppKit
import SwiftUI
import Testing
@testable import LaminaApp

/// The Layers and Properties footers (docs/DESIGN.md, Iconography): their buttons and menus draw their icons in the
/// same color, and dim to the same color when they can't be used.
@MainActor
struct FooterIconTests {
    /// The color of `view`'s strongest pixel against the panel, drawn offscreen in `appearance`, in sRGB.
    private func ink(_ view: some View, _ appearance: NSAppearance.Name) throws -> [Int] {
        let host = NSHostingView(rootView: view.frame(width: 40, height: 30).background(ColorRole.panel.color))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(x: 0, y: 0, width: 40, height: 30)
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        func rgb(_ x: Int, _ y: Int) -> [Int] {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return [0, 0, 0] }
            return [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
        }
        let background = rgb(0, 0)
        var strongest = background, distance = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                let pixel = rgb(x, y)
                let d = zip(pixel, background).map { abs($0 - $1) }.reduce(0, +)
                if d > distance { (strongest, distance) = (pixel, d) }
            }
        }
        return strongest
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func buttonsAndMenusDimAlike(_ appearance: NSAppearance.Name) throws {
        for disabled in [false, true] {
            let button = PropertiesFooterButton(title: "Delete layer", symbol: "trash") {}.disabled(disabled)
            let menu = Menu { Button("Item") {} } label: { LayersFooterIcon(symbol: "trash") }
                .layersFooterMenu().disabled(disabled)
            let mask = Button {} label: { LayersFooterIcon(symbol: "trash") }
                .buttonStyle(FooterButtonStyle()).disabled(disabled)
            let buttonInk = try ink(button, appearance)
            #expect(try ink(menu, appearance) == buttonInk, "disabled: \(disabled)")
            #expect(try ink(mask, appearance) == buttonInk, "disabled: \(disabled)")
        }
        let enabled = try ink(PropertiesFooterButton(title: "Delete layer", symbol: "trash") {}, appearance)
        let disabled = try ink(PropertiesFooterButton(title: "Delete layer", symbol: "trash") {}.disabled(true), appearance)
        #expect(enabled != disabled, "a disabled icon dims")
    }
}
