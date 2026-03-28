import Foundation
import CoreData

struct CoreDataShoppingItem: Identifiable {
    let id: UUID
    var name: String
    var categoryRawValue: String?
    var quantity: Int
    var isBought: Bool
    var boughtAt: Date?
    var needsExpiryCapture: Bool
    var pendingExpiryDate: Date?
    var createdAt: Date
}

final class CoreDataShoppingRepository {
    private let context: NSManagedObjectContext
    private let listRepository: CoreDataListRepository

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.listRepository = CoreDataListRepository(context: context)
    }

    func fetchShoppingItems() throws -> [CoreDataShoppingItem] {
        let listID = try activeList().id
        try normalizeStoredCategoryKeys(listID: listID)
        try consolidateToBuyDuplicates(listID: listID)

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

            let categoryRawValue = normalizeCategoryKey(object.value(forKey: "categoryRawValue") as? String)
            let quantity = Int((object.value(forKey: "quantity") as? Int64) ?? 1)
            let isBought = (object.value(forKey: "isBought") as? Bool) ?? false
            let boughtAt = object.value(forKey: "boughtAt") as? Date
            let needsExpiryCapture = (object.value(forKey: "needsExpiryCapture") as? Bool) ?? false
            let pendingExpiryDate = object.value(forKey: "pendingExpiryDate") as? Date

            return CoreDataShoppingItem(
                id: id,
                name: name,
                categoryRawValue: categoryRawValue,
                quantity: max(1, quantity),
                isBought: isBought,
                boughtAt: boughtAt,
                needsExpiryCapture: needsExpiryCapture,
                pendingExpiryDate: pendingExpiryDate,
                createdAt: createdAt
            )
        }
    }

    func addShoppingItem(name: String, categoryRawValue: String?, quantity: Int = 1) throws {
        let currentList = try activeList()
        let listID = currentList.id
        let normalizedName = normalizeName(name)
        guard !normalizedName.isEmpty else { return }
        let normalizedCategory = normalizeCategoryKey(categoryRawValue)
        let categoryEquivalenceMap = try categoryEquivalenceMap(listID: listID)
        let normalizedCategoryForGrouping = categoryGroupingKey(
            rawCategory: normalizedCategory,
            categoryEquivalenceMap: categoryEquivalenceMap
        )
        let quantityToAdd = max(1, quantity)

        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        existingRequest.predicate = NSPredicate(format: "listID == %@ AND isBought == NO", listID as CVarArg)
        let existingObjects = try context.fetch(existingRequest)
        let nameMatches = existingObjects.filter { object in
            normalizeName((object.value(forKey: "name") as? String) ?? "") == normalizedName
        }
        if let existing = nameMatches.first(where: { object in
            categoryGroupingKey(
                rawCategory: object.value(forKey: "categoryRawValue") as? String,
                categoryEquivalenceMap: categoryEquivalenceMap
            ) == normalizedCategoryForGrouping
        }) {
            let currentQuantity = Int((existing.value(forKey: "quantity") as? Int64) ?? 1)
            existing.setValue(Int64(max(1, currentQuantity + quantityToAdd)), forKey: "quantity")
            existing.setValue(normalizedCategory, forKey: "categoryRawValue")
            try saveIfNeeded()
            return
        }
        if nameMatches.count == 1, let existing = nameMatches.first {
            let currentQuantity = Int((existing.value(forKey: "quantity") as? Int64) ?? 1)
            existing.setValue(Int64(max(1, currentQuantity + quantityToAdd)), forKey: "quantity")
            try saveIfNeeded()
            return
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "CDShoppingItem", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(listID, forKey: "listID")
        object.setValue(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
        object.setValue(normalizedCategory, forKey: "categoryRawValue")
        object.setValue(Int64(quantityToAdd), forKey: "quantity")
        object.setValue(false, forKey: "isBought")
        object.setValue(nil, forKey: "boughtAt")
        object.setValue(false, forKey: "needsExpiryCapture")
        object.setValue(nil, forKey: "pendingExpiryDate")
        object.setValue(Date(), forKey: "createdAt")
        if let listObject = try? context.existingObject(with: currentList.objectID) {
            object.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(object, to: store)
            }
        }
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
        object.setValue(false, forKey: "needsExpiryCapture")
        object.setValue(nil, forKey: "pendingExpiryDate")
        try saveIfNeeded()
    }

    func setBoughtState(
        id: UUID,
        isBought: Bool,
        needsExpiryCapture: Bool,
        pendingExpiryDate: Date?
    ) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        object.setValue(isBought, forKey: "isBought")
        object.setValue(isBought ? (object.value(forKey: "boughtAt") as? Date ?? Date()) : nil, forKey: "boughtAt")
        object.setValue(isBought ? needsExpiryCapture : false, forKey: "needsExpiryCapture")
        object.setValue(isBought ? pendingExpiryDate : nil, forKey: "pendingExpiryDate")
        try saveIfNeeded()
    }

    func updateShoppingItem(id: UUID, quantity: Int, categoryRawValue: String?) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        object.setValue(Int64(max(1, quantity)), forKey: "quantity")
        object.setValue(normalizeCategoryKey(categoryRawValue), forKey: "categoryRawValue")
        try saveIfNeeded()
    }

    func updatePendingExpiryDate(id: UUID, pendingExpiryDate: Date?) throws {
        guard let object = try fetchShoppingObject(id: id) else { return }
        object.setValue(pendingExpiryDate, forKey: "pendingExpiryDate")
        try saveIfNeeded()
    }

    func captureBoughtItem(id: UUID, quantity: Int, expiryDate: Date) throws {
        let currentList = try activeList()
        guard let object = try fetchShoppingObject(id: id),
              let name = object.value(forKey: "name") as? String
        else { return }

        let categoryRawValue = normalizeCategoryKey(object.value(forKey: "categoryRawValue") as? String)
        let quantityValue = max(1, quantity)

        let product = NSEntityDescription.insertNewObject(forEntityName: "CDProduct", into: context)
        product.setValue(UUID(), forKey: "id")
        product.setValue(currentList.id, forKey: "listID")
        product.setValue(name, forKey: "name")
        product.setValue(categoryRawValue, forKey: "categoryRawValue")
        product.setValue(expiryDate, forKey: "expiryDate")
        product.setValue(nil, forKey: "openedAt")
        product.setValue(Int64(quantityValue), forKey: "quantity")
        product.setValue(nil, forKey: "customAfterOpeningDays")
        product.setValue(Date(), forKey: "createdAt")
        if let listObject = try? context.existingObject(with: currentList.objectID) {
            product.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(product, to: store)
            }
        }

        object.setValue(Int64(quantityValue), forKey: "quantity")
        object.setValue(false, forKey: "needsExpiryCapture")
        object.setValue(nil, forKey: "pendingExpiryDate")

        try saveIfNeeded()
    }

    private func fetchShoppingObject(id: UUID) throws -> NSManagedObject? {
        let listID = try activeList().id
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        request.predicate = NSPredicate(format: "id == %@ AND listID == %@", id as CVarArg, listID as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func activeList() throws -> CoreDataListInfo {
        if let list = try listRepository.currentList() {
            return list
        }
        return try listRepository.ensureDefaultList()
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func normalizeStoredCategoryKeys(listID: UUID) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        let objects = try context.fetch(request)
        let categoryEquivalenceMap = try categoryEquivalenceMap(listID: listID)

        var didChange = false
        for object in objects {
            let original = object.value(forKey: "categoryRawValue") as? String
            let normalized = categoryGroupingKey(
                rawCategory: original,
                categoryEquivalenceMap: categoryEquivalenceMap
            )
            if original != normalized {
                object.setValue(normalized, forKey: "categoryRawValue")
                didChange = true
            }
        }

        if didChange {
            try saveIfNeeded()
        }
    }

    private func consolidateToBuyDuplicates(listID: UUID) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDShoppingItem")
        request.predicate = NSPredicate(format: "listID == %@ AND isBought == NO", listID as CVarArg)
        let objects = try context.fetch(request)
        let categoryEquivalenceMap = try categoryEquivalenceMap(listID: listID)

        var grouped: [String: [NSManagedObject]] = [:]
        for object in objects {
            let name = normalizeName((object.value(forKey: "name") as? String) ?? "")
            guard !name.isEmpty else { continue }
            let category = categoryGroupingKey(
                rawCategory: object.value(forKey: "categoryRawValue") as? String,
                categoryEquivalenceMap: categoryEquivalenceMap
            )
            let key = "\(name)|\(category)"
            grouped[key, default: []].append(object)
        }

        var didChange = false
        for (_, duplicates) in grouped where duplicates.count > 1 {
            let sorted = duplicates.sorted {
                let lhs = ($0.value(forKey: "createdAt") as? Date) ?? .distantFuture
                let rhs = ($1.value(forKey: "createdAt") as? Date) ?? .distantFuture
                return lhs < rhs
            }

            guard let keeper = sorted.first else { continue }
            let totalQuantity = sorted.reduce(0) { partial, object in
                partial + Int((object.value(forKey: "quantity") as? Int64) ?? 1)
            }
            keeper.setValue(Int64(max(1, totalQuantity)), forKey: "quantity")

            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
            didChange = true
        }

        if didChange {
            try saveIfNeeded()
        }
    }

    private func normalizeCategoryKey(_ raw: String?) -> String {
        CategoryDefaults.canonicalCategoryKey(raw)
    }

    private func categoryEquivalenceMap(listID: UUID) throws -> [String: String] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategory")
        request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        let objects = try context.fetch(request)

        var map: [String: String] = [:]
        for object in objects {
            guard let key = object.value(forKey: "key") as? String else { continue }
            let normalizedKey = normalizeCategoryKey(key)
            guard !normalizedKey.isEmpty else { continue }

            let rawName = (object.value(forKey: "name") as? String) ?? ""
            let normalizedName = normalizeName(rawName)
            if normalizedName == "other" || normalizedName == "autre" || normalizedName == "category.other" {
                map[normalizedKey] = "other"
            }
        }

        return map
    }

    private func categoryGroupingKey(rawCategory: String?, categoryEquivalenceMap: [String: String]) -> String {
        let normalized = normalizeCategoryKey(rawCategory)
        if normalized == "other" { return "other" }
        if categoryEquivalenceMap[normalized] == "other" { return "other" }
        return normalized
    }

    private func normalizeName(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }
}
