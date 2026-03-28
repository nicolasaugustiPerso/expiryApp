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

enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Product.self, CategoryRule.self, UserSettings.self, ShoppingItem.self]
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
        var shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue
        var shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue

        init(
            id: UUID = UUID(),
            preferredLanguageCode: String = "system",
            notificationsEnabled: Bool = true,
            reminderLookaheadDays: Int = 2,
            dailyDigestHour: Int = 20,
            dailyDigestMinute: Int = 0,
            shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue,
            shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue
        ) {
            self.id = id
            self.preferredLanguageCode = preferredLanguageCode
            self.notificationsEnabled = notificationsEnabled
            self.reminderLookaheadDays = reminderLookaheadDays
            self.dailyDigestHour = dailyDigestHour
            self.dailyDigestMinute = dailyDigestMinute
            self.shoppingModeRawValue = shoppingModeRawValue
            self.shoppingCaptureModeRawValue = shoppingCaptureModeRawValue
        }
    }

    @Model
    final class ShoppingItem {
        var id: UUID
        var name: String
        var categoryRawValue: String?
        var quantity: Int = 1
        var isBought: Bool = false
        var boughtAt: Date?
        var needsExpiryCapture: Bool = false
        var pendingExpiryDate: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory? = nil,
            quantity: Int = 1,
            isBought: Bool = false,
            boughtAt: Date? = nil,
            needsExpiryCapture: Bool = false,
            pendingExpiryDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = category?.rawValue
            self.quantity = max(1, quantity)
            self.isBought = isBought
            self.boughtAt = boughtAt
            self.needsExpiryCapture = needsExpiryCapture
            self.pendingExpiryDate = pendingExpiryDate
            self.createdAt = createdAt
        }

        var category: ProductCategory? {
            get {
                guard let raw = categoryRawValue else { return nil }
                return ProductCategory(rawValue: raw)
            }
            set { categoryRawValue = newValue?.rawValue }
        }
    }
}

enum AppSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Product.self, CategoryRule.self, UserSettings.self, ShoppingItem.self, ConsumptionEvent.self]
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
        var shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue
        var shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue

        init(
            id: UUID = UUID(),
            preferredLanguageCode: String = "system",
            notificationsEnabled: Bool = true,
            reminderLookaheadDays: Int = 2,
            dailyDigestHour: Int = 20,
            dailyDigestMinute: Int = 0,
            shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue,
            shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue
        ) {
            self.id = id
            self.preferredLanguageCode = preferredLanguageCode
            self.notificationsEnabled = notificationsEnabled
            self.reminderLookaheadDays = reminderLookaheadDays
            self.dailyDigestHour = dailyDigestHour
            self.dailyDigestMinute = dailyDigestMinute
            self.shoppingModeRawValue = shoppingModeRawValue
            self.shoppingCaptureModeRawValue = shoppingCaptureModeRawValue
        }
    }

    @Model
    final class ShoppingItem {
        var id: UUID
        var name: String
        var categoryRawValue: String?
        var quantity: Int = 1
        var isBought: Bool = false
        var boughtAt: Date?
        var needsExpiryCapture: Bool = false
        var pendingExpiryDate: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory? = nil,
            quantity: Int = 1,
            isBought: Bool = false,
            boughtAt: Date? = nil,
            needsExpiryCapture: Bool = false,
            pendingExpiryDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = category?.rawValue
            self.quantity = max(1, quantity)
            self.isBought = isBought
            self.boughtAt = boughtAt
            self.needsExpiryCapture = needsExpiryCapture
            self.pendingExpiryDate = pendingExpiryDate
            self.createdAt = createdAt
        }

        var category: ProductCategory? {
            get {
                guard let raw = categoryRawValue else { return nil }
                return ProductCategory(rawValue: raw)
            }
            set { categoryRawValue = newValue?.rawValue }
        }
    }

    @Model
    final class ConsumptionEvent {
        var id: UUID
        var productName: String
        var categoryRawValue: String
        var quantity: Int
        var consumedAt: Date
        var effectiveExpiryDate: Date
        var consumedBeforeExpiry: Bool

        init(
            id: UUID = UUID(),
            productName: String,
            categoryRawValue: String,
            quantity: Int,
            consumedAt: Date = .now,
            effectiveExpiryDate: Date,
            consumedBeforeExpiry: Bool
        ) {
            self.id = id
            self.productName = productName
            self.categoryRawValue = categoryRawValue
            self.quantity = max(1, quantity)
            self.consumedAt = consumedAt
            self.effectiveExpiryDate = effectiveExpiryDate
            self.consumedBeforeExpiry = consumedBeforeExpiry
        }

        var category: ProductCategory {
            get { ProductCategory(rawValue: categoryRawValue) ?? .other }
            set { categoryRawValue = newValue.rawValue }
        }
    }
}

enum AppSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Product.self, CategoryRule.self, UserSettings.self, ShoppingItem.self, ConsumptionEvent.self]
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
        var isExpiryTrackingEnabled: Bool = true

        init(
            id: UUID = UUID(),
            category: ProductCategory,
            defaultAfterOpeningDays: Int,
            isExpiryTrackingEnabled: Bool = true
        ) {
            self.id = id
            self.categoryRawValue = category.rawValue
            self.defaultAfterOpeningDays = defaultAfterOpeningDays
            self.isExpiryTrackingEnabled = isExpiryTrackingEnabled
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
        var shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue
        var shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue

        init(
            id: UUID = UUID(),
            preferredLanguageCode: String = "system",
            notificationsEnabled: Bool = true,
            reminderLookaheadDays: Int = 2,
            dailyDigestHour: Int = 20,
            dailyDigestMinute: Int = 0,
            shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue,
            shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue
        ) {
            self.id = id
            self.preferredLanguageCode = preferredLanguageCode
            self.notificationsEnabled = notificationsEnabled
            self.reminderLookaheadDays = reminderLookaheadDays
            self.dailyDigestHour = dailyDigestHour
            self.dailyDigestMinute = dailyDigestMinute
            self.shoppingModeRawValue = shoppingModeRawValue
            self.shoppingCaptureModeRawValue = shoppingCaptureModeRawValue
        }
    }

    @Model
    final class ShoppingItem {
        var id: UUID
        var name: String
        var categoryRawValue: String?
        var quantity: Int = 1
        var isBought: Bool = false
        var boughtAt: Date?
        var needsExpiryCapture: Bool = false
        var pendingExpiryDate: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory? = nil,
            quantity: Int = 1,
            isBought: Bool = false,
            boughtAt: Date? = nil,
            needsExpiryCapture: Bool = false,
            pendingExpiryDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = category?.rawValue
            self.quantity = max(1, quantity)
            self.isBought = isBought
            self.boughtAt = boughtAt
            self.needsExpiryCapture = needsExpiryCapture
            self.pendingExpiryDate = pendingExpiryDate
            self.createdAt = createdAt
        }

        var category: ProductCategory? {
            get {
                guard let raw = categoryRawValue else { return nil }
                return ProductCategory(rawValue: raw)
            }
            set { categoryRawValue = newValue?.rawValue }
        }
    }

    @Model
    final class ConsumptionEvent {
        var id: UUID
        var productName: String
        var categoryRawValue: String
        var quantity: Int
        var consumedAt: Date
        var effectiveExpiryDate: Date
        var consumedBeforeExpiry: Bool

        init(
            id: UUID = UUID(),
            productName: String,
            categoryRawValue: String,
            quantity: Int,
            consumedAt: Date = .now,
            effectiveExpiryDate: Date,
            consumedBeforeExpiry: Bool
        ) {
            self.id = id
            self.productName = productName
            self.categoryRawValue = categoryRawValue
            self.quantity = max(1, quantity)
            self.consumedAt = consumedAt
            self.effectiveExpiryDate = effectiveExpiryDate
            self.consumedBeforeExpiry = consumedBeforeExpiry
        }

        var category: ProductCategory {
            get { ProductCategory(rawValue: categoryRawValue) ?? .other }
            set { categoryRawValue = newValue.rawValue }
        }
    }
}

enum AppSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Category.self, Product.self, CategoryRule.self, UserSettings.self, ShoppingItem.self, ConsumptionEvent.self]
    }

    @Model
    final class Category {
        var id: UUID
        var key: String
        var name: String
        var symbolName: String
        var tintColorHex: String
        var isSystem: Bool
        var createdAt: Date

        init(
            id: UUID = UUID(),
            key: String,
            name: String,
            symbolName: String,
            tintColorHex: String,
            isSystem: Bool,
            createdAt: Date = .now
        ) {
            self.id = id
            self.key = key
            self.name = name
            self.symbolName = symbolName
            self.tintColorHex = tintColorHex
            self.isSystem = isSystem
            self.createdAt = createdAt
        }
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
            categoryKey: String,
            expiryDate: Date,
            openedAt: Date? = nil,
            quantity: Int = 1,
            customAfterOpeningDays: Int? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = categoryKey
            self.expiryDate = expiryDate
            self.openedAt = openedAt
            self.quantity = max(1, quantity)
            self.customAfterOpeningDays = customAfterOpeningDays
            self.createdAt = createdAt
        }

        convenience init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory,
            expiryDate: Date,
            openedAt: Date? = nil,
            quantity: Int = 1,
            customAfterOpeningDays: Int? = nil,
            createdAt: Date = .now
        ) {
            self.init(
                id: id,
                name: name,
                categoryKey: category.rawValue,
                expiryDate: expiryDate,
                openedAt: openedAt,
                quantity: quantity,
                customAfterOpeningDays: customAfterOpeningDays,
                createdAt: createdAt
            )
        }
    }

    @Model
    final class CategoryRule {
        var id: UUID
        var categoryRawValue: String
        var defaultAfterOpeningDays: Int
        var isExpiryTrackingEnabled: Bool = true

        init(
            id: UUID = UUID(),
            categoryKey: String,
            defaultAfterOpeningDays: Int,
            isExpiryTrackingEnabled: Bool = true
        ) {
            self.id = id
            self.categoryRawValue = categoryKey
            self.defaultAfterOpeningDays = defaultAfterOpeningDays
            self.isExpiryTrackingEnabled = isExpiryTrackingEnabled
        }

        convenience init(
            id: UUID = UUID(),
            category: ProductCategory,
            defaultAfterOpeningDays: Int,
            isExpiryTrackingEnabled: Bool = true
        ) {
            self.init(
                id: id,
                categoryKey: category.rawValue,
                defaultAfterOpeningDays: defaultAfterOpeningDays,
                isExpiryTrackingEnabled: isExpiryTrackingEnabled
            )
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
        var shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue
        var shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue

        init(
            id: UUID = UUID(),
            preferredLanguageCode: String = "system",
            notificationsEnabled: Bool = true,
            reminderLookaheadDays: Int = 2,
            dailyDigestHour: Int = 20,
            dailyDigestMinute: Int = 0,
            shoppingModeRawValue: String = ShoppingMode.listOnly.rawValue,
            shoppingCaptureModeRawValue: String = ShoppingCaptureMode.byItem.rawValue
        ) {
            self.id = id
            self.preferredLanguageCode = preferredLanguageCode
            self.notificationsEnabled = notificationsEnabled
            self.reminderLookaheadDays = reminderLookaheadDays
            self.dailyDigestHour = dailyDigestHour
            self.dailyDigestMinute = dailyDigestMinute
            self.shoppingModeRawValue = shoppingModeRawValue
            self.shoppingCaptureModeRawValue = shoppingCaptureModeRawValue
        }
    }

    @Model
    final class ShoppingItem {
        var id: UUID
        var name: String
        var categoryRawValue: String?
        var quantity: Int = 1
        var isBought: Bool = false
        var boughtAt: Date?
        var needsExpiryCapture: Bool = false
        var pendingExpiryDate: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            name: String,
            categoryKey: String? = nil,
            quantity: Int = 1,
            isBought: Bool = false,
            boughtAt: Date? = nil,
            needsExpiryCapture: Bool = false,
            pendingExpiryDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = categoryKey
            self.quantity = max(1, quantity)
            self.isBought = isBought
            self.boughtAt = boughtAt
            self.needsExpiryCapture = needsExpiryCapture
            self.pendingExpiryDate = pendingExpiryDate
            self.createdAt = createdAt
        }

        convenience init(
            id: UUID = UUID(),
            name: String,
            category: ProductCategory? = nil,
            quantity: Int = 1,
            isBought: Bool = false,
            boughtAt: Date? = nil,
            needsExpiryCapture: Bool = false,
            pendingExpiryDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.init(
                id: id,
                name: name,
                categoryKey: category?.rawValue,
                quantity: quantity,
                isBought: isBought,
                boughtAt: boughtAt,
                needsExpiryCapture: needsExpiryCapture,
                pendingExpiryDate: pendingExpiryDate,
                createdAt: createdAt
            )
        }
    }

    @Model
    final class ConsumptionEvent {
        var id: UUID
        var productName: String
        var categoryRawValue: String
        var quantity: Int
        var consumedAt: Date
        var effectiveExpiryDate: Date
        var consumedBeforeExpiry: Bool

        init(
            id: UUID = UUID(),
            productName: String,
            categoryRawValue: String,
            quantity: Int,
            consumedAt: Date = .now,
            effectiveExpiryDate: Date,
            consumedBeforeExpiry: Bool
        ) {
            self.id = id
            self.productName = productName
            self.categoryRawValue = categoryRawValue
            self.quantity = max(1, quantity)
            self.consumedAt = consumedAt
            self.effectiveExpiryDate = effectiveExpiryDate
            self.consumedBeforeExpiry = consumedBeforeExpiry
        }
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self, AppSchemaV4.self, AppSchemaV5.self, AppSchemaV6.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AppSchemaV3.self,
        toVersion: AppSchemaV4.self
    )

    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: AppSchemaV4.self,
        toVersion: AppSchemaV5.self
    )

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: AppSchemaV5.self,
        toVersion: AppSchemaV6.self
    )
}

typealias Category = AppSchemaV6.Category
typealias Product = AppSchemaV6.Product
typealias ShoppingItem = AppSchemaV6.ShoppingItem
typealias ConsumptionEvent = AppSchemaV6.ConsumptionEvent
