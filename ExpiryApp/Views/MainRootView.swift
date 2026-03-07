import SwiftUI
import SwiftData

private enum AppSection {
    case shopping
    case products
    case insights
    case settings
}

struct MainRootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @Query
    private var settingsList: [UserSettings]

    @State private var selectedSection: AppSection = .shopping
    @State private var showAddSheet = false
    private var settings: UserSettings? {
        settingsList.first
    }

    private var productDigestSignature: [String] {
        products.map {
            "\($0.id.uuidString)-\($0.expiryDate.timeIntervalSince1970)-\($0.openedAt?.timeIntervalSince1970 ?? -1)-\($0.customAfterOpeningDays ?? -1)-\($0.quantity)"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            currentSectionView
                .padding(.bottom, 88)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditProductView(product: nil)
        }
        .task {
            SeedService.seedIfNeeded(context: modelContext)
            _ = await NotificationService.requestPermission()
            await rescheduleDigestIfPossible()
        }
        .onChange(of: productDigestSignature) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
        .onChange(of: rules.map(\.defaultAfterOpeningDays)) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
        .onChange(of: settings?.reminderLookaheadDays) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
        .onChange(of: settings?.dailyDigestHour) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
        .onChange(of: settings?.dailyDigestMinute) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
        .onChange(of: settings?.notificationsEnabled) { _, _ in
            Task { await rescheduleDigestIfPossible() }
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .shopping:
            if FeatureFlags.useCoreDataShopping {
                CoreDataShoppingView()
            } else {
                RecipeSuggestionsView()
            }
        case .products:
            ProductListView(onAddProductTap: { showAddSheet = true })
        case .insights:
            CalendarExpiryView()
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

    private func rescheduleDigestIfPossible() async {
        guard let settings else { return }
        await NotificationService.scheduleDailyDigest(products: products, rules: rules, settings: settings)
    }
}
