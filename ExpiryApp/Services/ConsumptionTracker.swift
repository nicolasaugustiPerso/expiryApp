import Foundation
import SwiftData

enum ConsumptionTracker {
    static func recordConsumption(
        context: ModelContext,
        product: Product,
        effectiveExpiry: Date,
        quantity: Int = 1,
        consumedAt: Date = .now
    ) {
        let consumedBeforeExpiry = consumedAt <= effectiveExpiry
        let event = ConsumptionEvent(
            productName: product.name,
            categoryRawValue: product.categoryRawValue,
            quantity: max(1, quantity),
            consumedAt: consumedAt,
            effectiveExpiryDate: effectiveExpiry,
            consumedBeforeExpiry: consumedBeforeExpiry
        )
        context.insert(event)
    }
}
