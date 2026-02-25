import Foundation
import SwiftData

enum SeedService {
    static func seedIfNeeded(context: ModelContext) {
        var settingsDescriptor = FetchDescriptor<UserSettings>()
        settingsDescriptor.fetchLimit = 1

        if (try? context.fetchCount(settingsDescriptor)) == 0 {
            context.insert(UserSettings())
        }

        let existingRules = (try? context.fetch(FetchDescriptor<CategoryRule>())) ?? []
        let existingCategories = Set(existingRules.map(\.category))

        for category in ProductCategory.allCases where !existingCategories.contains(category) {
            let defaultDays = CategoryDefaults.afterOpeningDays[category] ?? 3
            context.insert(CategoryRule(category: category, defaultAfterOpeningDays: defaultDays))
        }

        try? context.save()
    }
}
