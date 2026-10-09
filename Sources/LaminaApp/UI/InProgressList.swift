import SwiftUI

/// A placeholder's icon as its control shows it: a planned tool's toolbar icon, or the symbol of a panel or bar
/// control; nothing for menu items and text controls.
struct PlannedFeatureIcon: View {
    let feature: PlannedFeature

    var body: some View {
        if feature.home == .toolbar {
            ToolIcon(item: .planned(feature), size: 16)
        } else if let symbol = feature.symbol {
            Image(systemName: symbol)
        }
    }
}

/// Help › Features in Progress…: every control in the interface whose feature is still being built, grouped by where
/// it lives, with its icon, where to find it and the task that delivers it (docs/DESIGN.md, In-progress placeholders).
/// It reads `PlannedFeature`, so it lists exactly the placeholders there are.
struct InProgressListView: View {
    var body: some View {
        ScrollView { InProgressListContent().padding(20) }
            .frame(width: 520, height: 560)
            .background(ColorRole.panel.color)
    }
}

/// The list itself, every group in full.
struct InProgressListContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("These controls are already where they will be, but what they do is still being built: using one says so and changes nothing.")
                .font(.system(size: 12)).foregroundStyle(ColorRole.secondaryText.color)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(PlannedFeature.Category.allCases, id: \.self) { category in
                let features = PlannedFeature.allCases.filter { $0.category == category }
                if !features.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.title).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ColorRole.text.color).padding(.bottom, 4)
                        ForEach(features) { row($0) }
                    }
                }
            }
        }
        .frame(width: 480, alignment: .leading)
    }

    private func row(_ feature: PlannedFeature) -> some View {
        HStack(spacing: 10) {
            // The column stays when there's no icon, so every name lines up.
            ZStack { PlannedFeatureIcon(feature: feature).font(.system(size: 14)).foregroundStyle(ColorRole.icon.color) }
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(feature.name).font(.system(size: 12)).foregroundStyle(ColorRole.text.color)
                Text(feature.location).font(.system(size: 11)).foregroundStyle(ColorRole.secondaryText.color)
            }
            Spacer(minLength: 8)
            Text(feature.task).font(.system(size: 11)).monospacedDigit().foregroundStyle(ColorRole.tertiaryText.color)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { ColorRole.separator.color.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

/// The floating panel Help › Features in Progress… opens.
@MainActor
final class InProgressList {
    static let shared = InProgressList()
    private let panel = FloatingPanelController(name: "inProgress")
    func show() { panel.show(title: "Features in Progress", content: InProgressListView()) }
}
