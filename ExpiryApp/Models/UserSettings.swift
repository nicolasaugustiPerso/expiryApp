import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var reminderLookaheadDays: Int
    var dailyDigestHour: Int
    var dailyDigestMinute: Int

    init(
        id: UUID = UUID(),
        reminderLookaheadDays: Int = 2,
        dailyDigestHour: Int = 20,
        dailyDigestMinute: Int = 0
    ) {
        self.id = id
        self.reminderLookaheadDays = reminderLookaheadDays
        self.dailyDigestHour = dailyDigestHour
        self.dailyDigestMinute = dailyDigestMinute
    }
}
