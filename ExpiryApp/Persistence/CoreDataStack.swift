import Foundation
import CoreData
import CloudKit

final class CoreDataStack {
    static let shared = CoreDataStack()
    static let cloudKitContainerIdentifier = "iCloud.com.nicolasaugusti.expiryapp"

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private static let cloudKitEnabled: Bool = {
        #if DEBUG
        // Keep dev runs stable by default; enable explicitly when validating iCloud.
        return ProcessInfo.processInfo.environment["ENABLE_CLOUDKIT"] == "1"
        #else
        return true
        #endif
    }()

    private init(inMemory: Bool = false) {
        let model = CoreDataSchema.makeModel()
        let cloudKitCompatibility = Self.cloudKitCompatibilityIssues(in: model)
        let shouldEnableCloudKit = Self.cloudKitEnabled && cloudKitCompatibility.isEmpty
        if !cloudKitCompatibility.isEmpty {
            print("CloudKit disabled: CoreData model is not fully compatible.")
            for issue in cloudKitCompatibility {
                print(" - \(issue)")
            }
        } else if !Self.cloudKitEnabled {
            print("CloudKit disabled (DEBUG default). Set ENABLE_CLOUDKIT=1 to enable.")
        }
        container = NSPersistentCloudKitContainer(
            name: CoreDataSchema.modelName,
            managedObjectModel: model
        )

        let descriptions: [NSPersistentStoreDescription]
        if inMemory {
            let privateDesc = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            let sharedDesc = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            privateDesc.configuration = "Private"
            sharedDesc.configuration = "Shared"
            descriptions = [privateDesc, sharedDesc]
        } else {
            let base = NSPersistentContainer.defaultDirectoryURL()
            let privateURL = base.appendingPathComponent("\(CoreDataSchema.modelName)-Private.sqlite")
            let sharedURL = base.appendingPathComponent("\(CoreDataSchema.modelName)-Shared.sqlite")
            let privateDesc = NSPersistentStoreDescription(url: privateURL)
            let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
            privateDesc.configuration = "Private"
            sharedDesc.configuration = "Shared"
            descriptions = [privateDesc, sharedDesc]
        }

        for description in descriptions {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            if shouldEnableCloudKit {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                if description.configuration == "Shared" {
                    description.cloudKitContainerOptions?.databaseScope = .shared
                } else {
                    description.cloudKitContainerOptions?.databaseScope = .private
                }
            } else {
                description.cloudKitContainerOptions = nil
            }
        }

        container.persistentStoreDescriptions = descriptions
        container.loadPersistentStores { storeDescription, error in
            let scope = storeDescription.cloudKitContainerOptions?.databaseScope ?? .private
            if let error {
                // Shared CloudKit store can fail depending on account/capabilities.
                // Do not crash the app for this; local private data can still work.
                if scope == .shared {
                    print("CoreData shared store load failed (non-fatal): \(error)")
                    self.sharedStore = nil
                    return
                }

                // For private store, try a local fallback store without CloudKit options.
                guard let url = storeDescription.url else {
                    print("CoreData private store load failed (no URL): \(error)")
                    return
                }

                do {
                    let fallback = NSPersistentStoreDescription(url: url)
                    fallback.configuration = storeDescription.configuration
                    fallback.shouldMigrateStoreAutomatically = true
                    fallback.shouldInferMappingModelAutomatically = true
                    fallback.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                    fallback.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    fallback.cloudKitContainerOptions = nil

                    let localStore = try self.container.persistentStoreCoordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: fallback.configuration,
                        at: fallback.url,
                        options: fallback.options
                    )
                    self.privateStore = localStore
                    print("CoreData private store recovered with local fallback (CloudKit disabled).")
                } catch {
                    print("CoreData private store failed to recover: \(error)")
                }
                return
            }

            if scope == .shared {
                self.sharedStore = self.container.persistentStoreCoordinator.persistentStores.first(where: {
                    $0.url == storeDescription.url
                })
            } else {
                self.privateStore = self.container.persistentStoreCoordinator.persistentStores.first(where: {
                    $0.url == storeDescription.url
                })
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }

    func checkCloudKitAccountStatus() async -> CKAccountStatus {
        guard Self.cloudKitEnabled else { return .couldNotDetermine }
        return await withCheckedContinuation { continuation in
            CKContainer(identifier: Self.cloudKitContainerIdentifier).accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    func persistentStore(for scope: CKDatabase.Scope) -> NSPersistentStore? {
        switch scope {
        case .shared: return sharedStore
        case .private: return privateStore
        default: return privateStore
        }
    }

    private static func cloudKitCompatibilityIssues(in model: NSManagedObjectModel) -> [String] {
        var issues: [String] = []

        for entity in model.entities {
            let entityName = entity.name ?? "<unnamed>"
            for attribute in entity.attributesByName.values {
                if !attribute.isOptional && attribute.defaultValue == nil {
                    issues.append("Entity \(entityName): attribute \(attribute.name) is non-optional without default.")
                }
            }
            for relationship in entity.relationshipsByName.values {
                if !relationship.isOptional {
                    issues.append("Entity \(entityName): relationship \(relationship.name) is non-optional.")
                }
            }
        }

        return issues
    }
}
