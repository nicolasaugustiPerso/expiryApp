import SwiftUI
import SwiftData

private enum AppSection {
    case products
    case calendar
    case recipes
}

struct MainRootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @Query
    private var settingsList: [UserSettings]

    @State private var selectedSection: AppSection = .products
    @State private var showAddSheet = false
    @State private var showSettings = false

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
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        case .products:
            ProductListView()
        case .calendar:
            CalendarExpiryView()
        case .recipes:
            RecipeSuggestionsView()
        }
    }

    private var bottomBar: some View {
        HStack {
            navIcon(systemName: "house", isSelected: selectedSection == .products) {
                selectedSection = .products
            }

            Spacer(minLength: 0)

            navIcon(systemName: "calendar", isSelected: selectedSection == .calendar) {
                selectedSection = .calendar
            }

            Spacer(minLength: 0)

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            Spacer(minLength: 0)

            navIcon(systemName: "fork.knife", isSelected: selectedSection == .recipes) {
                selectedSection = .recipes
            }

            Spacer(minLength: 0)

            navIcon(systemName: "gearshape", isSelected: false) {
                showSettings = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func navIcon(systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? .blue : .primary)
                .frame(width: 28, height: 28)
        }
    }

    private func rescheduleDigestIfPossible() async {
        guard let settings else { return }
        await NotificationService.scheduleDailyDigest(products: products, rules: rules, settings: settings)
    }
}
