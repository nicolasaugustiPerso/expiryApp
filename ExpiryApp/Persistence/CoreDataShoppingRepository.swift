import Foundation
import CoreData

struct CoreDataShoppingItem: Identifiable {
    let id: UUID
    var name: String
    var categoryRawValue: String?
    var quantity: Int
    var isBought: Bool
    var boughtAt: Date?
    var createdAt: Date
}

final class CoreDataShoppingRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    func fetchShoppingItems() throws -> [CoreDataShoppingItem] {
        let listID = try ensureDefaultListID()
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let objects = try context.fetch(request)

        return objects.compactMap { object in
            guard
                let id = object.value(forKey: "id") as? UUID,
                let name = object.value(forKey: "name") as? String,
                let createdAt = object.value(forKey: "createdAt") as? Date
            else {
                return nil
            }

            let categoryRawValue = object.value(forKey: "categoryRawValue") as? String
            let quantity = Int((object.value(forKey: "quantity") as? Int64) ?? 1)
            let isBought = (object.value(forKey: "isBought") as? Bool) ?? false
            let boughtAt = object.value(forKey: "boughtAt") as? Date

            return CoreDataShoppingItem(
                id: id,
                name: name,
                categoryRawValue: categoryRawValue,
                quantity: max(1, quantity),
                isBought: isBought,
                boughtAt: boughtAt,
                createdAt: createdAt
            )
        }
    }

    func addShoppingItem(name: String, categoryRawValue: String?, quantity: Int = 1) throws {
        let listID = try ensureDefaultListID()
        let object = NSEntityDescription.insertNewObject(forEntityName: "CDShoppingItem", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(listID, forKey: "listID")
        object.setValue(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
        object.setValue(categoryRawValue, forKey: "categoryRawValue")
        object.setValue(Int64(max(1, quantity)), forKey: "quantity")
        object.setValue(false, forKey: "isBought")
        object.setValue(nil, forKey: "boughtAt")
        object.setValue(false, forKey: "needsExpiryCapture")
        object.setValue(nil, forKey: "pendingExpiryDate")
        object.setValue(Date(), forKey: "createdAt")
        try saveIfNeeded()
    }

    func deleteShoppingItem(id: UUID) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        context.delete(object)
        try saveIfNeeded()
    }

    func toggleBought(id: UUID) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        let current = (object.value(forKey: "isBought") as? Bool) ?? false
        object.setValue(!current, forKey: "isBought")
        object.setValue(!current ? Date() : nil, forKey: "boughtAt")
        try saveIfNeeded()
    }

    func updateShoppingItem(id: UUID, quantity: Int, categoryRawValue: String?) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        object.setValue(Int64(max(1, quantity)), forKey: "quantity")
        object.setValue(categoryRawValue, forKey: "categoryRawValue")
        try saveIfNeeded()
    }

    private func fetchShoppingObject(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
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
