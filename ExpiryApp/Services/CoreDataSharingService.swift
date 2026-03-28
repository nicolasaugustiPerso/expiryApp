import Foundation
import CoreData
import CloudKit

enum CoreDataSharingService {
    static func share(
        managedObjects: [NSManagedObject],
        in container: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {
        typealias ShareResult = (CKShare, CKContainer)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShareResult, Error>) in
            container.share(managedObjects, to: nil) { _, share, cloudKitContainer, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let share, let cloudKitContainer else {
                    continuation.resume(throwing: NSError(
                        domain: "CoreDataSharingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Missing CKShare/container."]
                    ))
                    return
                }
                continuation.resume(returning: (share, cloudKitContainer))
            }
        }
    }

    static func fetchShare(
        for objectID: NSManagedObjectID,
        in container: NSPersistentCloudKitContainer
    ) throws -> CKShare? {
        try container.fetchShares(matching: [objectID])[objectID]
    }

    static func accept(
        metadata: CKShare.Metadata,
        in container: NSPersistentCloudKitContainer,
        sharedStore: NSPersistentStore
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func share(
        listObjectID: NSManagedObjectID,
        in container: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {
        let context = container.viewContext
        let object = try context.existingObject(with: listObjectID)
        return try await share(managedObjects: [object], in: container)
    }
}
