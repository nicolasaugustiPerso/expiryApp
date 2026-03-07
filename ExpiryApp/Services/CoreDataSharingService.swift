import Foundation
import CoreData
import CloudKit

enum CoreDataSharingService {
    // Placeholder for the upcoming share/join implementation.
    // The concrete CKShare flow will be added once the UI layer is switched to Core Data.
    static func share(
        listObjectID: NSManagedObjectID,
        in container: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {
        _ = (listObjectID, container)
        throw NSError(
            domain: "CoreDataSharingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Sharing not yet wired to the Core Data UI layer."]
        )
    }
}
