import Foundation
import SwiftData

enum SeedService {
    static func seedIfNeeded(context: ModelContext) {
        var settingsDescriptor = FetchDescriptor<UserSettings>()
        settingsDescriptor.fetchLimit = 1

        let settingsCount = (try? context.fetchCount(settingsDescriptor)) ?? 0
        if settingsCount == 0 {
            context.insert(UserSettings())
        }

        let existingRules = (try? context.fetch(FetchDescriptor<CategoryRule>())) ?? []
        if existingRules.isEmpty {
            for category in ProductCategory.allCases {
                let defaultDays = CategoryDefaults.afterOpeningDays[category] ?? 3
                context.insert(CategoryRule(category: category, defaultAfterOpeningDays: defaultDays))
            }
        }

        do {
            try context.save()
        } catch {
            print("SeedService save failed: \(error)")
        }
    }
}
