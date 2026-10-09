import SwiftUI
import LaminaCore

/// The Layers panel in the dock (its tab names it): the blend mode and Opacity on top, the layer list, and the footer
/// in the order familiar editors use (docs/DESIGN.md, Dock and panels).
struct LayersPanel: View {
    @Bindable var session: EditorSession
    /// The dock's width (DockLayout).
    var width: CGFloat = 252

    /// New fill or adjustment layer's menu, in the Layer menu's order and groups (docs/DESIGN.md, Menus).
    static let adjustmentMenu: [[AdjustmentKind]] = [[.grain], [.levels, .curves, .exposure],
                                                     [.hsv, .colorBalance, .blackWhite], [.invert, .gradientMap],
                                                     AdjustmentsPanel.filterLayers]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayerAppearanceControls(session: session, layerID: session.activeLayerID).id(session.activeLayerID)
            ColorRole.separator.color.frame(height: 1)
            if let layers = session.document?.layers, !layers.isEmpty {
                NativeLayerList(session: session)
            } else {
                DockEmptyState(symbol: "square.3.layers.3d", title: "No layers yet",
                               message: session.document == nil ? "Create a canvas or import an image." : "Import an image or add a blank layer.")
            }
            footer
        }
        .frame(width: width)
    }

    private var deleteTitle: String {
        session.selectedEffect != nil ? "Delete effect"
            : session.isMaskSelected ? "Delete layer mask"
            : session.selectedLayerIDs.count > 1 ? "Delete layers" : "Delete layer"
    }

    private var footer: some View {
        PropertiesFooter {
            Menu {
                // The Layer ▸ Layer Style items, each opening the Layer Style dialog on its page.
                ForEach(LayerStylePage.all, id: \.self) { page in
                    Button(page.title + "…") { session.openLayerStyle(page) }
                    if page == .blendingOptions { Divider() }
                }
            } label: {
                // "fx" in italic serif, as the rows' badge reads; the SF Symbol draws it as capitals.
                Text(verbatim: "fx").font(.system(size: 15, weight: .semibold, design: .serif).italic())
                    .frame(width: 26, height: 24).contentShape(Rectangle())
                    .foregroundStyle(ColorRole.icon.color)
            }
                .layersFooterMenu()
                .help("Add a layer style").accessibilityLabel("Add a layer style")
                .accessibilityIdentifier("layerEffects").disabled(!session.canOpenLayerStyle)
            LayerMaskMenu(session: session)
            Menu {
                ForEach(Self.adjustmentMenu.indices, id: \.self) { group in
                    if group > 0 { Divider() }
                    ForEach(Self.adjustmentMenu[group], id: \.self) { kind in
                        Button(kind.rawValue + (kind.isEditable ? "…" : "")) {
                            session.addAdjustment(kind)
                            session.showProperties()
                        }
                    }
                }
            } label: { LayersFooterIcon(symbol: "circle.lefthalf.filled") }
                .layersFooterMenu()
                .help("Create new fill or adjustment layer").accessibilityLabel("Create new fill or adjustment layer")
                .accessibilityIdentifier("addAdjustmentLayer").disabled(!AdjustmentsPanel.canAdd(session))
            PropertiesFooterButton(title: "Create a new group", symbol: "folder") { session.addGroup() }
                .accessibilityIdentifier("addGroup").disabled(!session.canEditLayers || session.document == nil)
            PropertiesFooterButton(title: "Create a new layer (⇧⌘N)", symbol: "plus.square") { session.addBlankLayer() }
                .accessibilityLabel("Create a new layer")
                .accessibilityIdentifier("addBlankLayer").disabled(!session.canEditLayers || session.document == nil)
            PropertiesFooterButton(title: deleteTitle, symbol: "trash") { session.deleteLayerOrMask() }
                .accessibilityIdentifier("deleteLayer")
                .disabled(!session.canEditLayers || session.activeLayer == nil)
        }
    }
}

/// A footer icon at the size of the Properties footer's buttons (15 pt in a 26 × 24 pt target).
struct LayersFooterIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15))
            .frame(width: 26, height: 24).contentShape(Rectangle())
            .foregroundStyle(ColorRole.icon.color)
    }
}

extension View {
    /// A footer button that opens a menu: the icon alone, without the menu's indicator.
    func layersFooterMenu() -> some View {
        menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }

    /// Makes a small footer icon easier to click. The padding is the clickable area, so the
    /// footer's own spacing is reduced to match and every icon keeps its old position.
    /// (Negative padding to hand the space back does not work: the button then only answers
    /// clicks inside its shrunken frame.)
    func footerHitArea() -> some View {
        padding(.horizontal, 8).padding(.vertical, 12)
            .contentShape(Rectangle())
    }
}
