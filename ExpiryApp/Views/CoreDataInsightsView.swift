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

@MainActor
final class CoreDataInsightsViewModel: ObservableObject {
    @Published var events: [CoreDataConsumptionEvent] = []
    @Published var error: String?

    private let repository: CoreDataExpirationRepository
    private let calendar = Calendar.current

    init(repository: CoreDataExpirationRepository = CoreDataExpirationRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            events = try repository.fetchConsumptionEvents()
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

    func wastedItems(limit: Int = 5) -> [CoreDataItemWasteInsight] {
        let grouped = Dictionary(grouping: events) { $0.productName.lowercased() }
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
}

struct CoreDataInsightsView: View {
    @StateObject private var vm = CoreDataInsightsViewModel()
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard
                    trendCard
                    wastedItemsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(L("insights.title"))
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

    private var thisMonthStart: Date { vm.monthStart(Date()) }
    private var previousMonthStart: Date { calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart }
    private var thisMonthScore: Int { vm.monthScore(for: thisMonthStart) }
    private var previousMonthScore: Int { vm.monthScore(for: previousMonthStart) }
    private var scoreDelta: Int { thisMonthScore - previousMonthScore }

    private var lastSixMonths: [CoreDataMonthlyInsight] {
        var output: [CoreDataMonthlyInsight] = []
        for offset in stride(from: 5, through: 0, by: -1) {
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
        if thisMonthScore < 50 { return .red }
        if thisMonthScore < 75 { return .orange }
        return .green
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
                    .trim(from: 0, to: CGFloat(thisMonthScore) / 100)
                    .stroke(scoreRingColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)

                Text("\(thisMonthScore)%")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
            }

            HStack(spacing: 6) {
                Text(L("insights.this_month"))
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
            Text(L("insights.trend_6m"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(lastSixMonths) { month in
                    VStack(spacing: 8) {
                        Text("\(month.score)%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .frame(width: 42, height: max(18, CGFloat(month.score)))

                        Text(monthLabel(month.monthStart))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var wastedItemsCard: some View {
        let items = vm.wastedItems()
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

    private var scoreDeltaText: String {
        if scoreDelta == 0 { return L("insights.delta_equal") }
        if scoreDelta > 0 { return String(format: L("insights.delta_up"), scoreDelta) }
        return String(format: L("insights.delta_down"), abs(scoreDelta))
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

    private func appLocale() -> Locale {
        let code = UserDefaults.standard.string(forKey: "app.preferred_language_code") ?? "system"
        if code == "system" { return .current }
        return Locale(identifier: code)
    }
}
