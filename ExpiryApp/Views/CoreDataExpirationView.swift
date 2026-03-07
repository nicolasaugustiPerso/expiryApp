import SwiftUI

private struct CoreDataProductDateGroup: Identifiable {
    let date: Date
    let products: [CoreDataProduct]
    var id: Date { date }
}

@MainActor
final class CoreDataExpirationViewModel: ObservableObject {
    @Published var products: [CoreDataProduct] = []
    @Published var rules: [CoreDataCategoryRule] = []
    @Published var error: String?

    private let repository: CoreDataExpirationRepository
    private let calendar = Calendar.current

    init(repository: CoreDataExpirationRepository = CoreDataExpirationRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            products = try repository.fetchProducts()
            rules = try repository.fetchCategoryRules()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ product: CoreDataProduct) {
        do {
            try repository.deleteProduct(id: product.id)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleOpened(_ product: CoreDataProduct) {
        do {
            try repository.toggleOpened(id: product.id)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func consumeOne(_ product: CoreDataProduct) {
        do {
            try repository.consumeOne(id: product.id, effectiveExpiryDate: effectiveExpiryDate(for: product))
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func effectiveExpiryDate(for product: CoreDataProduct) -> Date {
        guard let openedAt = product.openedAt else { return product.expiryDate }
        let ruleDays = product.customAfterOpeningDays ?? defaultAfterOpeningDays(for: product.categoryRawValue)
        return calendar.date(byAdding: .day, value: max(1, ruleDays), to: openedAt) ?? product.expiryDate
    }

    func daysUntil(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func groupedByDate() -> [CoreDataProductDateGroup] {
        let grouped = Dictionary(grouping: products) { product in
            calendar.startOfDay(for: effectiveExpiryDate(for: product))
        }

        return grouped.keys.sorted().compactMap { day in
            guard let items = grouped[day] else { return nil }
            let sorted = items.sorted {
                let left = effectiveExpiryDate(for: $0)
                let right = effectiveExpiryDate(for: $1)
                if left != right { return left < right }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return CoreDataProductDateGroup(date: day, products: sorted)
        }
    }

    var urgentCounts: (expired: Int, today: Int, tomorrow: Int) {
        var expired = 0
        var today = 0
        var tomorrow = 0

        for product in products {
            let days = daysUntil(effectiveExpiryDate(for: product))
            if days < 0 { expired += product.quantity }
            else if days == 0 { today += product.quantity }
            else if days == 1 { tomorrow += product.quantity }
        }
        return (expired, today, tomorrow)
    }

    private func defaultAfterOpeningDays(for categoryRawValue: String) -> Int {
        if let rule = rules.first(where: { $0.categoryRawValue == categoryRawValue }) {
            return max(1, rule.defaultAfterOpeningDays)
        }
        let category = ProductCategory(rawValue: categoryRawValue) ?? .other
        return CategoryDefaults.afterOpeningDays[category] ?? 3
    }
}

struct CoreDataExpirationView: View {
    @StateObject private var vm = CoreDataExpirationViewModel()

    var body: some View {
        NavigationStack {
            List {
                if urgentTotal > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(String(format: L("home.urgent_title"), urgentTotal))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.red)
                        }
                        Text(urgentSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red.opacity(0.06))
                            )
                            .padding(.vertical, 4)
                    )
                }

                ForEach(vm.groupedByDate()) { group in
                    Section {
                        ForEach(group.products) { product in
                            row(product)
                                .swipeActions {
                                    Button(L("common.delete"), role: .destructive) {
                                        vm.delete(product)
                                    }
                                }
                        }
                    } header: {
                        Text(capitalizedDateHeader(group.date))
                            .textCase(nil)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .listSectionSpacing(8)
            .navigationTitle(L("app.title"))
            .task { vm.load() }
            .alert("Core Data", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button(L("common.done"), role: .cancel) {}
            } message: {
                Text(vm.error ?? "")
            }
        }
    }

    private func row(_ product: CoreDataProduct) -> some View {
        let effectiveExpiry = vm.effectiveExpiryDate(for: product)
        let days = vm.daysUntil(effectiveExpiry)
        let stateColor: Color = days < 0 ? .red : (days <= 2 ? .orange : .green)

        return HStack(spacing: 12) {
            Image(systemName: (ProductCategory(rawValue: product.categoryRawValue) ?? .other).symbolName)
                .font(.title3)
                .foregroundStyle(stateColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(localizedProductName(product.name))
                        .font(.headline)
                    Text("x\(product.quantity)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    Button {
                        vm.toggleOpened(product)
                    } label: {
                        Image(systemName: product.openedAt == nil ? "square" : "checkmark.square.fill")
                            .foregroundStyle(product.openedAt == nil ? .secondary : .green)
                    }
                    .buttonStyle(.plain)

                    Text(product.openedAt == nil ? L("product.not_opened") : String(format: L("product.opened_on"), product.openedAt!.formatted(.dateTime.day().month(.abbreviated))))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(daysLabel(days))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stateColor.opacity(0.15))
                .clipShape(Capsule())

            Button {
                vm.consumeOne(product)
            } label: {
                Image(systemName: "fork.knife.circle")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days < 0 { return L("status.expired") }
        if days == 0 { return L("status.today") }
        let format = L("status.in_days")
        return String(format: format, days)
    }

    private var urgentTotal: Int {
        vm.urgentCounts.expired + vm.urgentCounts.today + vm.urgentCounts.tomorrow
    }

    private var urgentSubtitle: String {
        let expired = String(format: L("home.urgent_expired"), vm.urgentCounts.expired)
        let today = String(format: L("home.urgent_today"), vm.urgentCounts.today)
        let tomorrow = String(format: L("home.urgent_tomorrow"), vm.urgentCounts.tomorrow)
        return "\(expired) · \(today) · \(tomorrow)"
    }

    private func capitalizedDateHeader(_ date: Date) -> String {
        let formatted = date.formatted(date: .complete, time: .omitted)
        guard let first = formatted.first else { return formatted }
        return String(first).uppercased() + formatted.dropFirst()
    }
}
