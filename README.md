# ExpiryApp (iPhone)

Simple iOS app to track grocery expiry dates, adjust expiry after opening, and send a single daily digest notification.

## Stack
- SwiftUI
- SwiftData (local-first)
- iCloud-ready via CloudKit entitlement
- UserNotifications (daily digest)
- English/French localization

## Features in this V1 scaffold
- Add/edit products manually with date picker and category
- Default per-category after-opening rules, editable in Settings
- Mark product as opened
- Effective expiry date rule:
  - `effective = min(expiryDate, openedAt + afterOpeningRule)`
- One daily digest notification for products expiring within `N` days
- EN/FR strings included

## Project generation
This repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`.

1. Install XcodeGen (if needed):
   - `brew install xcodegen`
2. Generate project:
   - `xcodegen generate`
3. Open project:
   - `open ExpiryApp.xcodeproj`

## Notes
- Update `DEVELOPMENT_TEAM` in `project.yml` before installing on physical device.
- Configure CloudKit container `iCloud.com.nicolasaugusti.expiryapp` in Apple Developer portal.
- App icons are placeholders and should be replaced.
