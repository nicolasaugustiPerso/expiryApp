import Foundation

enum ShoppingMode: String, CaseIterable, Identifiable {
    case listOnly = "list_only"
    case connected = "connected"

    var id: String { rawValue }
}

enum ShoppingCaptureMode: String, CaseIterable, Identifiable {
    case byItem = "by_item"
    case bulk = "bulk"

    var id: String { rawValue }
}

typealias UserSettings = AppSchemaV3.UserSettings

extension UserSettings {
    var shoppingMode: ShoppingMode {
        get { ShoppingMode(rawValue: shoppingModeRawValue) ?? .listOnly }
        set { shoppingModeRawValue = newValue.rawValue }
    }

    var shoppingCaptureMode: ShoppingCaptureMode {
        get { ShoppingCaptureMode(rawValue: shoppingCaptureModeRawValue) ?? .byItem }
        set { shoppingCaptureModeRawValue = newValue.rawValue }
    }
}
