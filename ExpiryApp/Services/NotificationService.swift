import Foundation
import UserNotifications

enum NotificationService {
    static let digestIdentifier = "expiry.daily.digest"

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleDailyDigest(
        products: [Product],
        rules: [CategoryRule],
        settings: UserSettings
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [digestIdentifier])

        let lookahead = settings.reminderLookaheadDays
        let expiringSoon = products.filter {
            let days = ExpiryCalculator.daysUntilExpiry(
                ExpiryCalculator.effectiveExpiryDate(product: $0, rules: rules)
            )
            return days >= 0 && days <= lookahead
        }

        guard !expiringSoon.isEmpty else { return }

        let content = UNMutableNotificationContent()
        let count = expiringSoon.reduce(0) { $0 + $1.quantity }
        let titleFormat = NSLocalizedString("notification.title", comment: "")
        content.title = String(format: titleFormat, count)

        let list = expiringSoon
            .prefix(3)
            .map { "\($0.name) (x\($0.quantity))" }
            .joined(separator: ", ")
        let bodyFormat = NSLocalizedString("notification.body", comment: "")
        content.body = String(format: bodyFormat, list)

        var components = DateComponents()
        components.hour = settings.dailyDigestHour
        components.minute = settings.dailyDigestMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: digestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
