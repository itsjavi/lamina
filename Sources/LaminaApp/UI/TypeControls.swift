import SwiftUI
import AppKit
import LaminaCore

/// The Type tool's bar: font family, font style and size, the alignments, the color and the Character panel, then
/// Cancel and Commit while text is being edited.
struct TypeControls: View {
    @Bindable var session: EditorSession
    private func value<T>(_ key: WritableKeyPath<LayerTextStyle, T>) -> Binding<T> {
        Binding(get: { session.currentTextStyle[keyPath: key] }, set: { value in
            session.changeTextStyle { $0[keyPath: key] = value }
        })
    }
    private func number(_ key: WritableKeyPath<LayerTextStyle, CGFloat>) -> Binding<Double> {
        Binding(get: { Double(session.currentTextStyle[keyPath: key]) }, set: { value in
            session.changeTextStyle { $0[keyPath: key] = CGFloat(value) }
        })
    }
    /// The open menus try faces on the text being edited (the one under the pointer), then put it back or keep it.
    private func preview(_ face: @escaping (String) -> String?) -> (FontMenuPicker.PreviewStep) -> Void {
        { step in
            switch step {
            case .show(let value): if let name = face(value) { session.previewFont(name) }
            case .revert: session.endFontPreview()
            case .keep: session.keepFontPreview()
            }
        }
    }
    var body: some View {
        let fontName = session.textFontName
        let family = fontName.isEmpty ? "" : FontFaces.family(of: fontName) ?? fontName
        OptionsBarRow(commit: commitButtons) {
            FontMenuPicker(label: "Font Family", value: Binding(get: { family }, set: { chosen in
                if let face = session.textFace(inFamily: chosen) { session.setTextFont(face) }
            }), title: family, items: { FontMenuPicker.familyItems() }, reloads: false,
                           preview: preview { session.textFace(inFamily: $0) })
                .frame(width: 160).help("Font family")
            FontMenuPicker(label: "Font Style", value: Binding(get: { fontName }, set: { session.setTextFont($0) }),
                           title: fontName.isEmpty ? "" : FontFaces.styles(of: family).first(where: { $0.name == fontName })?.style ?? fontName,
                           items: { FontMenuPicker.styleItems(family: family) }, reloads: true,
                           preview: preview { $0 })
                .frame(width: 110).help("Font style")
            HStack(spacing: 4) {
                Image(systemName: "textformat.size").foregroundStyle(.secondary).accessibilityHidden(true)
                    .scrubbable(sensitivity: 1, value: value(\.fontSize), range: 1...2000, step: 1)
                TextField("Font Size", value: number(\.fontSize), format: .number).frame(width: 52)
                    .multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.currentTextStyle.fontSize) },
                                change: { stepped in session.changeTextStyle { $0.fontSize = CGFloat(min(2000, max(1, stepped))) } })
                Text("px")
            }
            .fixedSize().help("Font size")
            OptionsBarDivider()
            HStack(spacing: 2) {
                ForEach(LaminaCore.TextAlignment.allCases, id: \.self) { alignment in
                    OptionsBarIconButton(title: alignment.rawValue + " Align Text",
                                         symbol: alignment == .left ? "text.alignleft" : alignment == .center ? "text.aligncenter" : "text.alignright",
                                         isPressed: session.currentTextStyle.alignment == alignment) {
                        session.changeTextStyle { $0.alignment = alignment }
                    }
                }
            }
            Button { session.openTextColorPicker() } label: {
                let color = session.typeColor
                let swatch = RoundedRectangle(cornerRadius: 3, style: .continuous)
                swatch.fill(Color(red: color.red, green: color.green, blue: color.blue))
                    .overlay { swatch.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                    .frame(width: 36, height: 18)
            }
            .buttonStyle(.plain).help("Set the text color").accessibilityLabel("Text color")
            // Leading and tracking are in Properties ▸ Character, as in familiar editors.
            OptionsBarIconButton(title: "Character panel", symbol: "character.textbox") { DockLayout.shared.show(.properties) }
                .accessibilityIdentifier("characterPanel")
        }
        .textFieldStyle(.roundedBorder)
        .disabled(session.document == nil || session.showsBusy)
        .onChange(of: session.colorPicker?.color) { _, _ in session.previewTextColor() }
    }

    /// Cancel ⊘ and Commit ✓ while text is being edited (Escape and ⌘Return on the canvas).
    private var commitButtons: OptionsBarCommitButtons? {
        guard session.textDraft != nil else { return nil }
        return OptionsBarCommitButtons(cancelTitle: "Cancel any current edits (Escape)", commitTitle: "Commit any current edits (⌘Return)",
                                       cancel: { session.cancelText() }, commit: { _ = session.finishText() })
    }
}

/// A font pop-up, the family or the style, each name set in its own face. Kept out of SwiftUI's per-keystroke view
/// updates: the closed control holds only the current name, and the menu fills when it opens.
struct FontMenuPicker: NSViewRepresentable {
    struct Item {
        let title: String
        /// What choosing it sets: a family name, or a face's PostScript name.
        let value: String
        /// The face its title is drawn in.
        let face: StyledName.Face
    }
    let label: String
    /// The chosen item's value; empty when the text being edited is in more than one.
    @Binding var value: String
    /// The closed pop-up's title for `value`.
    let title: String
    let items: @MainActor () -> [Item]
    /// Builds the list each time the menu opens (a family's styles), rather than once (the families).
    let reloads: Bool
    /// The open menu trying faces on the text: the one under the pointer, putting the text back, or keeping it.
    enum PreviewStep { case show(String), revert, keep }
    var preview: (PreviewStep) -> Void = { _ in }
    @Environment(\.isEnabled) private var isEnabled

    static func familyItems() -> [Item] {
        NSFontManager.shared.availableFontFamilies.map { Item(title: $0, value: $0, face: .family($0)) }
    }

    static func styleItems(family: String) -> [Item] {
        FontFaces.styles(of: family).map { Item(title: $0.style, value: $0.name, face: .font($0.name)) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = FixedWidthPopUpButton(frame: .zero, pullsDown: false)
        button.borderShape = .capsule
        // A long name is cut off at its end rather than widening the control or scrolling its start away.
        button.cell?.lineBreakMode = .byTruncatingTail
        button.cell?.usesSingleLineMode = true
        button.cell?.alignment = .left
        button.setAccessibilityLabel(label)
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.menu?.delegate = context.coordinator
        if !reloads { StyledName.prepare(families: NSFontManager.shared.availableFontFamilies) }
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.isEnabled = isEnabled
        guard !context.coordinator.tracking else { return }
        if value.isEmpty { Self.showMultiple(in: button); return }
        Self.hideMultiple(in: button)
        if let item = button.selectedItem, item.representedObject as? String == value { return }
        // The styles belong to one family: when it changes, the old ones go.
        if reloads { button.removeAllItems(); context.coordinator.loaded = false }
        let index = button.indexOfItem(withRepresentedObject: value)
        if index >= 0 { button.selectItem(at: index); return }
        button.addItem(withTitle: title)
        button.lastItem?.representedObject = value
        button.select(button.lastItem)
    }

    /// Selected letters in more than one face: the menu says so with an item of its own at the top, which sets nothing.
    private static let multiple = "(Multiple)"
    private static func isMultiple(_ item: NSMenuItem?) -> Bool { item?.representedObject as? String == multiple }
    static func showMultiple(in button: NSPopUpButton) {
        if !isMultiple(button.item(at: 0)) {
            let item = NSMenuItem(title: multiple, action: nil, keyEquivalent: "")
            item.representedObject = multiple
            button.menu?.insertItem(item, at: 0)
        }
        if button.indexOfSelectedItem != 0 { button.selectItem(at: 0) }
    }
    static func hideMultiple(in button: NSPopUpButton) {
        if isMultiple(button.item(at: 0)) { button.removeItem(at: 0) }
    }

    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        button.menu?.delegate = nil
        button.target = nil
    }

    /// The lists hold names of every length; the control keeps whatever width it is given, so choosing a long name
    /// can't stretch it — or leave it stretched once a short one is chosen again.
    final class FixedWidthPopUpButton: NSPopUpButton {
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
        }
    }

    final class Coordinator: NSObject, NSMenuDelegate {
        var parent: FontMenuPicker
        weak var button: NSPopUpButton?
        var tracking = false
        var loaded = false
        /// An item was chosen in the menu just closing, so its preview stays rather than being put back.
        private var chose = false

        init(parent: FontMenuPicker) { self.parent = parent }

        func menuNeedsUpdate(_ menu: NSMenu) {
            guard !loaded || parent.reloads, let button else { return }
            let selected = parent.value
            var items = parent.items()
            if !selected.isEmpty, !items.contains(where: { $0.value == selected }) {
                items.append(Item(title: parent.title, value: selected, face: .font(selected)))
            }
            button.removeAllItems()
            for item in items {
                button.addItem(withTitle: item.title)
                button.lastItem?.representedObject = item.value
                button.lastItem?.attributedTitle = StyledName.make(item.title, in: item.face)
            }
            if selected.isEmpty { FontMenuPicker.showMultiple(in: button) }
            else { button.selectItem(at: button.indexOfItem(withRepresentedObject: selected)) }
            loaded = true
        }

        func menuWillOpen(_ menu: NSMenu) { tracking = true }
        func menuDidClose(_ menu: NSMenu) {
            tracking = false
            // A choice may be reported just after the menu closes: put the text back only if none came.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.chose { self.parent.preview(.revert) }
                self.chose = false
            }
        }
        /// Only an item previews. Nothing highlighted (the pointer off the list, or the menu closing on a click) leaves
        /// the last face showing: reverting there flashed the old face just before the chosen one landed.
        func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
            if let item, !FontMenuPicker.isMultiple(item), let value = item.representedObject as? String {
                parent.preview(.show(value))
            }
        }

        @objc func choose(_ button: NSPopUpButton) {
            // The text already shows the face under the pointer: keep it as it is, so it doesn't flash back.
            chose = true
            parent.preview(.keep)
            guard !FontMenuPicker.isMultiple(button.selectedItem),
                  let selected = button.selectedItem?.representedObject as? String, selected != parent.value else { return }
            parent.value = selected
        }
    }
}

/// Font names set in their own faces for the font menus, made once for the app. Building every family's takes a
/// moment, so `prepare` does it in the background when the Type bar first appears, ahead of the menu opening. Faces
/// that can't draw their own name (symbol fonts) keep the menu's font, so the name stays readable.
@MainActor enum StyledName {
    nonisolated enum Face: Hashable, Sendable {
        /// A family, drawn in its regular face.
        case family(String)
        case font(String)
    }
    private static var made: [Face: NSAttributedString] = [:]
    private static var preparing = false

    static func make(_ title: String, in face: Face) -> NSAttributedString? {
        if made[face] == nil { made[face] = styled(title, in: face) }
        let styled = made[face]!
        return styled.length == 0 ? nil : styled
    }

    /// Every family's name in its regular face, made in the background.
    static func prepare(families: [String]) {
        guard !preparing, made.isEmpty else { return }
        preparing = true
        Task.detached(priority: .utility) {
            let result = Made(names: Dictionary(families.map { (Face.family($0), styled($0, in: .family($0))) },
                                                uniquingKeysWith: { first, _ in first }))
            await MainActor.run { made.merge(result.names) { current, _ in current } }
        }
    }
    /// Finished strings, never changed after they're made, handed over to the main thread.
    private struct Made: @unchecked Sendable { let names: [Face: NSAttributedString] }

    nonisolated private static func styled(_ title: String, in face: Face) -> NSAttributedString {
        let font: NSFont? = switch face {
        case .family(let family): NSFont(descriptor: NSFontDescriptor(fontAttributes: [.family: family]), size: NSFont.systemFontSize)
        case .font(let name): NSFont(name: name, size: NSFont.systemFontSize)
        }
        guard let font, title.unicodeScalars.filter({ $0.properties.isAlphabetic }).allSatisfy({ font.coveredCharacterSet.contains($0) })
        else { return NSAttributedString() }
        return NSAttributedString(string: title, attributes: [.font: font])
    }
}
