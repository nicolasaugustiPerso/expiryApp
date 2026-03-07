import Foundation
import CoreData

enum CoreDataSchema {
    static let modelName = "ExpiryCore"

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            sharedListEntity(),
            productEntity(),
            shoppingItemEntity(),
            categoryRuleEntity(),
            consumptionEventEntity()
        ]
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

    private static func categoryRuleEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDCategoryRule"
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            requiredUUID(name: "id"),
            requiredUUID(name: "listID"),
            requiredString(name: "categoryRawValue"),
            requiredInt64(name: "defaultAfterOpeningDays", defaultValue: 3)
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

    private static func requiredUUID(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .UUIDAttributeType
        attr.isOptional = false
        return attr
    }

    private static func requiredString(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = false
        return attr
    }

    private static func optionalString(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = true
        return attr
    }

    private static func requiredDate(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = false
        return attr
    }

    private static func optionalDate(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = true
        return attr
    }

    private static func requiredBool(name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .booleanAttributeType
        attr.isOptional = false
        attr.defaultValue = false
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
}
