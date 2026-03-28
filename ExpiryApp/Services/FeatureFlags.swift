import Foundation

enum FeatureFlags {
    static var useCoreDataShopping: Bool {
        true
    }

    static var useCoreDataExpiration: Bool {
        true
    }

    static var useCoreDataInsights: Bool {
        true
    }

    static var isAnyCoreDataFeatureEnabled: Bool {
        useCoreDataShopping || useCoreDataExpiration || useCoreDataInsights
    }
}
