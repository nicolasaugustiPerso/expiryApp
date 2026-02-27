import Foundation
import UserNotifications

enum NotificationService {
    static let digestIdentifier = "expiry.daily.digest"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    
    static func notificationsAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }
    
    static func removeDailyDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [digestIdentifier])
    }

    static func scheduleDailyDigest(
        products: [Product],
        rules: [CategoryRule],
        settings: UserSettings
    ) async {
        removeDailyDigest()
        guard settings.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()

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
        let titleFormat = L("notification.title")
        content.title = String(format: titleFormat, count)

        let list = expiringSoon
            .prefix(3)
            .map { "\(localizedProductName($0.name)) (x\($0.quantity))" }
            .joined(separator: ", ")
        let bodyFormat = L("notification.body")
        content.body = String(format: bodyFormat, list)

        var components = DateComponents()
        components.hour = settings.dailyDigestHour
        components.minute = settings.dailyDigestMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: digestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
