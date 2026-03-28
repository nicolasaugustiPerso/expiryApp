import Foundation
import CoreData

enum CoreDataListStoreScope: String {
    case `private`
    case shared
}

struct CoreDataListInfo: Identifiable {
    let id: UUID
    let name: String
    let isDefault: Bool
    let isShared: Bool
    let shareRecordName: String?
    let storeScope: CoreDataListStoreScope
    let objectID: NSManagedObjectID
}

final class CoreDataListRepository {
    private let context: NSManagedObjectContext
    private let stack: CoreDataStack
    private let activeListKey = "coredata.active_list_id"

    init(
        context: NSManagedObjectContext = CoreDataStack.shared.viewContext,
        stack: CoreDataStack = .shared
    ) {
        self.context = context
        self.stack = stack
    }

    @discardableResult
    func ensureDefaultList() throws -> CoreDataListInfo {
        if let current = try currentList() { return current }

        let object = NSEntityDescription.insertNewObject(forEntityName: "CDSharedList", into: context)
        let id = UUID()
        object.setValue(id, forKey: "id")
        object.setValue("My List", forKey: "name")
        object.setValue(true, forKey: "isDefault")
        object.setValue(false, forKey: "isShared")
        object.setValue("private", forKey: "storeScope")
        object.setValue(nil, forKey: "shareRecordName")
        object.setValue(Date(), forKey: "createdAt")
        if let privateStore = stack.privateStore {
            context.assign(object, to: privateStore)
        }
        try saveIfNeeded()
        UserDefaults.standard.set(id.uuidString, forKey: activeListKey)
        guard let created = try currentList() else {
            throw NSError(
                domain: "CoreDataListRepository",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create default list"]
            )
        }
        return created
    }

    func currentList() throws -> CoreDataListInfo? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSharedList")
        let objects = try context.fetch(request)

        if let raw = UserDefaults.standard.string(forKey: activeListKey),
           let activeID = UUID(uuidString: raw),
           let active = objects.first(where: { ($0.value(forKey: "id") as? UUID) == activeID }) {
            return try mapList(active)
        }

        if let defaultList = objects.first(where: { ($0.value(forKey: "isDefault") as? Bool) == true }) {
            let info = try mapList(defaultList)
            UserDefaults.standard.set(info.id.uuidString, forKey: activeListKey)
            return info
        }

        return nil
    }

    func fetchLists() throws -> [CoreDataListInfo] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSharedList")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request).map { try mapList($0) }
    }

    func setActiveList(id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: activeListKey)
        NotificationCenter.default.post(name: .coreDataActiveListDidChange, object: nil)
    }

    func updateListName(id: UUID, name: String) throws {
        guard let object = try fetchListObject(id: id) else { return }
        object.setValue(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
        try saveIfNeeded()
    }

    func allManagedObjectsForList(id: UUID) throws -> [NSManagedObject] {
        var all: [NSManagedObject] = []
        if let listObject = try fetchListObject(id: id) {
            all.append(listObject)
        }
        for entity in ["CDProduct", "CDShoppingItem", "CDCategory", "CDCategoryRule", "CDConsumptionEvent"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "listID == %@", id as CVarArg)
            all.append(contentsOf: try context.fetch(request))
        }
        return all
    }

    func markShared(id: UUID, shareRecordName: String?) throws {
        guard let object = try fetchListObject(id: id) else { return }
        object.setValue(true, forKey: "isShared")
        object.setValue(shareRecordName, forKey: "shareRecordName")
        try saveIfNeeded()
    }

    func objectIDForList(id: UUID) throws -> NSManagedObjectID? {
        try fetchListObject(id: id)?.objectID
    }

    func storeForList(id: UUID) throws -> NSPersistentStore? {
        guard let object = try fetchListObject(id: id) else { return nil }
        let scope = (object.value(forKey: "storeScope") as? String) ?? "private"
        if scope == "shared" { return stack.sharedStore }
        return stack.privateStore
    }

    private func fetchListObject(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSharedList")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func mapList(_ object: NSManagedObject) throws -> CoreDataListInfo {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let name = object.value(forKey: "name") as? String
        else {
            throw NSError(domain: "CoreDataListRepository", code: -1)
        }

        let scope: CoreDataListStoreScope
        if let store = object.objectID.persistentStore, store == stack.sharedStore {
            scope = .shared
        } else {
            scope = .private
        }

        return CoreDataListInfo(
            id: id,
            name: name,
            isDefault: (object.value(forKey: "isDefault") as? Bool) ?? false,
            isShared: (object.value(forKey: "isShared") as? Bool) ?? false,
            shareRecordName: object.value(forKey: "shareRecordName") as? String,
            storeScope: scope,
            objectID: object.objectID
        )
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
