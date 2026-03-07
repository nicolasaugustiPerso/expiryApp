import Foundation
import CoreData
import CloudKit

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentCloudKitContainer

    private init(inMemory: Bool = false) {
        let model = CoreDataSchema.makeModel()
        container = NSPersistentCloudKitContainer(
            name: CoreDataSchema.modelName,
            managedObjectModel: model
        )

        let storeURL: URL
        if inMemory {
            storeURL = URL(fileURLWithPath: "/dev/null")
        } else {
            let base = NSPersistentContainer.defaultDirectoryURL()
            storeURL = base.appendingPathComponent("\(CoreDataSchema.modelName).sqlite")
        }

        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.nicolasaugusti.expiryapp"
        )

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("CoreData store failed to load: \(error)")
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
        await withCheckedContinuation { continuation in
            CKContainer(identifier: "iCloud.com.nicolasaugusti.expiryapp").accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
