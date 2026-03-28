import SwiftUI

private enum AppSection {
    case shopping
    case products
    case insights
    case settings
}

struct MainRootView: View {
    @State private var selectedSection: AppSection = .shopping

    var body: some View {
        ZStack(alignment: .bottom) {
            currentSectionView
                .padding(.bottom, 88)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .task { _ = await NotificationService.requestPermission() }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .shopping:
            CoreDataShoppingView()
        case .products:
            CoreDataExpirationView()
        case .insights:
            CoreDataInsightsView()
        case .settings:
            SettingsView()
        }
    }

    private var bottomBar: some View {
        HStack {
            navItem(systemName: "cart", label: L("tab.list"), isSelected: selectedSection == .shopping) {
                selectedSection = .shopping
            }

            Spacer(minLength: 0)

            navItem(systemName: "calendar", label: L("tab.expiration"), isSelected: selectedSection == .products) {
                selectedSection = .products
            }

            Spacer(minLength: 0)

            navItem(systemName: "chart.bar", label: L("tab.stats"), isSelected: selectedSection == .insights) {
                selectedSection = .insights
            }

            Spacer(minLength: 0)

            navItem(systemName: "gearshape", label: L("tab.settings"), isSelected: selectedSection == .settings) {
                selectedSection = .settings
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func navItem(systemName: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .blue : .primary)
            .frame(minWidth: 56)
        }
    }
}
