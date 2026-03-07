# iCloud Shared Lists Migration Plan

## Goal
Move from SwiftData-only storage to Core Data + CloudKit sharing so a list can be shared between users via iCloud invite links.

## Current status
- [x] Branch created for migration work.
- [x] iCloud/CloudKit entitlements added.
- [x] `CKSharingSupported` added to app plist.
- [x] Core Data + CloudKit stack scaffold added.
- [x] Initial Core Data schema scaffold added.
- [ ] Core Data entities wired to app UI.
- [ ] SwiftData -> Core Data data migration routine.
- [ ] Share list creation and invite flow.
- [ ] Join/accept shared list flow.
- [ ] Multi-list selection UI.
- [ ] Conflict/merge rules + QA matrix.

## Incremental rollout
1. Build Core Data repositories mirroring existing SwiftData reads/writes.
2. Switch Shopping list feature to Core Data behind a feature flag.
3. Switch Expiration list and Insights to Core Data.
4. Add list-scoped sharing (`CKShare`) and member management UI.
5. Remove SwiftData dependency once migration is stable.

## Notes
- Sharing is iCloud-based. Users need Apple ID + iCloud enabled.
- Notifications remain per-user and local device settings stay personal.
