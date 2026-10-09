import AppKit
import SwiftUI
import LaminaCore

/// A type layer's Character section: family, style, size, leading, tracking and color. The text being edited takes
/// the changes as the Type bar's do (the selected letters, for a face or a color); a layer that is only selected
/// changes as a whole, one undo step per change.
struct CharacterProperties: View {
    @Bindable var session: EditorSession

    private var style: LayerTextStyle { session.currentTextStyle }
    /// The letters a face or color applies to: the selection in the text being edited, otherwise all of it.
    private var range: NSRange { session.textDraft?.selection ?? NSRange(location: 0, length: 0) }
    /// The face the selected letters use, as the Type bar's font menu shows it; empty when they use more than one.
    private var faceName: String {
        guard let draft = session.textDraft else { return style.fontName }
        let selection = draft.selection
        if selection.length == 0 { return draft.style.fontName(at: max(0, selection.location - 1)) }
        return draft.style.uniformFontName(in: selection) ?? ""
    }

    var body: some View {
        let face = faceName
        let family = FontFaces.family(of: face)
        PropertiesSection("Character") {
            VStack(alignment: .leading, spacing: 6) {
                FontFamilyPopUp(family: family) { chosen in
                    guard let name = FontFaces.face(in: chosen, like: face) else { return }
                    setFace(name)
                }
                .frame(height: 22)
                .help("Font family")
                Picker("Font Style", selection: Binding(get: { face }, set: { setFace($0) })) {
                    if face.isEmpty { Text("(Multiple)").tag("") }
                    ForEach(FontFaces.styles(of: family), id: \.name) { Text($0.style).tag($0.name) }
                }
                .labelsHidden().fixedSize().frame(maxWidth: .infinity, alignment: .leading)
                .disabled(family == nil)
                .help("Font style")
                HStack(spacing: 6) {
                    TransformValueField(label: "Size", symbol: "textformat.size", suffix: "px", value: style.fontSize, range: 1...2000,
                                        finish: session.finishPropertyChange) { size in
                        session.changeTextLayerStyle(held: true) { $0.fontSize = min(2000, max(1, size.rounded())) }
                    }
                    .help("Font size")
                    Spacer(minLength: 0)
                    // 0 is Auto: 120% of the size, shown as the field's placeholder.
                    TransformValueField(label: "Leading", symbol: "arrow.up.and.down.text.horizontal", suffix: "px",
                                        value: style.leading, range: 0...5000, prompt: "Auto",
                                        finish: session.finishPropertyChange) { leading in
                        session.changeTextLayerStyle(held: true) { $0.leading = min(5000, max(0, leading.rounded())) }
                    }
                    .help("Leading: line height, baseline to baseline. Empty or 0 is Auto, 120% of the size.")
                }
                HStack(spacing: 6) {
                    TransformValueField(label: "Tracking", symbol: "arrow.left.and.right.text.vertical", value: style.tracking,
                                        range: -100...1000, finish: session.finishPropertyChange) { tracking in
                        session.changeTextLayerStyle(held: true) { $0.tracking = min(1000, max(-100, tracking.rounded())) }
                    }
                    .help("Tracking: the space between letters")
                    Spacer(minLength: 0)
                    Text("Color").foregroundStyle(ColorRole.secondaryText.color)
                    Button { session.openTextLayerColorPicker() } label: {
                        let color = session.textLayerColor
                        let swatch = RoundedRectangle(cornerRadius: 3, style: .continuous)
                        swatch.fill(Color(red: color.red, green: color.green, blue: color.blue))
                            .overlay { swatch.strokeBorder(ColorRole.edge.color, lineWidth: 1) }
                            .frame(width: 40, height: 18)
                    }
                    .buttonStyle(.plain).help("Text color").accessibilityLabel("Text color")
                }
            }
        }
        .disabled(session.showsBusy)
        // The picker's working color shows on the text as it moves.
        .onChange(of: session.colorPicker?.color) { _, _ in
            session.previewTextColor()
            session.previewDialogColor()
        }
    }

    private func setFace(_ name: String) {
        guard !name.isEmpty, name != faceName else { return }
        let range = range
        session.changeTextLayerStyle { $0.setFont(name, in: range) }
    }
}

/// A type layer's Paragraph section: alignment.
struct ParagraphProperties: View {
    @Bindable var session: EditorSession

    var body: some View {
        PropertiesSection("Paragraph") {
            HStack(spacing: 2) {
                ForEach(LaminaCore.TextAlignment.allCases, id: \.self) { alignment in
                    let selected = session.currentTextStyle.alignment == alignment
                    Button { session.changeTextLayerStyle { $0.alignment = alignment } } label: {
                        Image(systemName: alignment == .left ? "text.alignleft" : alignment == .center ? "text.aligncenter" : "text.alignright")
                            .frame(width: 28, height: 24)
                            .background(selected ? ColorRole.activeTool.color : .clear, in: RoundedRectangle(cornerRadius: 4))
                            .contentShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selected ? ColorRole.text.color : ColorRole.icon.color)
                    .help("Align " + alignment.rawValue.lowercased())
                    .accessibilityLabel("Align " + alignment.rawValue.lowercased())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .disabled(session.showsBusy)
    }
}

/// Installed faces by family, as Character's two menus list them.
enum FontFaces {
    struct Style { let name: String; let style: String }

    /// The family a face (a PostScript name) belongs to; nil for an empty or unknown name.
    static func family(of face: String) -> String? {
        guard !face.isEmpty else { return nil }
        return NSFont(name: face, size: 12)?.familyName
    }
    /// A family's faces, in the order the system gives them (lightest to heaviest, romans before italics).
    static func styles(of family: String?) -> [Style] {
        guard let family, let members = NSFontManager.shared.availableMembers(ofFontFamily: family) else { return [] }
        return members.compactMap { member in
            guard let name = member.first as? String, let style = member.dropFirst().first as? String else { return nil }
            return Style(name: name, style: style)
        }
    }
    /// The face of `family` closest to `face`: the same style (Bold, Italic…) if the family has it, else its regular
    /// face, else its first.
    static func face(in family: String, like face: String) -> String? {
        let members = styles(of: family)
        let current = Self.family(of: face).flatMap { styles(of: $0).first { $0.name == face }?.style }
        if let current, let match = members.first(where: { $0.style == current }) { return match.name }
        return members.first { ["Regular", "Roman", "Book", "Medium"].contains($0.style) }?.name ?? members.first?.name
    }
}

/// Every installed family, in a pop-up filled only when it opens: the closed control needs just the current name, and
/// SwiftUI needn't rebuild hundreds of items at every change.
struct FontFamilyPopUp: NSViewRepresentable {
    let family: String?
    let choose: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(choose: choose) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = FixedWidthPopUpButton(frame: .zero, pullsDown: false)
        button.borderShape = .capsule
        button.cell?.lineBreakMode = .byTruncatingTail
        button.setAccessibilityLabel("Font Family")
        button.target = context.coordinator
        button.action = #selector(Coordinator.chose(_:))
        button.menu?.delegate = context.coordinator
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.choose = choose
        context.coordinator.family = family
        guard !context.coordinator.tracking else { return }
        let title = family ?? "(Multiple)"
        if button.titleOfSelectedItem != title {
            if button.item(withTitle: title) == nil { button.addItem(withTitle: title) }
            button.selectItem(withTitle: title)
        }
    }

    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        button.menu?.delegate = nil
        button.target = nil
    }

    /// Keeps the width it is given, however long the family chosen.
    final class FixedWidthPopUpButton: NSPopUpButton {
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
        }
    }

    final class Coordinator: NSObject, NSMenuDelegate {
        var choose: (String) -> Void
        var family: String?
        weak var button: NSPopUpButton?
        var tracking = false
        private var loaded = false

        init(choose: @escaping (String) -> Void) { self.choose = choose }

        func menuNeedsUpdate(_ menu: NSMenu) {
            guard !loaded, let button else { return }
            button.removeAllItems()
            button.addItems(withTitles: NSFontManager.shared.availableFontFamilies)
            if let family { button.selectItem(withTitle: family) }
            loaded = true
        }
        func menuWillOpen(_ menu: NSMenu) { tracking = true }
        func menuDidClose(_ menu: NSMenu) { tracking = false }
        @objc func chose(_ button: NSPopUpButton) {
            guard let title = button.titleOfSelectedItem, title != family else { return }
            choose(title)
        }
    }
}
