import SwiftUI

/// Where a dialog's buttons go (docs/DESIGN.md, Dialogs).
enum DialogButtonPlacement {
    /// OK, Cancel, extra buttons and Preview stacked in a column on the right: adjustments, filters, selection
    /// dialogs, Stroke, Fill, Trim, Canvas Size.
    case column
    /// Cancel then the default button in a row at the bottom right: Image Size, New Document, Export As.
    case bottom
}

/// Every Lamina dialog's frame: its settings, then its buttons where switchers look for them. OK is the default
/// button (Return) and Cancel takes Escape; `extras` go under them in the column (Auto, Reset, eyedroppers, Invert),
/// then the Preview checkbox when the dialog has one.
struct DialogLayout<Settings: View, Extras: View>: View {
    static var columnWidth: CGFloat { 100 }
    static var spacing: CGFloat { 18 }

    var placement: DialogButtonPlacement = .column
    /// A heading for dialogs shown as sheets, which have no title bar of their own.
    var title: String?
    var defaultTitle = "OK"
    /// New Document's is Close, as in Photoshop.
    var cancelTitle = "Cancel"
    var defaultDisabled = false
    /// The Preview checkbox, for dialogs that preview on the canvas.
    var preview: Binding<Bool>?
    /// What the dialog is waiting for ("Applying…"), shown with a spinner under the buttons.
    var status: String?
    /// Keeps room for `status` so the dialog doesn't grow and shrink as it comes and goes.
    var reservesStatus = false
    let confirm: () -> Void
    let cancel: () -> Void
    let settings: Settings
    let extras: Extras

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title { Text(title).font(.headline) }
            switch placement {
            case .column:
                HStack(alignment: .top, spacing: Self.spacing) {
                    settings
                    VStack(alignment: .leading, spacing: 8) {
                        DialogButton(defaultTitle, action: confirm)
                            .buttonStyle(.borderedProminent).configuredNativeShortcut(.return)
                            .disabled(defaultDisabled)
                        DialogButton(cancelTitle, action: cancel).configuredNativeShortcut(.escape)
                        extras
                        if let preview { DialogPreviewToggle(isOn: preview).padding(.top, 4) }
                        if status != nil || reservesStatus { statusLine.padding(.top, 4) }
                    }
                    .frame(width: Self.columnWidth)
                }
            case .bottom:
                settings
                HStack(spacing: 10) {
                    if let preview { DialogPreviewToggle(isOn: preview) }
                    if status != nil || reservesStatus { statusLine }
                    Spacer(minLength: 0)
                    extras
                    Button(action: cancel) { Text(cancelTitle).frame(minWidth: 64) }.configuredNativeShortcut(.escape)
                    Button(action: confirm) { Text(defaultTitle).frame(minWidth: 64) }
                        .buttonStyle(.borderedProminent).configuredNativeShortcut(.return)
                        .disabled(defaultDisabled)
                }
            }
        }
        .padding(20)
        .fixedSize()
    }

    private var statusLine: some View {
        HStack(spacing: 5) {
            ProgressView().controlSize(.small)
            Text(status ?? " ").font(.callout).foregroundStyle(.secondary)
        }
        .opacity(status == nil ? 0 : 1)
        .accessibilityHidden(status == nil)
    }
}

extension DialogLayout where Extras == EmptyView {
    init(placement: DialogButtonPlacement = .column, title: String? = nil, defaultTitle: String = "OK",
         cancelTitle: String = "Cancel",
         defaultDisabled: Bool = false, preview: Binding<Bool>? = nil, status: String? = nil, reservesStatus: Bool = false,
         confirm: @escaping () -> Void, cancel: @escaping () -> Void, @ViewBuilder settings: () -> Settings) {
        self.init(placement: placement, title: title, defaultTitle: defaultTitle, cancelTitle: cancelTitle,
                  defaultDisabled: defaultDisabled,
                  preview: preview, status: status, reservesStatus: reservesStatus, confirm: confirm, cancel: cancel,
                  settings: settings(), extras: EmptyView())
    }
}

extension DialogLayout {
    init(placement: DialogButtonPlacement = .column, title: String? = nil, defaultTitle: String = "OK",
         cancelTitle: String = "Cancel",
         defaultDisabled: Bool = false, preview: Binding<Bool>? = nil, status: String? = nil, reservesStatus: Bool = false,
         confirm: @escaping () -> Void, cancel: @escaping () -> Void,
         @ViewBuilder settings: () -> Settings, @ViewBuilder extras: () -> Extras) {
        self.init(placement: placement, title: title, defaultTitle: defaultTitle, cancelTitle: cancelTitle,
                  defaultDisabled: defaultDisabled,
                  preview: preview, status: status, reservesStatus: reservesStatus, confirm: confirm, cancel: cancel,
                  settings: settings(), extras: extras())
    }
}

/// The Preview checkbox (⌥P). `DialogLayout` puts it under the column's buttons; a dialog with something to show
/// under it (Layer Style's swatch) passes no `preview` and puts this in its `extras` instead.
struct DialogPreviewToggle: View {
    let isOn: Binding<Bool>
    var body: some View {
        Toggle("Preview", isOn: isOn).configuredNativeShortcut("p", modifiers: .option)
            .help("Show the change on the canvas (⌥P)")
    }
}

/// A push button as wide as the dialog's button column.
struct DialogButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    var body: some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }
            .accessibilityLabel(title)
    }
}

/// A labeled dialog row: the label (ending with a colon) right-aligned in a column `labelWidth` wide, then its
/// controls, so the rows of a dialog or group line up as a form.
struct DialogRow<Content: View>: View {
    let label: String
    var labelWidth: CGFloat = 80
    let content: Content

    init(_ label: String, labelWidth: CGFloat = 80, @ViewBuilder content: () -> Content) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: labelWidth, alignment: .trailing)
            content
        }
    }
}

/// A titled group of dialog settings ("Stroke", "Location", "New Size"), drawn as the system's group box.
struct DialogGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title).font(.system(size: 12, weight: .semibold))
        }
    }
}
