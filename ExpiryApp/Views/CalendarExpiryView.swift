import SwiftUI
import SwiftData

private struct MonthlyInsight: Identifiable {
    let monthStart: Date
    let score: Int
    let total: Int

    var id: Date { monthStart }
}

private struct ItemWasteInsight: Identifiable {
    let name: String
    let expired: Int
    let total: Int

    var id: String { name.lowercased() }
    var ratio: Double {
        guard total > 0 else { return 0 }
        return Double(expired) / Double(total)
    }
}

struct CalendarExpiryView: View {
    @Query(sort: [SortDescriptor(\ConsumptionEvent.consumedAt, order: .reverse)])
    private var events: [ConsumptionEvent]

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
        }
    }

    private var thisMonthStart: Date {
        monthStart(for: .now)
    }

    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
    }

    private var thisMonthScore: Int {
        monthScore(for: thisMonthStart)
    }

    private var previousMonthScore: Int {
        monthScore(for: previousMonthStart)
    }

    private var scoreDelta: Int {
        thisMonthScore - previousMonthScore
    }

    private var scoreRingColor: Color {
        if thisMonthScore < 50 { return .red }
        if thisMonthScore < 75 { return .orange }
        return .green
    }

    private var lastSixMonths: [MonthlyInsight] {
        let current = monthStart(for: .now)
        var months: [MonthlyInsight] = []

        for offset in stride(from: 5, through: 0, by: -1) {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: current) else { continue }
            let monthEvents = eventsForMonth(month)
            let total = monthEvents.reduce(0) { $0 + max(1, $1.quantity) }
            months.append(
                MonthlyInsight(
                    monthStart: month,
                    score: score(for: monthEvents),
                    total: total
                )
            )
        }
        return months
    }

    private var wastedItems: [ItemWasteInsight] {
        let grouped = Dictionary(grouping: events) { $0.productName.lowercased() }

        let ranked = grouped.compactMap { _, values -> ItemWasteInsight? in
            guard let first = values.first else { return nil }
            let name = first.productName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let total = values.reduce(0) { $0 + max(1, $1.quantity) }
            let expired = values.reduce(0) { partial, event in
                partial + (event.consumedBeforeExpiry ? 0 : max(1, event.quantity))
            }
            guard total > 0, expired > 0 else { return nil }

            return ItemWasteInsight(name: name, expired: expired, total: total)
        }

        return ranked
            .sorted {
                if $0.ratio != $1.ratio { return $0.ratio > $1.ratio }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
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
                            .frame(width: 42, height: max(18, CGFloat(month.score) * 1.0))

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
        VStack(alignment: .leading, spacing: 14) {
            Text(L("insights.often_wasted"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            if wastedItems.isEmpty {
                Text(L("insights.no_waste_items"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(wastedItems) { insight in
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

    private func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func eventsForMonth(_ month: Date) -> [ConsumptionEvent] {
        events.filter {
            calendar.isDate($0.consumedAt, equalTo: month, toGranularity: .month) &&
            calendar.isDate($0.consumedAt, equalTo: month, toGranularity: .year)
        }
    }

    private func monthScore(for month: Date) -> Int {
        score(for: eventsForMonth(month))
    }

    private func score(for monthEvents: [ConsumptionEvent]) -> Int {
        let total = monthEvents.reduce(0) { $0 + max(1, $1.quantity) }
        guard total > 0 else { return 0 }

        let consumedBeforeExpiry = monthEvents.reduce(0) { partial, event in
            partial + (event.consumedBeforeExpiry ? max(1, event.quantity) : 0)
        }
        return Int((Double(consumedBeforeExpiry) / Double(total) * 100).rounded())
    }

    private var scoreDeltaText: String {
        if scoreDelta == 0 { return L("insights.delta_equal") }
        if scoreDelta > 0 {
            let format = L("insights.delta_up")
            return String(format: format, scoreDelta)
        }
        let format = L("insights.delta_down")
        return String(format: format, abs(scoreDelta))
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
