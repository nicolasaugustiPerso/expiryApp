import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var preferredLanguageCode: String = "system"
    var notificationsEnabled: Bool = true
    var reminderLookaheadDays: Int = 2
    var dailyDigestHour: Int = 20
    var dailyDigestMinute: Int = 0

    init(
        id: UUID = UUID(),
        preferredLanguageCode: String = "system",
        notificationsEnabled: Bool = true,
        reminderLookaheadDays: Int = 2,
        dailyDigestHour: Int = 20,
        dailyDigestMinute: Int = 0
    ) {
        self.id = id
        self.preferredLanguageCode = preferredLanguageCode
        self.notificationsEnabled = notificationsEnabled
        self.reminderLookaheadDays = reminderLookaheadDays
        self.dailyDigestHour = dailyDigestHour
        self.dailyDigestMinute = dailyDigestMinute
    }
}
