import Foundation
import CoreData

struct CoreDataProduct: Identifiable {
    let id: UUID
    let listID: UUID
    var name: String
    var categoryRawValue: String
    var expiryDate: Date
    var openedAt: Date?
    var quantity: Int
    var customAfterOpeningDays: Int?
    var createdAt: Date

    var category: ProductCategory {
        ProductCategory(rawValue: categoryRawValue) ?? .other
    }
}

struct CoreDataCategoryRule {
    let categoryRawValue: String
    let defaultAfterOpeningDays: Int
}

struct CoreDataConsumptionEvent {
    let id: UUID
    let listID: UUID
    let productName: String
    let categoryRawValue: String
    let quantity: Int
    let consumedAt: Date
    let effectiveExpiryDate: Date
    let consumedBeforeExpiry: Bool
}

final class CoreDataExpirationRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchProducts() throws -> [CoreDataProduct] {
        let listID = try ensureDefaultListID()
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDProduct")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "expiryDate", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        let objects = try context.fetch(request)
        return objects.compactMap(mapProduct)
    }

    func fetchCategoryRules() throws -> [CoreDataCategoryRule] {
        let listID = try ensureDefaultListID()
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        let objects = try context.fetch(request)

        if objects.isEmpty {
            try seedDefaultCategoryRules(listID: listID)
            return try fetchCategoryRules()
        }

        return objects.compactMap { object in
            guard
                let categoryRawValue = object.value(forKey: "categoryRawValue") as? String
            else {
                return nil
            }
            let days = Int((object.value(forKey: "defaultAfterOpeningDays") as? Int64) ?? 3)
            return CoreDataCategoryRule(
                categoryRawValue: categoryRawValue,
                defaultAfterOpeningDays: max(1, days)
            )
        }
    }

    func fetchConsumptionEvents() throws -> [CoreDataConsumptionEvent] {
        let listID = try ensureDefaultListID()
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDConsumptionEvent")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "consumedAt", ascending: false)]
        let objects = try context.fetch(request)

        return objects.compactMap { object in
            guard
                let id = object.value(forKey: "id") as? UUID,
                let listID = object.value(forKey: "listID") as? UUID,
                let productName = object.value(forKey: "productName") as? String,
                let categoryRawValue = object.value(forKey: "categoryRawValue") as? String,
                let consumedAt = object.value(forKey: "consumedAt") as? Date,
                let effectiveExpiryDate = object.value(forKey: "effectiveExpiryDate") as? Date
            else {
                return nil
            }

            return CoreDataConsumptionEvent(
                id: id,
                listID: listID,
                productName: productName,
                categoryRawValue: categoryRawValue,
                quantity: Int((object.value(forKey: "quantity") as? Int64) ?? 1),
                consumedAt: consumedAt,
                effectiveExpiryDate: effectiveExpiryDate,
                consumedBeforeExpiry: (object.value(forKey: "consumedBeforeExpiry") as? Bool) ?? false
            )
        }
    }

    func deleteProduct(id: UUID) throws {
        guard let object = try fetchProductObject(id: id) else { return }
        context.delete(object)
        try saveIfNeeded()
    }

    func toggleOpened(id: UUID) throws {
        guard let object = try fetchProductObject(id: id) else { return }
        let openedAt = object.value(forKey: "openedAt") as? Date
        object.setValue(openedAt == nil ? Date() : nil, forKey: "openedAt")
        try saveIfNeeded()
    }

    func consumeOne(id: UUID, effectiveExpiryDate: Date) throws {
        guard let object = try fetchProductObject(id: id),
              let listID = object.value(forKey: "listID") as? UUID,
              let name = object.value(forKey: "name") as? String,
              let categoryRawValue = object.value(forKey: "categoryRawValue") as? String
        else { return }

        let quantity = Int((object.value(forKey: "quantity") as? Int64) ?? 1)
        let consumedAt = Date()
        let event = NSEntityDescription.insertNewObject(forEntityName: "CDConsumptionEvent", into: context)
        event.setValue(UUID(), forKey: "id")
        event.setValue(listID, forKey: "listID")
        event.setValue(name, forKey: "productName")
        event.setValue(categoryRawValue, forKey: "categoryRawValue")
        event.setValue(Int64(1), forKey: "quantity")
        event.setValue(consumedAt, forKey: "consumedAt")
        event.setValue(effectiveExpiryDate, forKey: "effectiveExpiryDate")
        event.setValue(consumedAt <= effectiveExpiryDate, forKey: "consumedBeforeExpiry")

        if quantity > 1 {
            object.setValue(Int64(quantity - 1), forKey: "quantity")
        } else {
            context.delete(object)
        }

        try saveIfNeeded()
    }

    private func fetchProductObject(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDProduct")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func mapProduct(_ object: NSManagedObject) -> CoreDataProduct? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let listID = object.value(forKey: "listID") as? UUID,
            let name = object.value(forKey: "name") as? String,
            let categoryRawValue = object.value(forKey: "categoryRawValue") as? String,
            let expiryDate = object.value(forKey: "expiryDate") as? Date,
            let createdAt = object.value(forKey: "createdAt") as? Date
        else {
            return nil
        }

        return CoreDataProduct(
            id: id,
            listID: listID,
            name: name,
            categoryRawValue: categoryRawValue,
            expiryDate: expiryDate,
            openedAt: object.value(forKey: "openedAt") as? Date,
            quantity: max(1, Int((object.value(forKey: "quantity") as? Int64) ?? 1)),
            customAfterOpeningDays: (object.value(forKey: "customAfterOpeningDays") as? Int64).map(Int.init),
            createdAt: createdAt
        )
    }

    private func seedDefaultCategoryRules(listID: UUID) throws {
        for category in ProductCategory.allCases {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(listID, forKey: "listID")
            object.setValue(category.rawValue, forKey: "categoryRawValue")
            object.setValue(Int64(CategoryDefaults.afterOpeningDays[category] ?? 3), forKey: "defaultAfterOpeningDays")
        }
        try saveIfNeeded()
    }

    private func ensureDefaultListID() throws -> UUID {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSharedList")
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1

        if let existing = try context.fetch(request).first,
           let id = existing.value(forKey: "id") as? UUID {
            return id
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "CDSharedList", into: context)
        let id = UUID()
        object.setValue(id, forKey: "id")
        object.setValue("My List", forKey: "name")
        object.setValue(true, forKey: "isDefault")
        object.setValue(Date(), forKey: "createdAt")
        try saveIfNeeded()
        return id
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
