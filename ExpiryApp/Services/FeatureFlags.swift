import Foundation

enum FeatureFlags {
    // Keep disabled by default until Core Data shopping is validated.
    static var useCoreDataShopping: Bool {
        UserDefaults.standard.bool(forKey: "feature.coredata_shopping_enabled")
    }

    static var useCoreDataExpiration: Bool {
        UserDefaults.standard.bool(forKey: "feature.coredata_expiration_enabled")
    }

    static var useCoreDataInsights: Bool {
        UserDefaults.standard.bool(forKey: "feature.coredata_insights_enabled")
    }

    static var isAnyCoreDataFeatureEnabled: Bool {
        useCoreDataShopping || useCoreDataExpiration || useCoreDataInsights
    }
}
