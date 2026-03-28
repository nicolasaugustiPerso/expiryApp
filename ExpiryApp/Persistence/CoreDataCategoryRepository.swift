import Foundation
import CoreData
import SwiftUI

struct CoreDataCategory: Identifiable {
    let id: UUID
    let listID: UUID
    var key: String
    var name: String
    var symbolName: String
    var tintColorHex: String
    var isSystem: Bool
    var createdAt: Date

    var displayName: String {
        if name.hasPrefix("category.") {
            let localized = L(name)
            return localized.hasPrefix("category.") ? name.replacingOccurrences(of: "category.", with: "").capitalized : localized
        }
        return name
    }

    var tintColor: Color {
        Color(hex: tintColorHex) ?? .blue
    }

    static func fallbackOther() -> CoreDataCategory {
        CoreDataCategory(
            id: UUID(),
            listID: UUID(),
            key: "other",
            name: "category.other",
            symbolName: "shippingbox",
            tintColorHex: "#8E8E93",
            isSystem: true,
            createdAt: .distantPast
        )
    }
}

final class CoreDataCategoryRepository {
    private let context: NSManagedObjectContext
    private let listRepository: CoreDataListRepository

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
        self.listRepository = CoreDataListRepository(context: context)
    }

    func fetchCategories() throws -> [CoreDataCategory] {
        let list = try activeList()
        try migrateLegacyCategoryKeysIfNeeded(listID: list.id)
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategory")
        request.predicate = NSPredicate(format: "listID == %@", list.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        var objects = try context.fetch(request)

        if objects.isEmpty {
            try seedDefaultCategories(for: list)
            return try fetchCategories()
        }

        // Backfill any missing default categories without disturbing custom/user data.
        let existingKeys = Set(
            objects.compactMap { object in
                CategoryDefaults.canonicalCategoryKey(object.value(forKey: "key") as? String)
            }
        )
        var didBackfill = false
        guard let listObject = try? context.existingObject(with: list.objectID) else {
            return sortCategories(objects.compactMap(mapCategory))
        }
        for seed in CategoryDefaults.systemSeeds where !existingKeys.contains(seed.key) {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategory", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(list.id, forKey: "listID")
            object.setValue(seed.key, forKey: "key")
            object.setValue(seed.name, forKey: "name")
            object.setValue(seed.symbolName, forKey: "symbolName")
            object.setValue(seed.tintColorHex, forKey: "tintColorHex")
            object.setValue(seed.isSystem, forKey: "isSystem")
            object.setValue(Date(), forKey: "createdAt")
            object.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(object, to: store)
            }
            try ensureRule(for: seed.key, list: list, defaultDays: seed.defaultAfterOpeningDays)
            didBackfill = true
        }
        if didBackfill {
            try saveIfNeeded()
            objects = try context.fetch(request)
        }

        try normalizeMissingVisuals(in: objects)
        objects = try context.fetch(request)

        return sortCategories(objects.compactMap(mapCategory))
    }

    func addCategory(name: String, symbolName: String, tintColorHex: String) throws {
        let list = try activeList()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let key = "custom:\(UUID().uuidString.lowercased())"
        let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategory", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(list.id, forKey: "listID")
        object.setValue(key, forKey: "key")
        object.setValue(trimmed, forKey: "name")
        object.setValue(symbolName, forKey: "symbolName")
        object.setValue(tintColorHex, forKey: "tintColorHex")
        object.setValue(false, forKey: "isSystem")
        object.setValue(Date(), forKey: "createdAt")

        if let listObject = try? context.existingObject(with: list.objectID) {
            object.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(object, to: store)
            }
        }

        try ensureRule(for: key, list: list)
        try saveIfNeeded()
    }

    func updateCategory(id: UUID, name: String, symbolName: String, tintColorHex: String) throws {
        let list = try activeList()
        guard let object = try fetchCategoryObject(id: id, listID: list.id) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            object.setValue(trimmed, forKey: "name")
        }
        object.setValue(symbolName, forKey: "symbolName")
        object.setValue(tintColorHex, forKey: "tintColorHex")
        try saveIfNeeded()
    }

    func deleteCategory(id: UUID, fallbackKey: String = "other") throws {
        let list = try activeList()
        guard let object = try fetchCategoryObject(id: id, listID: list.id),
              let key = object.value(forKey: "key") as? String,
              key != fallbackKey else { return }

        let entitiesToReassign = ["CDProduct", "CDShoppingItem", "CDConsumptionEvent"]
        for entity in entitiesToReassign {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "listID == %@ AND categoryRawValue == %@", list.id as CVarArg, key)
            let objects = try context.fetch(request)
            for item in objects {
                item.setValue(fallbackKey, forKey: "categoryRawValue")
            }
        }

        let ruleRequest = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        ruleRequest.predicate = NSPredicate(format: "listID == %@ AND categoryRawValue == %@", list.id as CVarArg, key)
        for rule in try context.fetch(ruleRequest) {
            context.delete(rule)
        }

        context.delete(object)
        try saveIfNeeded()
    }

    func categoryForKey(_ key: String) -> CoreDataCategory {
        let canonicalKey = CategoryDefaults.canonicalCategoryKey(key)
        if let categories = try? fetchCategories(),
           let category = categories.first(where: { $0.key == canonicalKey }) {
            return category
        }
        if let categories = try? fetchCategories(),
           let fallback = categories.first(where: { $0.key == "other" }) {
            return fallback
        }
        return CoreDataCategory.fallbackOther()
    }

    private func fetchCategoryObject(id: UUID, listID: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategory")
        request.predicate = NSPredicate(format: "id == %@ AND listID == %@", id as CVarArg, listID as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func mapCategory(_ object: NSManagedObject) -> CoreDataCategory? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let listID = object.value(forKey: "listID") as? UUID,
            let key = object.value(forKey: "key") as? String,
            let name = object.value(forKey: "name") as? String,
            let symbolName = object.value(forKey: "symbolName") as? String,
            let tintColorHex = object.value(forKey: "tintColorHex") as? String,
            let createdAt = object.value(forKey: "createdAt") as? Date
        else {
            return nil
        }

        let canonicalKey = CategoryDefaults.canonicalCategoryKey(key)
        let resolvedSymbol = resolvedSymbolName(for: canonicalKey, rawSymbolName: symbolName)
        let resolvedTint = resolvedTintColorHex(for: canonicalKey, rawTintColorHex: tintColorHex)

        return CoreDataCategory(
            id: id,
            listID: listID,
            key: canonicalKey,
            name: name,
            symbolName: resolvedSymbol,
            tintColorHex: resolvedTint,
            isSystem: (object.value(forKey: "isSystem") as? Bool) ?? false,
            createdAt: createdAt
        )
    }

    private func seedDefaultCategories(for list: CoreDataListInfo) throws {
        guard let listObject = try? context.existingObject(with: list.objectID) else { return }
        for seed in CategoryDefaults.systemSeeds {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategory", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(list.id, forKey: "listID")
            object.setValue(seed.key, forKey: "key")
            object.setValue(seed.name, forKey: "name")
            object.setValue(seed.symbolName, forKey: "symbolName")
            object.setValue(seed.tintColorHex, forKey: "tintColorHex")
            object.setValue(seed.isSystem, forKey: "isSystem")
            object.setValue(Date(), forKey: "createdAt")
            object.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(object, to: store)
            }
        }

        for seed in CategoryDefaults.systemSeeds {
            try ensureRule(for: seed.key, list: list, defaultDays: seed.defaultAfterOpeningDays)
        }

        try saveIfNeeded()
    }

    private func ensureRule(for categoryKey: String, list: CoreDataListInfo, defaultDays: Int? = nil) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCategoryRule")
        request.predicate = NSPredicate(format: "listID == %@ AND categoryRawValue == %@", list.id as CVarArg, categoryKey)
        request.fetchLimit = 1
        if try context.fetch(request).first != nil { return }

        let object = NSEntityDescription.insertNewObject(forEntityName: "CDCategoryRule", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(list.id, forKey: "listID")
        let canonicalCategoryKey = CategoryDefaults.canonicalCategoryKey(categoryKey)
        object.setValue(canonicalCategoryKey, forKey: "categoryRawValue")
        let days = defaultDays ?? CategoryDefaults.defaultAfterOpeningDaysByKey[categoryKey] ?? 3
        object.setValue(Int64(days), forKey: "defaultAfterOpeningDays")
        let trackingEnabled = CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[canonicalCategoryKey] ?? true
        object.setValue(trackingEnabled, forKey: "isExpiryTrackingEnabled")

        if let listObject = try? context.existingObject(with: list.objectID) {
            object.setValue(listObject, forKey: "list")
            if let store = listObject.objectID.persistentStore {
                context.assign(object, to: store)
            }
        }
    }

    private func activeList() throws -> CoreDataListInfo {
        if let list = try listRepository.currentList() { return list }
        return try listRepository.ensureDefaultList()
    }

    private func migrateLegacyCategoryKeysIfNeeded(listID: UUID) throws {
        let legacyMap = CategoryDefaults.legacyToCanonicalCategoryKey
        guard !legacyMap.isEmpty else { return }

        func fetch(entity: String, key: String, value: String) throws -> [NSManagedObject] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(
                format: "listID == %@ AND \(key) == %@",
                listID as CVarArg,
                value
            )
            return try context.fetch(request)
        }

        var didChange = false

        for (legacy, canonical) in legacyMap {
            let productObjects = try fetch(entity: "CDProduct", key: "categoryRawValue", value: legacy)
            for object in productObjects {
                object.setValue(canonical, forKey: "categoryRawValue")
                didChange = true
            }

            let shoppingObjects = try fetch(entity: "CDShoppingItem", key: "categoryRawValue", value: legacy)
            for object in shoppingObjects {
                object.setValue(canonical, forKey: "categoryRawValue")
                didChange = true
            }

            let consumptionObjects = try fetch(entity: "CDConsumptionEvent", key: "categoryRawValue", value: legacy)
            for object in consumptionObjects {
                object.setValue(canonical, forKey: "categoryRawValue")
                didChange = true
            }

            let legacyRules = try fetch(entity: "CDCategoryRule", key: "categoryRawValue", value: legacy)
            let canonicalRules = try fetch(entity: "CDCategoryRule", key: "categoryRawValue", value: canonical)
            if let canonicalRule = canonicalRules.first {
                for legacyRule in legacyRules {
                    // Keep user values from canonical and remove duplicates.
                    context.delete(legacyRule)
                    didChange = true
                }
                canonicalRule.setValue(canonical, forKey: "categoryRawValue")
            } else {
                for legacyRule in legacyRules {
                    legacyRule.setValue(canonical, forKey: "categoryRawValue")
                    didChange = true
                }
            }

            let legacyCategories = try fetch(entity: "CDCategory", key: "key", value: legacy)
            let canonicalCategories = try fetch(entity: "CDCategory", key: "key", value: canonical)
            if let canonicalCategory = canonicalCategories.first {
                if !legacyCategories.isEmpty {
                    for legacyCategory in legacyCategories {
                        context.delete(legacyCategory)
                        didChange = true
                    }
                    if (canonicalCategory.value(forKey: "key") as? String) != canonical {
                        canonicalCategory.setValue(canonical, forKey: "key")
                        didChange = true
                    }
                }
            } else {
                for legacyCategory in legacyCategories {
                    legacyCategory.setValue(canonical, forKey: "key")
                    didChange = true
                }
            }
        }

        if didChange {
            try saveIfNeeded()
        }
    }

    private func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func normalizeMissingVisuals(in objects: [NSManagedObject]) throws {
        var changed = false
        for object in objects {
            let key = CategoryDefaults.canonicalCategoryKey(object.value(forKey: "key") as? String)

            let currentSymbol = (object.value(forKey: "symbolName") as? String) ?? ""
            let resolvedSymbol = resolvedSymbolName(for: key, rawSymbolName: currentSymbol)
            if currentSymbol != resolvedSymbol {
                object.setValue(resolvedSymbol, forKey: "symbolName")
                changed = true
            }

            let currentTint = (object.value(forKey: "tintColorHex") as? String) ?? ""
            let resolvedTint = resolvedTintColorHex(for: key, rawTintColorHex: currentTint)
            if currentTint != resolvedTint {
                object.setValue(resolvedTint, forKey: "tintColorHex")
                changed = true
            }
        }

        if changed {
            try saveIfNeeded()
        }
    }

    private func resolvedSymbolName(for categoryKey: String, rawSymbolName: String) -> String {
        let trimmed = rawSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return CategoryDefaults.seed(for: categoryKey)?.symbolName ?? "tag"
    }

    private func resolvedTintColorHex(for categoryKey: String, rawTintColorHex: String) -> String {
        let trimmed = rawTintColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return CategoryDefaults.seed(for: categoryKey)?.tintColorHex ?? "#007AFF"
    }

    private func sortCategories(_ categories: [CoreDataCategory]) -> [CoreDataCategory] {
        categories.sorted { lhs, rhs in
            let lhsIsOther = CategoryDefaults.canonicalCategoryKey(lhs.key) == "other"
            let rhsIsOther = CategoryDefaults.canonicalCategoryKey(rhs.key) == "other"
            if lhsIsOther != rhsIsOther {
                return !lhsIsOther
            }

            let lhsName = lhs.displayName
            let rhsName = rhs.displayName
            let compare = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if compare != .orderedSame {
                return compare == .orderedAscending
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
