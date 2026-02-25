import Foundation
import SwiftData

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
