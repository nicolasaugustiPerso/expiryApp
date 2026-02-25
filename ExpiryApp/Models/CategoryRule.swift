import Foundation
import SwiftData

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
