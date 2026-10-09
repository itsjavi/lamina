import LaminaCore
import SwiftUI

/// The Adjustments panel, in the dock's top group beside Properties (docs/DESIGN.md, Dock and panels): a grid of
/// labeled icons, each adding its adjustment layer in one click, then Lamina's filter layers in their own section.
struct AdjustmentsPanel: View {
    @Bindable var session: EditorSession
    let layout: DockLayout

    /// The single adjustments, in the order familiar editors list them.
    static let adjustments: [AdjustmentKind] = [.grain, .levels, .curves, .exposure, .hsv, .colorBalance, .blackWhite,
                                                .invert, .gradientMap]
    /// Lamina's live filter layers.
    static let filterLayers: [AdjustmentKind] = [.gaussianBlur, .motionBlur, .addNoise]

    /// Four cells a row at the dock's default 292 pt, three at its narrowest.
    private let columns = [GridItem(.adaptive(minimum: 62), spacing: 2)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                grid(Self.adjustments)
                Divider().overlay(ColorRole.separator.color)
                HStack(spacing: 5) {
                    Text("Filter layers").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(ColorRole.text.color)
                    Text("Lamina").font(.system(size: 9.5)).foregroundStyle(ColorRole.secondaryText.color)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(ColorRole.control.color, in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 1)
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                grid(Self.filterLayers)
            }
        }
        .background(ColorRole.panel.color)
        .disabled(!Self.canAdd(session))
    }

    private func grid(_ kinds: [AdjustmentKind]) -> some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(kinds, id: \.self) { kind in
                AdjustmentCell(kind: kind) { Self.add(kind, session: session, layout: layout) }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    /// Layer ▸ New Adjustment Layer's enable rule.
    static func canAdd(_ session: EditorSession) -> Bool { session.canEditLayers && session.document != nil }

    /// What a click does: the menu's command (one undo step, the new layer above the active one and selected), then
    /// Properties comes forward to show the adjustment's controls.
    static func add(_ kind: AdjustmentKind, session: EditorSession, layout: DockLayout) {
        guard canAdd(session) else { return }
        session.addAdjustment(kind)
        layout.show(.properties)
    }
}

extension AdjustmentKind {
    /// The adjustment's SF Symbol in the Adjustments panel.
    var panelSymbol: String {
        switch self {
        case .grain: "film"
        case .levels: "chart.bar.xaxis"
        case .curves: "point.bottomleft.forward.to.point.topright.scurvepath"
        case .exposure: "plusminus.circle"
        case .hsv: "drop.halffull"
        case .colorBalance: "slider.horizontal.3"
        case .blackWhite: "circle.lefthalf.filled"
        case .invert: "circle.righthalf.filled.inverse"
        case .gradientMap: "rectangle.split.3x1"
        case .gaussianBlur: "camera.aperture"
        case .motionBlur: "wind"
        case .addNoise: "aqi.medium"
        }
    }
}

/// One cell of the grid: an 18 pt icon over its name, highlighted under the pointer.
private struct AdjustmentCell: View {
    let kind: AdjustmentKind
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: kind.panelSymbol).font(.system(size: 18)).frame(height: 22)
                Text(kind.rawValue).font(.system(size: 10)).lineLimit(2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ColorRole.icon.color)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .top)
            .padding(.top, 5).padding(.bottom, 4).padding(.horizontal, 2)
            .background(isHovered && isEnabled ? ColorRole.hover.color : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
        .help(kind.rawValue)
        .accessibilityLabel(kind.rawValue)
    }
}
