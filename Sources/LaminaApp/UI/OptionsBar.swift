import SwiftUI

/// The bar above the canvas: the active tool's icon, then that tool's settings. It is the same height for every tool,
/// so switching tools never moves the canvas.
struct OptionsBar<Settings: View>: View {
    let session: EditorSession
    @ViewBuilder var settings: Settings

    var body: some View {
        HStack(spacing: 0) {
            ToolIcon(tool: session.tool, size: 16)
                .foregroundStyle(ColorRole.text.color)
                .frame(width: OptionsBarStyle.iconSlotWidth)
                .help(session.tool.label)
                .accessibilityLabel(session.tool.label)
                .accessibilityIdentifier("optionsBarTool")
            OptionsBarDivider()
            settings.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ToolHeaderStyle.height)
    }
}

enum OptionsBarStyle {
    /// The toolbar's width in docs/DESIGN.md, so the icon sits over the column it was picked from.
    static let iconSlotWidth: CGFloat = 44
}

/// The 1 × 20 pt line between a bar's groups.
struct OptionsBarDivider: View {
    var body: some View { ColorRole.separator.color.frame(width: 1, height: 20) }
}

/// A bar's icon button, 24 × 22: the icon alone, with its name as the help tag and accessibility label. A pressed one
/// (the chosen selection mode, a pressure toggle that is on) sits on `activeTool`.
struct OptionsBarIconButton<Icon: View>: View {
    let title: String
    var isPressed = false
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        Button(action: action) {
            icon.frame(width: 24, height: 22)
                .background(isPressed ? ColorRole.activeTool.color : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isPressed ? .isSelected : [])
    }
}

extension OptionsBarIconButton where Icon == Image {
    init(title: String, symbol: String, isPressed: Bool = false, action: @escaping () -> Void) {
        self.init(title: title, isPressed: isPressed, action: action) { Image(systemName: symbol) }
    }
}

/// A tool's settings, left to right. While an edit is in progress, its Cancel ⊘ and Commit ✓ sit at the far right,
/// after a divider, where the Free Transform bar has them. In a window too narrow for the bar, the settings keep their
/// size and scroll sideways (no scroller), and Cancel and Commit stay pinned outside the scroll.
struct OptionsBarRow<Content: View>: View {
    var commit: OptionsBarCommitButtons? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) { content }.padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
            }
            // .never, not .hidden: .hidden still shows a legacy scroller ("Show scroll bars: Always", or a mouse).
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            if let commit {
                OptionsBarDivider()
                commit.padding(.horizontal, 8)
            }
        }
        .toolHeaderBar()
    }
}

/// Cancel ⊘ and Commit ✓, the end of every bar with an edit in progress. Return and Escape stay with the canvas.
struct OptionsBarCommitButtons: View {
    let cancelTitle: String
    let commitTitle: String
    let cancel: () -> Void
    let commit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            OptionsBarIconButton(title: cancelTitle, symbol: "nosign", action: cancel)
                .accessibilityIdentifier("optionsBarCancel")
            OptionsBarIconButton(title: commitTitle, symbol: "checkmark", action: commit)
                .accessibilityIdentifier("optionsBarCommit")
        }
    }
}

/// The active tool's settings, which the options bar shows after the tool's icon.
struct ToolSettings: View {
    @Bindable var session: EditorSession

    var body: some View {
        Group {
            // A Free Transform waiting for Commit or Cancel turns the Move bar into the Free Transform bar; a drag
            // that applies itself when let go (a move, a nudge) leaves the Move bar in place.
            if session.tool == .move, session.transformEdit?.persistent == true {
                FreeTransformBar(session: session).id(session.activeLayerID)
            } else if session.tool == .move {
                MoveToolBar(session: session)
            }
            if session.tool.isBrushTool {
                BrushControls(session: session)
            }
            if session.tool.isSelectionTool {
                LassoControls(session: session)
            }
            if session.tool == .gradient {
                GradientControls(session: session)
            }
            if session.tool == .paintBucket {
                PaintBucketControls(session: session)
            }
            if session.tool == .type {
                TypeControls(session: session)
            }
            if session.tool.shapeKind != nil {
                ShapeControls(session: session)
            }
            if session.tool == .eyedropper {
                OptionsBarRow {
                    Toggle("Show Sampling Ring", isOn: $session.showsSampleRing).toggleStyle(.checkbox)
                        .help("Show a ring of the color under the pointer and the one before it while sampling")
                }
            }
            if session.tool == .hand || session.tool == .zoom {
                NavigationToolHeader(session: session)
            }
            if session.tool == .crop {
                CropControls(session: session)
            }
            // No tool (A) keeps the bar, its icon and nothing after it, so the canvas doesn't jump.
            if session.tool == .idle {
                Spacer().toolHeaderBar()
            }
        }
    }
}
