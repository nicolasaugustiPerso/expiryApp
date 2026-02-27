import Foundation

enum ProductCategory: String, CaseIterable, Codable, Identifiable {
    case fruit
    case vegetable
    case bread
    case milk
    case cheese
    case yogurt
    case meat
    case fish
    case frozen
    case pantry
    case other

    var id: String { rawValue }
    
    var displayName: String {
        let localized = L("category.\(rawValue)")
        return localized.hasPrefix("category.") ? rawValue.capitalized : localized
    }

    var symbolName: String {
        switch self {
        case .fruit: return "apple.logo"
        case .vegetable: return "leaf"
        case .bread: return "birthday.cake"
        case .milk: return "carton"
        case .cheese: return "takeoutbag.and.cup.and.straw"
        case .yogurt: return "cup.and.saucer"
        case .meat: return "fork.knife"
        case .fish: return "fish"
        case .frozen: return "snowflake"
        case .pantry: return "archivebox"
        case .other: return "shippingbox"
        }
    }
}
