import Foundation

enum ExpiryCalculator {
    static func effectiveExpiryDate(product: Product, rules: [CategoryRule]) -> Date {
        guard let openedAt = product.openedAt else {
            return product.expiryDate
        }

        let fallbackDays = CategoryDefaults.afterOpeningDays[product.category] ?? 3
        let ruleDays = product.customAfterOpeningDays
            ?? rules.first(where: { $0.category == product.category })?.defaultAfterOpeningDays
            ?? fallbackDays

        let openedExpiry = Calendar.current.date(byAdding: .day, value: ruleDays, to: openedAt) ?? product.expiryDate
        return min(product.expiryDate, openedExpiry)
    }

    static func daysUntilExpiry(_ date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let target = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: target).day ?? 0
    }
}
