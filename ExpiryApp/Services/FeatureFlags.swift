import Foundation

enum FeatureFlags {
    // Keep disabled by default until Core Data shopping is validated.
    static var useCoreDataShopping: Bool {
        UserDefaults.standard.bool(forKey: "feature.coredata_shopping_enabled")
    }
}
