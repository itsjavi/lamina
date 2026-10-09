import AppKit
import LaminaCore

/// What Edit › Fill… fills with, in Photoshop's order: the fills Lamina has.
nonisolated enum FillContents: String, CaseIterable, Sendable {
    case foreground = "Foreground Color", background = "Background Color", color = "Color…"
    case contentAware = "Content-Aware"
    case black = "Black", gray = "50% Gray", white = "White"
}

/// Edit › Fill…'s settings.
nonisolated struct FillOptions: Equatable, Sendable {
    var contents: FillContents = .foreground
    /// What Color… fills with.
    var color: PaletteColor = .black
    /// 0.01 to 1. Content-Aware takes none: it opens its own dialog.
    var opacity: Double = 1
}

/// The dialogs that wait for OK before they change anything: Edit › Fill… and Select › Load Selection….
enum CommandDialog: Equatable {
    case fill, loadSelection
}

extension EditorSession {
    /// Edit › Fill… and the fill keys: the target (a layer's pixels or its mask) takes paint.
    var canFill: Bool { canEditPixels }

    /// Edit › Fill… (⇧F5, ⇧⌫): opens the Fill dialog.
    func beginFill() {
        guard canFill, commandDialog == nil else { NSSound.beep(); return }
        // Content-Aware needs a selection on an image's pixels; a dialog last left on it starts on the foreground color.
        if fillOptions.contents == .contentAware, !canContentAwareFill { fillOptions.contents = .foreground }
        commandDialog = .fill
    }

    /// The Fill dialog's OK (its settings) or Cancel (nil).
    func finishFill(_ options: FillOptions?) async {
        guard commandDialog == .fill else { return }
        commandDialog = nil
        guard let options else { return }
        fillOptions = options
        await fill(options)
    }

    /// Fills the selection (the whole layer or mask without one) as one undo step, as Fill's OK does. Content-Aware
    /// opens Content-Aware Fill, which works out the fill and shows it before it's applied.
    func fill(_ options: FillOptions) async {
        let opacity = min(1, max(0.01, options.opacity))
        switch options.contents {
        case .foreground: await fill(paletteColor(background: false), opacity: opacity)
        case .background: await fill(paletteColor(background: true), opacity: opacity)
        case .color: await fill(options.color, opacity: opacity)
        case .contentAware: beginFilter(.contentAwareFill)
        case .black: await fill(.black, opacity: opacity)
        case .gray: await fill(PaletteColor(red: 128 / 255, green: 128 / 255, blue: 128 / 255), opacity: opacity)
        case .white: await fill(.white, opacity: opacity)
        }
    }

    /// Paints `value` over the selection (or the whole layer) at `opacity`, as one undo step. On a mask a color
    /// counts by its brightness, so it reveals or hides as its gray would.
    func fill(_ value: PaletteColor, opacity: Double = 1) async {
        guard canEditPixels, let layer = activeLayer else { return }
        // A text layer that is still text takes the color as its own, rather than being painted over: the letters
        // change color and stay editable.
        if !isMaskSelected, selection == nil, opacity >= 1, layer.liveText != nil, recolorText(layer.id, to: value) { return }
        // In the mask's own gray, so 50% gray lands on 128 rather than being color-matched.
        let color = isMaskSelected
            ? CGColor(colorSpace: CGColorSpaceCreateDeviceGray(),
                      components: [0.299 * value.red + 0.587 * value.green + 0.114 * value.blue, opacity])!
            : CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [value.red, value.green, value.blue, opacity])!
        await applyPixelEdit(to: layer, name: isMaskSelected ? "Fill Mask" : "Fill") { try $0.fill(color) }
    }
}
