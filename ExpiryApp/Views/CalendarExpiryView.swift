import SwiftUI
import SwiftData

struct CalendarExpiryView: View {
    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    private let calendar = Calendar.current
    let onSelectDayWithItems: (Date) -> Void

    init(onSelectDayWithItems: @escaping (Date) -> Void = { _ in }) {
        self.onSelectDayWithItems = onSelectDayWithItems
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L("calendar.month_title")) {
                    let days = nextDays(30)
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(days, id: \.self) { day in
                            let count = itemCountForDay(day)
                            let daysUntil = ExpiryCalculator.daysUntilExpiry(day)
                            let hasItems = count > 0

                            Button {
                                guard hasItems else { return }
                                onSelectDayWithItems(day)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(day.formatted(.dateTime.day()))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundStyle(countTextColor(daysUntil: daysUntil, hasItems: hasItems))
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .padding(.vertical, 4)
                                .background(backgroundColor(daysUntil: daysUntil, hasItems: hasItems))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(!hasItems)
                        }
                    }
                }
            }
            .navigationTitle(L("calendar.title"))
        }
    }

    private func nextDays(_ count: Int) -> [Date] {
        let start = calendar.startOfDay(for: .now)
        return (0..<count).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func productsForDay(_ day: Date) -> [Product] {
        let target = calendar.startOfDay(for: day)
        return products.filter {
            let effective = ExpiryCalculator.effectiveExpiryDate(product: $0, rules: rules)
            return calendar.isDate(calendar.startOfDay(for: effective), inSameDayAs: target)
        }
    }

    private func itemCountForDay(_ day: Date) -> Int {
        productsForDay(day).reduce(0) { $0 + $1.quantity }
    }

    private func backgroundColor(daysUntil: Int, hasItems: Bool) -> Color {
        guard hasItems else { return Color.gray.opacity(0.12) }
        if daysUntil <= 0 { return Color.red.opacity(0.22) }
        if daysUntil <= 3 { return Color.orange.opacity(0.22) }
        return Color.green.opacity(0.22)
    }

    private func countTextColor(daysUntil: Int, hasItems: Bool) -> Color {
        guard hasItems else { return .secondary }
        if daysUntil <= 0 { return .red }
        if daysUntil <= 3 { return .orange }
        return .green
    }
}
