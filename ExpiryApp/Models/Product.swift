import Foundation
import SwiftData

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Product.self, CategoryRule.self, UserSettings.self]
    }

    @Model
    final class Product {
        var id: UUID
        var name: String
        var categoryRawValue: String
        var expiryDate: Date
        var openedAt: Date?
        var customAfterOpeningDays: Int?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            categoryRawValue: String,
            expiryDate: Date,
            openedAt: Date? = nil,
            customAfterOpeningDays: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = categoryRawValue
            self.expiryDate = expiryDate
            self.openedAt = openedAt
            self.customAfterOpeningDays = customAfterOpeningDays
            self.createdAt = createdAt
        }
    }

    @Model
    final class CategoryRule {
        var id: UUID
        var categoryRawValue: String
        var defaultAfterOpeningDays: Int

        init(id: UUID = UUID(), categoryRawValue: String, defaultAfterOpeningDays: Int) {
            self.id = id
            self.categoryRawValue = categoryRawValue
            self.defaultAfterOpeningDays = defaultAfterOpeningDays
        }
    }

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
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Product.self, CategoryRule.self, UserSettings.self]
    }

    @Model
    final class Product {
        var id: UUID
        var name: String
        var categoryRawValue: String
        var expiryDate: Date
        var openedAt: Date?
        var quantity: Int = 1
        var customAfterOpeningDays: Int?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory,
            expiryDate: Date,
            openedAt: Date? = nil,
            quantity: Int = 1,
            customAfterOpeningDays: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = category.rawValue
            self.expiryDate = expiryDate
            self.openedAt = openedAt
            self.quantity = max(1, quantity)
            self.customAfterOpeningDays = customAfterOpeningDays
            self.createdAt = createdAt
        }

        var category: ProductCategory {
            get { ProductCategory(rawValue: categoryRawValue) ?? .other }
            set { categoryRawValue = newValue.rawValue }
        }
    }

    @Model
    final class CategoryRule {
        var id: UUID
        var categoryRawValue: String
        var defaultAfterOpeningDays: Int

        init(id: UUID = UUID(), category: ProductCategory, defaultAfterOpeningDays: Int) {
            self.id = id
            self.categoryRawValue = category.rawValue
            self.defaultAfterOpeningDays = defaultAfterOpeningDays
        }

        var category: ProductCategory {
            get { ProductCategory(rawValue: categoryRawValue) ?? .other }
            set { categoryRawValue = newValue.rawValue }
        }
    }

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
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}

typealias Product = AppSchemaV2.Product
