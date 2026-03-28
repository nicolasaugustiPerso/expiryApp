import Foundation
import CoreData

enum CoreDataSchema {
    static let modelName = "ExpiryCore"

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let sharedList = sharedListEntity()
        let product = productEntity()
        let shoppingItem = shoppingItemEntity()
        let category = categoryEntity()
        let categoryRule = categoryRuleEntity()
        let consumptionEvent = consumptionEventEntity()

        let productsRel = toManyRelationship(
            name: "products",
            destination: product,
            minCount: 0,
            maxCount: 0
        )
        let shoppingItemsRel = toManyRelationship(
            name: "shoppingItems",
            destination: shoppingItem,
            minCount: 0,
            maxCount: 0
        )
        let rulesRel = toManyRelationship(
            name: "categoryRules",
            destination: categoryRule,
            minCount: 0,
            maxCount: 0
        )
        let categoriesRel = toManyRelationship(
            name: "categories",
            destination: category,
            minCount: 0,
            maxCount: 0
        )
        let eventsRel = toManyRelationship(
            name: "consumptionEvents",
            destination: consumptionEvent,
            minCount: 0,
            maxCount: 0
        )

        let productListRel = toOneRelationship(
            name: "list",
            destination: sharedList,
            isOptional: true
        )
        let shoppingListRel = toOneRelationship(
            name: "list",
            destination: sharedList,
            isOptional: true
        )
        let rulesListRel = toOneRelationship(
            name: "list",
            destination: sharedList,
            isOptional: true
        )
        let categoriesListRel = toOneRelationship(
            name: "list",
            destination: sharedList,
            isOptional: true
        )
        let eventsListRel = toOneRelationship(
            name: "list",
            destination: sharedList,
            isOptional: true
        )

        productsRel.inverseRelationship = productListRel
        productListRel.inverseRelationship = productsRel
        shoppingItemsRel.inverseRelationship = shoppingListRel
        shoppingListRel.inverseRelationship = shoppingItemsRel
        rulesRel.inverseRelationship = rulesListRel
        rulesListRel.inverseRelationship = rulesRel
        categoriesRel.inverseRelationship = categoriesListRel
        categoriesListRel.inverseRelationship = categoriesRel
        eventsRel.inverseRelationship = eventsListRel
        eventsListRel.inverseRelationship = eventsRel

        sharedList.properties += [productsRel, shoppingItemsRel, categoriesRel, rulesRel, eventsRel]
        product.properties += [productListRel]
        shoppingItem.properties += [shoppingListRel]
        category.properties += [categoriesListRel]
        categoryRule.properties += [rulesListRel]
        consumptionEvent.properties += [eventsListRel]

        let allEntities = [sharedList, product, shoppingItem, category, categoryRule, consumptionEvent]
        model.entities = allEntities
        model.setEntities(allEntities, forConfigurationName: "Private")
        model.setEntities(allEntities, forConfigurationName: "Shared")
        return model
    }

    private static func sharedListEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDSharedList"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredString(name: "name"),
            requiredBool(name: "isDefault"),
            requiredBool(name: "isShared"),
            requiredString(name: "storeScope", defaultValue: "private"),
            optionalString(name: "shareRecordName"),
            requiredDate(name: "createdAt")
        ]
        return entity
    }

    private static func productEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDProduct"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "name"),
            requiredString(name: "categoryRawValue"),
            requiredDate(name: "expiryDate"),
            optionalDate(name: "openedAt"),
            requiredInt64(name: "quantity", defaultValue: 1),
            optionalInt64(name: "customAfterOpeningDays"),
            requiredDate(name: "createdAt")
        ]
        return entity
    }

    private static func shoppingItemEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDShoppingItem"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "name"),
            optionalString(name: "categoryRawValue"),
            requiredInt64(name: "quantity", defaultValue: 1),
            requiredBool(name: "isBought"),
            optionalDate(name: "boughtAt"),
            requiredBool(name: "needsExpiryCapture"),
            optionalDate(name: "pendingExpiryDate"),
            requiredDate(name: "createdAt")
        ]
        return entity
    }

    private static func categoryEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDCategory"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "key"),
            requiredString(name: "name"),
            requiredString(name: "symbolName"),
            requiredString(name: "tintColorHex"),
            requiredBool(name: "isSystem", defaultValue: true),
            requiredDate(name: "createdAt")
        ]
        return entity
    }

    private static func categoryRuleEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDCategoryRule"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "categoryRawValue"),
            requiredInt64(name: "defaultAfterOpeningDays", defaultValue: 3),
            requiredBool(name: "isExpiryTrackingEnabled", defaultValue: true)
        ]
        return entity
    }

    private static func consumptionEventEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDConsumptionEvent"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "productName"),
            requiredString(name: "categoryRawValue"),
            requiredInt64(name: "quantity", defaultValue: 1),
            requiredDate(name: "consumedAt"),
            requiredDate(name: "effectiveExpiryDate"),
            requiredBool(name: "consumedBeforeExpiry")
        ]
        return entity
    }

    private static func requiredUUID(name: String, defaultValue: UUID = UUID()) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .UUIDAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func requiredString(name: String, defaultValue: String = "") -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func optionalString(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = true
        return attr
    }

    private static func requiredDate(name: String, defaultValue: Date = Date(timeIntervalSince1970: 0)) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func optionalDate(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = true
        return attr
    }

    private static func requiredBool(name: String, defaultValue: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .booleanAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func requiredInt64(name: String, defaultValue: Int64) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer64AttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }

    private static func optionalInt64(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer64AttributeType
        attr.isOptional = true
        return attr
    }

    private static func toManyRelationship(
        name: String,
        destination: NSEntityDescription,
        minCount: Int,
        maxCount: Int
    ) -> NSRelationshipDescription {
        let rel = NSRelationshipDescription()
        rel.name = name
        rel.destinationEntity = destination
        rel.minCount = minCount
        rel.maxCount = maxCount // 0 means unbounded
        rel.deleteRule = .cascadeDeleteRule
        rel.isOptional = true
        rel.inverseRelationship = nil
        return rel
    }

    private static func toOneRelationship(
        name: String,
        destination: NSEntityDescription,
        isOptional: Bool
    ) -> NSRelationshipDescription {
        let rel = NSRelationshipDescription()
        rel.name = name
        rel.destinationEntity = destination
        rel.minCount = isOptional ? 0 : 1
        rel.maxCount = 1
        rel.deleteRule = .nullifyDeleteRule
        rel.isOptional = isOptional
        rel.inverseRelationship = nil
        return rel
    }
}
