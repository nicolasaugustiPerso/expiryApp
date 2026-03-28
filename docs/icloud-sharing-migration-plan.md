# iCloud Shared Lists Migration Plan

## Goal
Move from SwiftData-only storage to Core Data + CloudKit sharing so a list can be shared between users via iCloud invite links.

## Current status
- [x] Branch created for migration work.
- [x] iCloud/CloudKit entitlements added.
- [x] `CKSharingSupported` added to app plist.
- [x] Core Data + CloudKit stack scaffold added.
- [x] Initial Core Data schema scaffold added.
- [x] Core Data entities fully wired to app UI.
- [x] SwiftData -> Core Data data migration routine.
- [x] Share list creation and invite flow.
- [x] Join/accept shared list flow.
- [x] Multi-list selection UI.
- [ ] Conflict/merge rules + QA matrix.

## Incremental rollout
1. Build Core Data repositories mirroring existing SwiftData reads/writes.
2. Switch Shopping list feature to Core Data behind a feature flag.
3. Switch Expiration list and Insights to Core Data.
4. Add list-scoped sharing (`CKShare`) and member management UI.
5. Remove SwiftData dependency once migration is stable.

## Progress update
- Added `CoreDataShoppingRepository` with CRUD for list-scoped shopping items.
- Added `CoreDataShoppingView` and `CoreDataShoppingViewModel`.
- Wired shopping tab switch through `FeatureFlags.useCoreDataShopping`.
- Added one-time SwiftData -> Core Data migration service (`SwiftDataToCoreDataMigrator`).
- Added Core Data expiration repository/view (`CoreDataExpirationRepository`, `CoreDataExpirationView`).
- Added Core Data insights view based on migrated consumption events (`CoreDataInsightsView`).

## Notes
- Sharing is iCloud-based. Users need Apple ID + iCloud enabled.
- Notifications remain per-user and local device settings stay personal.
