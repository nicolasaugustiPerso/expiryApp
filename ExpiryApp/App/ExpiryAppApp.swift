import SwiftUI
import SwiftData

@main
struct ExpiryAppApp: App {
    var body: some Scene {
        WindowGroup {
            MainRootView()
                .modelContainer(for: [Product.self, CategoryRule.self, UserSettings.self])
        }
    }
}
