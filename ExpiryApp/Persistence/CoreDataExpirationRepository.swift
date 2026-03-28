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

}

struct CoreDataCategoryRule {
    let categoryRawValue: String
    let defaultAfterOpeningDays: Int
    let isExpiryTrackingEnabled: Bool
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
    private let listRepository: CoreDataListRepository

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.listRepository = CoreDataListRepository(context: context)
    }

    func fetchProducts() throws -> [CoreDataProduct] {
        let listID = try activeList().id
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
        let active = try activeList()
        let listID = active.id
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        let objects = try context.fetch(request)

        let existingKeys = Set(objects.compactMap { $0.value(forKey: "categoryRawValue") as? String })
        let categories = (try? CoreDataCategoryRepository(context: context).fetchCategories()) ?? []
        var didInsert = false
        for category in categories where !existingKeys.contains(category.key) {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(active.id, forKey: "listID")
            object.setValue(category.key, forKey: "categoryRawValue")
            let days = CategoryDefaults.defaultAfterOpeningDaysByKey[category.key] ?? 3
            object.setValue(Int64(days), forKey: "defaultAfterOpeningDays")
            object.setValue(CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[category.key] ?? true, forKey: "isExpiryTrackingEnabled")
            if let listObject = try? context.existingObject(with: active.objectID) {
                object.setValue(listObject, forKey: "list")
                if let store = listObject.objectID.persistentStore {
                    context.assign(object, to: store)
                }
            }
            didInsert = true
        }

        if didInsert {
            try saveIfNeeded()
            return try fetchCategoryRules()
        }

        if objects.isEmpty {
            try seedDefaultCategoryRules(for: active)
            return try fetchCategoryRules()
        }

        if try applyTrackingDefaultsMigrationIfNeeded(listID: listID, objects: objects) {
            return try fetchCategoryRules()
        }

        return objects.compactMap { object in
            guard
                let categoryRawValue = object.value(forKey: "categoryRawValue") as? String
            else {
                return nil
            }
            let days = Int((object.value(forKey: "defaultAfterOpeningDays") as? Int64) ?? 3)
            let trackingEnabled = (object.value(forKey: "isExpiryTrackingEnabled") as? Bool) ?? true
            return CoreDataCategoryRule(
                categoryRawValue: CategoryDefaults.canonicalCategoryKey(categoryRawValue),
                defaultAfterOpeningDays: max(1, days),
                isExpiryTrackingEnabled: trackingEnabled
            )
        }
    }

    func fetchConsumptionEvents() throws -> [CoreDataConsumptionEvent] {
        let listID = try activeList().id
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

    func addProduct(
        name: String,
        categoryRawValue: String?,
        quantity: Int,
        expiryDate: Date,
        customAfterOpeningDays: Int? = nil
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let currentList = try activeList()
        let product = NSEntityDescription.insertNewObject(forEntityName: "CDProduct", into: context)
        product.setValue(UUID(), forKey: "id")
        product.setValue(currentList.id, forKey: "listID")
        product.setValue(trimmedName, forKey: "name")
        product.setValue(normalizeCategoryKey(categoryRawValue), forKey: "categoryRawValue")
        product.setValue(expiryDate, forKey: "expiryDate")
        product.setValue(nil, forKey: "openedAt")
        product.setValue(Int64(max(1, quantity)), forKey: "quantity")
        product.setValue(customAfterOpeningDays.map { Int64($0) }, forKey: "customAfterOpeningDays")
        product.setValue(Date(), forKey: "createdAt")
        if let listObject = try? context.existingObject(with: currentList.objectID) {
            product.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(product, to: store)
            }
        }

        try saveIfNeeded()
    }

    func updateProduct(
        id: UUID,
        name: String,
        categoryRawValue: String?,
        quantity: Int,
        expiryDate: Date,
        customAfterOpeningDays: Int?
    ) throws {
        guard let object = try fetchProductObject(id: id) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        object.setValue(trimmedName, forKey: "name")
        object.setValue(normalizeCategoryKey(categoryRawValue), forKey: "categoryRawValue")
        object.setValue(Int64(max(1, quantity)), forKey: "quantity")
        object.setValue(expiryDate, forKey: "expiryDate")
        object.setValue(customAfterOpeningDays.map { Int64(max(1, $0)) }, forKey: "customAfterOpeningDays")
        try saveIfNeeded()
    }

    func toggleOpened(id: UUID) throws {
        guard let object = try fetchProductObject(id: id) else { return }
        let openedAt = object.value(forKey: "openedAt") as? Date
        object.setValue(openedAt == nil ? Date() : nil, forKey: "openedAt")
        try saveIfNeeded()
    }

    func consumeOne(id: UUID, effectiveExpiryDate: Date) throws {
        let currentList = try activeList()
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
        if let listObject = try? context.existingObject(with: currentList.objectID) {
            event.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(event, to: store)
            }
        }

        if quantity > 1 {
            object.setValue(Int64(quantity - 1), forKey: "quantity")
        } else {
            context.delete(object)
        }

        try saveIfNeeded()
    }

    private func fetchProductObject(id: UUID) throws -> NSManagedObject? {
        let listID = try activeList().id
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDProduct")
        request.predicate = NSPredicate(format: "id == %@ AND listID == %@", id as CVarArg, listID as CVarArg)
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

    private func seedDefaultCategoryRules(for list: CoreDataListInfo) throws {
        for seed in CategoryDefaults.systemSeeds {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(list.id, forKey: "listID")
            object.setValue(seed.key, forKey: "categoryRawValue")
            object.setValue(Int64(seed.defaultAfterOpeningDays), forKey: "defaultAfterOpeningDays")
            object.setValue(CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[seed.key] ?? true, forKey: "isExpiryTrackingEnabled")
            if let listObject = try? context.existingObject(with: list.objectID) {
                object.setValue(listObject, forKey: "list")
                if let store = listObject.objectID.persistentStore {
                    context.assign(object, to: store)
                }
            }
        }
        try saveIfNeeded()
    }

    private func activeList() throws -> CoreDataListInfo {
        if let list = try listRepository.currentList() {
            return list
        }
        return try listRepository.ensureDefaultList()
    }

    private func normalizeCategoryKey(_ raw: String?) -> String {
        CategoryDefaults.canonicalCategoryKey(raw)
    }

    private func applyTrackingDefaultsMigrationIfNeeded(
        listID: UUID,
        objects: [NSManagedObject]
    ) throws -> Bool {
        let migrationKey = "migration.category_tracking_defaults.v1.\(listID.uuidString.lowercased())"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return false
        }

        var didChange = false
        for object in objects {
            guard let raw = object.value(forKey: "categoryRawValue") as? String else { continue }
            let key = CategoryDefaults.canonicalCategoryKey(raw)
            guard CategoryDefaults.nonExpiryTrackingCategoryKeys.contains(key) else { continue }
            let current = (object.value(forKey: "isExpiryTrackingEnabled") as? Bool) ?? true
            if current {
                object.setValue(false, forKey: "isExpiryTrackingEnabled")
                didChange = true
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        if didChange {
            try saveIfNeeded()
        }
        return didChange
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
