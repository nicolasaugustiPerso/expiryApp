import Foundation
import SwiftData
import CoreData

enum SwiftDataToCoreDataMigrator {
    static func migrateIfNeeded(modelContext: ModelContext) {
        let key = "migration.swiftdata_to_coredata.v2.completed"
        if UserDefaults.standard.bool(forKey: key) { return }

        do {
            let coreDataContext = CoreDataStack.shared.viewContext
            let listObject = try ensureDefaultList(context: coreDataContext)
            guard let listID = listObject.value(forKey: "id") as? UUID else { return }
            let listStore = listObject.objectID.persistentStore

            let products = try modelContext.fetch(FetchDescriptor<Product>(predicate: nil, sortBy: []))
            for product in products {
                if try exists(entity: "CDProduct", id: product.id, context: coreDataContext) { continue }
                let object = NSEntityDescription.insertNewObject(forEntityName: "CDProduct", into: coreDataContext)
                object.setValue(product.id, forKey: "id")
                object.setValue(listID, forKey: "listID")
                object.setValue(product.name, forKey: "name")
                object.setValue(product.categoryRawValue, forKey: "categoryRawValue")
                object.setValue(product.expiryDate, forKey: "expiryDate")
                object.setValue(product.openedAt, forKey: "openedAt")
                object.setValue(Int64(product.quantity), forKey: "quantity")
                object.setValue(product.customAfterOpeningDays.map { Int64($0) }, forKey: "customAfterOpeningDays")
                object.setValue(product.createdAt, forKey: "createdAt")
                object.setValue(listObject, forKey: "list")
                if let listStore {
                    coreDataContext.assign(object, to: listStore)
                }
            }

            let shoppingItems = try modelContext.fetch(FetchDescriptor<ShoppingItem>(predicate: nil, sortBy: []))
            for item in shoppingItems {
                if try exists(entity: "CDShoppingItem", id: item.id, context: coreDataContext) { continue }
                let object = NSEntityDescription.insertNewObject(forEntityName: "CDShoppingItem", into: coreDataContext)
                object.setValue(item.id, forKey: "id")
                object.setValue(listID, forKey: "listID")
                object.setValue(item.name, forKey: "name")
                object.setValue(item.categoryRawValue, forKey: "categoryRawValue")
                object.setValue(Int64(item.quantity), forKey: "quantity")
                object.setValue(item.isBought, forKey: "isBought")
                object.setValue(item.boughtAt, forKey: "boughtAt")
                object.setValue(item.needsExpiryCapture, forKey: "needsExpiryCapture")
                object.setValue(item.pendingExpiryDate, forKey: "pendingExpiryDate")
                object.setValue(item.createdAt, forKey: "createdAt")
                object.setValue(listObject, forKey: "list")
                if let listStore {
                    coreDataContext.assign(object, to: listStore)
                }
            }

            let rules = try modelContext.fetch(FetchDescriptor<CategoryRule>(predicate: nil, sortBy: []))
            for rule in rules {
                if try exists(entity: "CDCategoryRule", id: rule.id, context: coreDataContext) { continue }
                let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: coreDataContext)
                object.setValue(rule.id, forKey: "id")
                object.setValue(listID, forKey: "listID")
                object.setValue(rule.categoryRawValue, forKey: "categoryRawValue")
                object.setValue(Int64(rule.defaultAfterOpeningDays), forKey: "defaultAfterOpeningDays")
                object.setValue(rule.isExpiryTrackingEnabled, forKey: "isExpiryTrackingEnabled")
                object.setValue(listObject, forKey: "list")
                if let listStore {
                    coreDataContext.assign(object, to: listStore)
                }
            }

            let events = try modelContext.fetch(FetchDescriptor<ConsumptionEvent>(predicate: nil, sortBy: []))
            for event in events {
                if try exists(entity: "CDConsumptionEvent", id: event.id, context: coreDataContext) { continue }
                let object = NSEntityDescription.insertNewObject(forEntityName: "CDConsumptionEvent", into: coreDataContext)
                object.setValue(event.id, forKey: "id")
                object.setValue(listID, forKey: "listID")
                object.setValue(event.productName, forKey: "productName")
                object.setValue(event.categoryRawValue, forKey: "categoryRawValue")
                object.setValue(Int64(event.quantity), forKey: "quantity")
                object.setValue(event.consumedAt, forKey: "consumedAt")
                object.setValue(event.effectiveExpiryDate, forKey: "effectiveExpiryDate")
                object.setValue(event.consumedBeforeExpiry, forKey: "consumedBeforeExpiry")
                object.setValue(listObject, forKey: "list")
                if let listStore {
                    coreDataContext.assign(object, to: listStore)
                }
            }

            let categories = try modelContext.fetch(FetchDescriptor<Category>(predicate: nil, sortBy: []))
            for category in categories {
                if try exists(entity: "CDCategory", id: category.id, context: coreDataContext) { continue }
                let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategory", into: coreDataContext)
                object.setValue(category.id, forKey: "id")
                object.setValue(listID, forKey: "listID")
                object.setValue(category.key, forKey: "key")
                object.setValue(category.name, forKey: "name")
                object.setValue(category.symbolName, forKey: "symbolName")
                object.setValue(category.tintColorHex, forKey: "tintColorHex")
                object.setValue(category.isSystem, forKey: "isSystem")
                object.setValue(category.createdAt, forKey: "createdAt")
                object.setValue(listObject, forKey: "list")
                if let listStore {
                    coreDataContext.assign(object, to: listStore)
                }
            }

            if coreDataContext.hasChanges {
                try coreDataContext.save()
            }

            UserDefaults.standard.set(true, forKey: key)
        } catch {
            print("SwiftDataToCoreDataMigrator failed: \(error)")
        }
    }

    private static func exists(entity: String, id: UUID, context: NSManagedObjectContext) throws -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first != nil
    }

    private static func ensureDefaultList(context: NSManagedObjectContext) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSharedList")
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1

        if let existing = try context.fetch(request).first {
            return existing
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "CDSharedList", into: context)
        let id = UUID()
        object.setValue(id, forKey: "id")
        object.setValue("My List", forKey: "name")
        object.setValue(true, forKey: "isDefault")
        object.setValue(false, forKey: "isShared")
        object.setValue("private", forKey: "storeScope")
        object.setValue(nil, forKey: "shareRecordName")
        object.setValue(Date(), forKey: "createdAt")
        if let privateStore = CoreDataStack.shared.privateStore {
            context.assign(object, to: privateStore)
        }
        try context.save()
        return object
    }
}
