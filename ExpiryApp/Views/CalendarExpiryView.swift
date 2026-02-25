import SwiftUI
import SwiftData

private enum CalendarMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        NSLocalizedString("calendar.mode.\(rawValue)", comment: "")
    }
}

struct CalendarExpiryView: View {
    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @State private var mode: CalendarMode = .day
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $mode) {
                    ForEach(CalendarMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .day:
                    daySection
                case .week:
                    weekSection
                case .month:
                    monthSection
                }
            }
            .navigationTitle(NSLocalizedString("calendar.title", comment: ""))
        }
    }

    private var daySection: some View {
        Section {
            let today = calendar.startOfDay(for: .now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let todayCount = itemCountForDay(today)
            let tomorrowCount = itemCountForDay(tomorrow)

            HStack {
                Button(
                    String(
                        format: NSLocalizedString("calendar.quick_with_count", comment: ""),
                        NSLocalizedString("calendar.today", comment: ""),
                        todayCount
                    )
                ) {
                    selectedDay = today
                }
                .buttonStyle(.bordered)

                Button(
                    String(
                        format: NSLocalizedString("calendar.quick_with_count", comment: ""),
                        NSLocalizedString("calendar.tomorrow", comment: ""),
                        tomorrowCount
                    )
                ) {
                    selectedDay = tomorrow
                }
                .buttonStyle(.bordered)
            }

            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let dayProducts = productsForDay(selectedDay)
            if dayProducts.isEmpty {
                Text(NSLocalizedString("calendar.empty_day", comment: ""))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dayProducts) { product in
                    ProductRowView(
                        product: product,
                        effectiveExpiry: ExpiryCalculator.effectiveExpiryDate(product: product, rules: rules)
                    )
                }
            }
        }
    }

    private var weekSection: some View {
        Section(NSLocalizedString("calendar.week_title", comment: "")) {
            ForEach(nextDays(7), id: \.self) { day in
                Button {
                    selectedDay = day
                    mode = .day
                } label: {
                    HStack {
                        Text(day.formatted(.dateTime.weekday(.abbreviated).day().month()))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(String(format: NSLocalizedString("calendar.count", comment: ""), itemCountForDay(day)))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthSection: some View {
        Section(NSLocalizedString("calendar.month_title", comment: "")) {
            let days = nextDays(30)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let count = itemCountForDay(day)
                    Button {
                        selectedDay = day
                        mode = .day
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(count > 0 ? .blue : .secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.vertical, 4)
                        .background(count > 0 ? Color.blue.opacity(0.12) : Color.gray.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
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
}
