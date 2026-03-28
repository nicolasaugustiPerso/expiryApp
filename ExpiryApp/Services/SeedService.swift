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

        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        if existingCategories.isEmpty {
            for seed in CategoryDefaults.systemSeeds {
                context.insert(Category(
                    key: seed.key,
                    name: seed.name,
                    symbolName: seed.symbolName,
                    tintColorHex: seed.tintColorHex,
                    isSystem: seed.isSystem
                ))
            }
        }

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let existingRules = (try? context.fetch(FetchDescriptor<CategoryRule>())) ?? []
        let existingRuleKeys = Set(existingRules.map(\.categoryRawValue))
        for category in categories {
            guard !existingRuleKeys.contains(category.key) else { continue }
            let defaultDays = CategoryDefaults.defaultAfterOpeningDaysByKey[category.key] ?? 3
            let trackingEnabled = CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[category.key] ?? true
            context.insert(CategoryRule(
                categoryKey: category.key,
                defaultAfterOpeningDays: defaultDays,
                isExpiryTrackingEnabled: trackingEnabled
            ))
        }

        do {
            try context.save()
        } catch {
            print("SeedService save failed: \(error)")
        }
    }
}
