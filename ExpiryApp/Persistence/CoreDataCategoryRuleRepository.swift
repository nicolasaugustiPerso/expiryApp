import Foundation
import CoreData

struct CoreDataCategoryRuleEntry: Identifiable {
    let id: UUID
    var categoryRawValue: String
    var defaultAfterOpeningDays: Int
    var isExpiryTrackingEnabled: Bool
}

final class CoreDataCategoryRuleRepository {
    private let context: NSManagedObjectContext
    private let listRepository: CoreDataListRepository

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.listRepository = CoreDataListRepository(context: context)
    }

    func fetchRules() throws -> [CoreDataCategoryRuleEntry] {
        let list = try activeList()
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@", list.id as CVarArg)
        let objects = try context.fetch(request)

        let existingKeys = Set(objects.compactMap { $0.value(forKey: "categoryRawValue") as? String })
        let categories = (try? CoreDataCategoryRepository(context: context).fetchCategories()) ?? []
        var didInsert = false
        for category in categories where !existingKeys.contains(category.key) {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(list.id, forKey: "listID")
            object.setValue(category.key, forKey: "categoryRawValue")
            let days = CategoryDefaults.defaultAfterOpeningDaysByKey[category.key] ?? 3
            object.setValue(Int64(days), forKey: "defaultAfterOpeningDays")
            object.setValue(CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[category.key] ?? true, forKey: "isExpiryTrackingEnabled")
            if let listObject = try? context.existingObject(with: list.objectID) {
                object.setValue(listObject, forKey: "list")
                if let store = listObject.objectID.persistentStore {
                    context.assign(object, to: store)
                }
            }
            didInsert = true
        }

        if didInsert {
            try saveIfNeeded()
            return try fetchRules()
        }

        return objects.compactMap { object in
            guard
                let id = object.value(forKey: "id") as? UUID,
                let categoryRawValue = object.value(forKey: "categoryRawValue") as? String
            else { return nil }
            let days = Int((object.value(forKey: "defaultAfterOpeningDays") as? Int64) ?? 3)
            let trackingEnabled = (object.value(forKey: "isExpiryTrackingEnabled") as? Bool) ?? true
            return CoreDataCategoryRuleEntry(
                id: id,
                categoryRawValue: CategoryDefaults.canonicalCategoryKey(categoryRawValue),
                defaultAfterOpeningDays: max(1, days),
                isExpiryTrackingEnabled: trackingEnabled
            )
        }
    }

    func upsertRule(categoryKey: String, defaultAfterOpeningDays: Int, isExpiryTrackingEnabled: Bool) throws {
        let list = try activeList()
        let canonicalCategoryKey = CategoryDefaults.canonicalCategoryKey(categoryKey)
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@ AND categoryRawValue == %@", list.id as CVarArg, canonicalCategoryKey)
        request.fetchLimit = 1

        let object = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
        if object.value(forKey: "id") == nil {
            object.setValue(UUID(), forKey: "id")
            object.setValue(list.id, forKey: "listID")
            object.setValue(canonicalCategoryKey, forKey: "categoryRawValue")
            if let listObject = try? context.existingObject(with: list.objectID) {
                object.setValue(listObject, forKey: "list")
                if let store = listObject.objectID.persistentStore {
                    context.assign(object, to: store)
                }
            }
        }

        object.setValue(Int64(max(1, defaultAfterOpeningDays)), forKey: "defaultAfterOpeningDays")
        object.setValue(isExpiryTrackingEnabled, forKey: "isExpiryTrackingEnabled")
        try saveIfNeeded()
    }

    func deleteRule(categoryKey: String) throws {
        let list = try activeList()
        let canonicalCategoryKey = CategoryDefaults.canonicalCategoryKey(categoryKey)
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@ AND categoryRawValue == %@", list.id as CVarArg, canonicalCategoryKey)
        let objects = try context.fetch(request)
        for object in objects {
            context.delete(object)
        }
        try saveIfNeeded()
    }

    private func activeList() throws -> CoreDataListInfo {
        if let list = try listRepository.currentList() { return list }
        return try listRepository.ensureDefaultList()
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
