import SwiftUI

private struct CoreDataMonthlyInsight: Identifiable {
    let monthStart: Date
    let score: Int
    let total: Int
    var id: Date { monthStart }
}

private struct CoreDataItemWasteInsight: Identifiable {
    let name: String
    let expired: Int
    let total: Int

    var id: String { name.lowercased() }
    var ratio: Double { total > 0 ? Double(expired) / Double(total) : 0 }
}

private struct CoreDataTopProductInsight: Identifiable {
    let name: String
    let total: Int
    let consumedBeforeExpiry: Int?

    var id: String { name.lowercased() }
    var antiWasteScore: Int? {
        guard let consumedBeforeExpiry else { return nil }
        guard total > 0 else { return 0 }
        return Int((Double(consumedBeforeExpiry) / Double(total) * 100).rounded())
    }
}

private struct CoreDataCategoryDistributionInsight: Identifiable {
    let categoryKey: String
    let total: Int
    let ratio: Double

    var id: String { categoryKey }
}

@MainActor
final class CoreDataInsightsViewModel: ObservableObject {
    @Published var events: [CoreDataConsumptionEvent] = []
    @Published var shoppingItems: [CoreDataShoppingItem] = []
    @Published var categories: [CoreDataCategory] = []
    @Published var error: String?

    private let repository: CoreDataExpirationRepository
    private let shoppingRepository: CoreDataShoppingRepository
    private let categoryRepository: CoreDataCategoryRepository
    private let calendar = Calendar.current

    init(
        repository: CoreDataExpirationRepository = CoreDataExpirationRepository(),
        shoppingRepository: CoreDataShoppingRepository = CoreDataShoppingRepository(),
        categoryRepository: CoreDataCategoryRepository = CoreDataCategoryRepository()
    ) {
        self.repository = repository
        self.shoppingRepository = shoppingRepository
        self.categoryRepository = categoryRepository
    }

    func load() {
        do {
            events = try repository.fetchConsumptionEvents()
            shoppingItems = try shoppingRepository.fetchShoppingItems()
            categories = try categoryRepository.fetchCategories()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func monthScore(for month: Date) -> Int {
        score(for: eventsForMonth(month))
    }

    func eventsForMonth(_ month: Date) -> [CoreDataConsumptionEvent] {
        events.filter {
            calendar.isDate($0.consumedAt, equalTo: month, toGranularity: .month) &&
            calendar.isDate($0.consumedAt, equalTo: month, toGranularity: .year)
        }
    }

    func score(for source: [CoreDataConsumptionEvent]) -> Int {
        let total = source.reduce(0) { $0 + max(1, $1.quantity) }
        guard total > 0 else { return 0 }
        let nonExpired = source.reduce(0) { partial, event in
            partial + (event.consumedBeforeExpiry ? max(1, event.quantity) : 0)
        }
        return Int((Double(nonExpired) / Double(total) * 100).rounded())
    }

    func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    fileprivate func wastedItems(
        limit: Int = 5,
        source: [CoreDataConsumptionEvent]? = nil
    ) -> [CoreDataItemWasteInsight] {
        let input = source ?? events
        let grouped = Dictionary(grouping: input) { $0.productName.lowercased() }
        let items = grouped.compactMap { _, values -> CoreDataItemWasteInsight? in
            guard let first = values.first else { return nil }
            let name = first.productName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let total = values.reduce(0) { $0 + max(1, $1.quantity) }
            let expired = values.reduce(0) { partial, event in
                partial + (event.consumedBeforeExpiry ? 0 : max(1, event.quantity))
            }
            guard total > 0, expired > 0 else { return nil }
            return CoreDataItemWasteInsight(name: name, expired: expired, total: total)
        }

        return items.sorted {
            if $0.ratio != $1.ratio { return $0.ratio > $1.ratio }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }

    fileprivate func topProducts(
        limit: Int = 5,
        source: [CoreDataConsumptionEvent]? = nil
    ) -> [CoreDataTopProductInsight] {
        let input = source ?? events
        let grouped = Dictionary(grouping: input) { $0.productName.lowercased() }
        let items = grouped.compactMap { _, values -> CoreDataTopProductInsight? in
            guard let first = values.first else { return nil }
            let name = first.productName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let total = values.reduce(0) { $0 + max(1, $1.quantity) }
            let consumedBeforeExpiry = values.reduce(0) { partial, event in
                partial + (event.consumedBeforeExpiry ? max(1, event.quantity) : 0)
            }
            guard total > 0 else { return nil }
            return CoreDataTopProductInsight(
                name: name,
                total: total,
                consumedBeforeExpiry: consumedBeforeExpiry
            )
        }

        return items.sorted {
            if $0.total != $1.total { return $0.total > $1.total }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    fileprivate func topProductsFromShopping(
        limit: Int = 5,
        source: [CoreDataShoppingItem]
    ) -> [CoreDataTopProductInsight] {
        let grouped = Dictionary(grouping: source) { $0.name.lowercased() }
        let items = grouped.compactMap { _, values -> CoreDataTopProductInsight? in
            guard let first = values.first else { return nil }
            let name = first.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let total = values.reduce(0) { $0 + max(1, $1.quantity) }
            guard total > 0 else { return nil }
            return CoreDataTopProductInsight(
                name: name,
                total: total,
                consumedBeforeExpiry: nil
            )
        }

        return items.sorted {
            if $0.total != $1.total { return $0.total > $1.total }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    fileprivate func categoryDistribution(
        limit: Int? = nil,
        source: [CoreDataConsumptionEvent]? = nil
    ) -> [CoreDataCategoryDistributionInsight] {
        let input = source ?? events
        let grouped = Dictionary(grouping: input) { event in
            CategoryDefaults.canonicalCategoryKey(event.categoryRawValue)
        }

        let totalsByCategory = grouped.mapValues { values in
            values.reduce(0) { $0 + max(1, $1.quantity) }
        }

        let grandTotal = totalsByCategory.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        let sorted = totalsByCategory
            .map { (key: $0.key, total: $0.value) }
            .sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }

        let limited = (limit != nil) ? Array(sorted.prefix(max(1, limit!))) : sorted

        return limited.map { item in
            CoreDataCategoryDistributionInsight(
                categoryKey: item.key,
                total: item.total,
                ratio: Double(item.total) / Double(grandTotal)
            )
        }
    }

    fileprivate func categoryDistributionFromShopping(
        limit: Int? = nil,
        source: [CoreDataShoppingItem]
    ) -> [CoreDataCategoryDistributionInsight] {
        let grouped = Dictionary(grouping: source) { item in
            CategoryDefaults.canonicalCategoryKey(item.categoryRawValue)
        }

        let totalsByCategory = grouped.mapValues { values in
            values.reduce(0) { $0 + max(1, $1.quantity) }
        }

        let grandTotal = totalsByCategory.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        let sorted = totalsByCategory
            .map { (key: $0.key, total: $0.value) }
            .sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }

        let limited = (limit != nil) ? Array(sorted.prefix(max(1, limit!))) : sorted

        return limited.map { item in
            CoreDataCategoryDistributionInsight(
                categoryKey: item.key,
                total: item.total,
                ratio: Double(item.total) / Double(grandTotal)
            )
        }
    }
}

struct CoreDataInsightsView: View {
    @StateObject private var vm = CoreDataInsightsViewModel()
    @State private var showAllTopProducts = false
    @State private var selectedWindowMonths = 6
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    periodSelectorCard
                    scoreCard
                    trendCard
                    topProductsCard
                    categoryDistributionCard
                    wastedItemsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(L("insights.title"))
            .task { vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
                vm.load()
            }
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

    private var thisMonthStart: Date { vm.monthStart(Date()) }
    private var periodMonthOptions: [Int] { [3, 6, 9, 12] }

    private var currentPeriodStart: Date {
        calendar.date(byAdding: .month, value: -(selectedWindowMonths - 1), to: thisMonthStart) ?? thisMonthStart
    }

    private var previousPeriodStart: Date {
        calendar.date(byAdding: .month, value: -selectedWindowMonths, to: currentPeriodStart) ?? currentPeriodStart
    }

    private var currentPeriodEvents: [CoreDataConsumptionEvent] {
        vm.events.filter { event in
            event.consumedAt >= currentPeriodStart
        }
    }

    private var currentPeriodBoughtShoppingItems: [CoreDataShoppingItem] {
        vm.shoppingItems.filter { item in
            guard item.isBought else { return false }
            let referenceDate = item.boughtAt ?? item.createdAt
            return referenceDate >= currentPeriodStart
        }
    }

    private var previousPeriodEvents: [CoreDataConsumptionEvent] {
        vm.events.filter { event in
            event.consumedAt >= previousPeriodStart && event.consumedAt < currentPeriodStart
        }
    }

    private var thisPeriodScore: Int { vm.score(for: currentPeriodEvents) }
    private var previousPeriodScore: Int { vm.score(for: previousPeriodEvents) }
    private var scoreDelta: Int { thisPeriodScore - previousPeriodScore }

    private var periodMonths: [CoreDataMonthlyInsight] {
        var output: [CoreDataMonthlyInsight] = []
        for offset in stride(from: selectedWindowMonths - 1, through: 0, by: -1) {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: thisMonthStart) else { continue }
            let monthEvents = vm.eventsForMonth(month)
            output.append(
                CoreDataMonthlyInsight(
                    monthStart: month,
                    score: vm.score(for: monthEvents),
                    total: monthEvents.reduce(0) { $0 + max(1, $1.quantity) }
                )
            )
        }
        return output
    }

    private var scoreRingColor: Color {
        if thisPeriodScore < 50 { return .red }
        if thisPeriodScore < 75 { return .orange }
        return .green
    }

    private var topProductsAll: [CoreDataTopProductInsight] {
        if !currentPeriodEvents.isEmpty {
            return vm.topProducts(limit: 20, source: currentPeriodEvents)
        }
        return vm.topProductsFromShopping(limit: 20, source: currentPeriodBoughtShoppingItems)
    }

    private var topProductsDisplayed: [CoreDataTopProductInsight] {
        if showAllTopProducts {
            return topProductsAll
        }
        return Array(topProductsAll.prefix(5))
    }

    private var categoryDistribution: [CoreDataCategoryDistributionInsight] {
        if !currentPeriodEvents.isEmpty {
            return vm.categoryDistribution(source: currentPeriodEvents)
        }
        return vm.categoryDistributionFromShopping(source: currentPeriodBoughtShoppingItems)
    }

    private var periodSelectorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("insights.period"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Period", selection: $selectedWindowMonths) {
                ForEach(periodMonthOptions, id: \.self) { months in
                    Text(String(format: L("insights.period_month_short"), months))
                        .tag(months)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text(L("insights.waste_score"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.22), lineWidth: 14)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(thisPeriodScore) / 100)
                    .stroke(scoreRingColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)

                Text("\(thisPeriodScore)%")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
            }

            HStack(spacing: 6) {
                Text(String(format: L("insights.this_period"), selectedWindowMonths))
                    .foregroundStyle(.secondary)
                Text(scoreDeltaText)
                    .foregroundStyle(scoreDeltaColor)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(format: L("insights.trend_n_months"), selectedWindowMonths))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let count = max(periodMonths.count, 1)
                let columnWidth = proxy.size.width / CGFloat(count)
                let barWidth = max(16, min(42, floor(columnWidth * 0.72)))

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(periodMonths) { month in
                        VStack(spacing: 8) {
                            Text("\(month.score)%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                                .frame(width: barWidth, height: max(18, CGFloat(month.score)))

                            Text(monthLabel(month.monthStart))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var wastedItemsCard: some View {
        let items = vm.wastedItems(source: currentPeriodEvents)
        return VStack(alignment: .leading, spacing: 14) {
            Text(L("insights.often_wasted"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text(L("insights.no_waste_items"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(items) { insight in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(localizedProductName(insight.name))
                                .font(.headline)
                            Spacer()
                            Text(String(format: L("insights.expired_over_total"), insight.expired, insight.total))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: insight.ratio)
                            .tint(progressColor(for: insight.ratio))
                        Text(recommendation(for: insight.ratio))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var topProductsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("insights.top_products"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            if topProductsDisplayed.isEmpty {
                Text(L("insights.no_top_products"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                HStack(spacing: 10) {
                    Text(" ")
                        .frame(width: 18)
                    Text(L("insights.top_col_product"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(L("insights.top_col_qty"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 22, alignment: .trailing)
                    Text(L("insights.top_col_score"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 42, alignment: .trailing)
                }

                ForEach(Array(topProductsDisplayed.enumerated()), id: \.element.id) { index, product in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(localizedProductName(product.name))
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Spacer()
                        HStack(spacing: 12) {
                            Text("\(product.total)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 22, alignment: .trailing)

                            Text(product.antiWasteScore.map { "\($0)%" } ?? "--")
                                .font(.subheadline.italic())
                                .foregroundStyle(antiWasteColor(for: product.antiWasteScore))
                                .frame(minWidth: 42, alignment: .trailing)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 2)
                }

                if topProductsAll.count > 5 {
                    Button(showAllTopProducts ? L("insights.top_see_less") : L("insights.top_see_more")) {
                        showAllTopProducts.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var categoryDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("insights.category_distribution"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            if categoryDistribution.isEmpty {
                Text(L("insights.no_category_distribution"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    donutChart
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categoryDistribution.prefix(6)) { insight in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForCategory(key: insight.categoryKey))
                                    .frame(width: 8, height: 8)
                                Text(displayNameForCategory(key: insight.categoryKey))
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(Int((insight.ratio * 100).rounded()))%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var donutChart: some View {
        let segments = donutSegments(from: categoryDistribution)

        return ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 14)
                .frame(width: 120, height: 120)

            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 14, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
            }

            VStack(spacing: 1) {
                Text(L("insights.total"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(categoryDistribution.reduce(0) { $0 + $1.total })")
                    .font(.headline.weight(.bold))
            }
        }
        .frame(width: 120, height: 120)
    }

    private var scoreDeltaText: String {
        if scoreDelta == 0 { return L("insights.delta_equal_period") }
        if scoreDelta > 0 { return String(format: L("insights.delta_up_period"), scoreDelta, selectedWindowMonths) }
        return String(format: L("insights.delta_down_period"), abs(scoreDelta), selectedWindowMonths)
    }

    private var scoreDeltaColor: Color {
        if scoreDelta > 0 { return .green }
        if scoreDelta < 0 { return .red }
        return .secondary
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date).capitalized
    }

    private func progressColor(for ratio: Double) -> Color {
        if ratio >= 0.6 { return .red }
        if ratio >= 0.35 { return .orange }
        return .green
    }

    private func recommendation(for ratio: Double) -> String {
        if ratio >= 0.6 { return L("insights.reco_high") }
        if ratio >= 0.35 { return L("insights.reco_medium") }
        return L("insights.reco_low")
    }

    private func antiWasteColor(for score: Int) -> Color {
        if score == 100 { return .green }
        if score < 80 { return .red }
        return .orange
    }

    private func antiWasteColor(for score: Int?) -> Color {
        guard let score else { return .secondary }
        return antiWasteColor(for: score)
    }

    private func appLocale() -> Locale {
        let code = UserDefaults.standard.string(forKey: "app.preferred_language_code") ?? "system"
        if code == "system" { return .current }
        return Locale(identifier: code)
    }

    private func displayNameForCategory(key: String) -> String {
        let canonical = CategoryDefaults.canonicalCategoryKey(key)
        if let category = vm.categories.first(where: { $0.key == canonical }) {
            return category.displayName
        }
        if let seed = CategoryDefaults.seed(for: canonical) {
            return L(seed.name)
        }
        if canonical == "other" {
            return L("category.other")
        }
        return canonical.capitalized
    }

    private func colorForCategory(key: String) -> Color {
        let canonical = CategoryDefaults.canonicalCategoryKey(key)
        if let category = vm.categories.first(where: { $0.key == canonical }) {
            return category.tintColor
        }
        if let seed = CategoryDefaults.seed(for: canonical) {
            return Color(hex: seed.tintColorHex) ?? .gray
        }
        return .gray
    }

    private func donutSegments(from entries: [CoreDataCategoryDistributionInsight]) -> [CoreDataDonutSegment] {
        var cursor = 0.0
        return entries.map { entry in
            let start = cursor
            let end = min(1.0, start + entry.ratio)
            cursor = end
            return CoreDataDonutSegment(
                id: entry.categoryKey,
                start: start,
                end: end,
                color: colorForCategory(key: entry.categoryKey)
            )
        }
    }
}

private struct CoreDataDonutSegment: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let color: Color
}
