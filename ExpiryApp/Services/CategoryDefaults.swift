import Foundation

struct CategorySeed: Identifiable {
    let key: String
    let name: String
    let symbolName: String
    let tintColorHex: String
    let defaultAfterOpeningDays: Int
    let isSystem: Bool

    var id: String { key }
}

struct CategoryColorOption: Identifiable {
    let nameKey: String
    let hex: String

    var id: String { hex }
}

enum CategoryDefaults {
    static let systemSeeds: [CategorySeed] = [
        CategorySeed(key: "fruit", name: "category.fruit", symbolName: "🍎", tintColorHex: "#FF3B30", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "vegetable", name: "category.vegetable", symbolName: "🥕", tintColorHex: "#34C759", defaultAfterOpeningDays: 4, isSystem: true),
        CategorySeed(key: "bakery", name: "category.bakery", symbolName: "🥖", tintColorHex: "#FF9500", defaultAfterOpeningDays: 2, isSystem: true),
        CategorySeed(key: "dairy", name: "category.dairy", symbolName: "🥛", tintColorHex: "#007AFF", defaultAfterOpeningDays: 4, isSystem: true),
        CategorySeed(key: "fromage", name: "category.fromage", symbolName: "🧀", tintColorHex: "#007AFF", defaultAfterOpeningDays: 5, isSystem: true),
        CategorySeed(key: "meat", name: "category.meat", symbolName: "🥩", tintColorHex: "#A2845E", defaultAfterOpeningDays: 2, isSystem: true),
        CategorySeed(key: "charcuterie", name: "category.charcuterie", symbolName: "🥓", tintColorHex: "#A2845E", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "fish", name: "category.fish", symbolName: "🐟", tintColorHex: "#32ADE6", defaultAfterOpeningDays: 1, isSystem: true),
        CategorySeed(key: "frozen", name: "category.frozen", symbolName: "❄️", tintColorHex: "#00C7BE", defaultAfterOpeningDays: 14, isSystem: true),
        CategorySeed(key: "pantry", name: "category.pantry", symbolName: "archivebox", tintColorHex: "#8E8E93", defaultAfterOpeningDays: 7, isSystem: true),
        CategorySeed(key: "prepared", name: "category.prepared", symbolName: "🍱", tintColorHex: "#FF9F0A", defaultAfterOpeningDays: 2, isSystem: true),
        CategorySeed(key: "hygiene", name: "category.hygiene", symbolName: "🧴", tintColorHex: "#AF52DE", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "cleaning", name: "category.cleaning", symbolName: "🧽", tintColorHex: "#00C7BE", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "paper", name: "category.paper", symbolName: "🧻", tintColorHex: "#8E8E93", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "laundry", name: "category.laundry", symbolName: "👕", tintColorHex: "#5AC8FA", defaultAfterOpeningDays: 3, isSystem: true),
        CategorySeed(key: "other", name: "category.other", symbolName: "shippingbox", tintColorHex: "#8E8E93", defaultAfterOpeningDays: 3, isSystem: true)
    ]

    static let legacyToCanonicalCategoryKey: [String: String] = [
        "bread": "bakery",
        "milk": "dairy",
        "cheese": "fromage",
        "yogurt": "dairy"
    ]

    static let nonExpiryTrackingCategoryKeys: Set<String> = [
        "hygiene",
        "cleaning",
        "paper",
        "laundry"
    ]

    static let defaultAfterOpeningDaysByKey: [String: Int] = {
        var result: [String: Int] = [:]
        for seed in systemSeeds {
            result[seed.key] = seed.defaultAfterOpeningDays
        }
        for (legacy, canonical) in legacyToCanonicalCategoryKey {
            if let days = result[canonical] {
                result[legacy] = days
            }
        }
        return result
    }()

    static let defaultIsExpiryTrackingEnabledByKey: [String: Bool] = {
        var result: [String: Bool] = [:]
        for seed in systemSeeds {
            result[seed.key] = !nonExpiryTrackingCategoryKeys.contains(seed.key)
        }
        for (legacy, canonical) in legacyToCanonicalCategoryKey {
            if let enabled = result[canonical] {
                result[legacy] = enabled
            }
        }
        return result
    }()

    static let iconChoices: [String] = [
        "🍎",
        "🥕",
        "🥖",
        "🥛",
        "🧀",
        "🥓",
        "🥩",
        "🐟",
        "🧊",
        "🥫",
        "🍱",
        "🧼",
        "🧻",
        "🧴",
        "👕",
        "📦",
        "🧽",
        "❄️",
        "apple.logo",
        "leaf",
        "carrot",
        "birthday.cake",
        "carton",
        "circle.grid.2x2",
        "circle.grid.2x2.fill",
        "takeoutbag.and.cup.and.straw",
        "cup.and.saucer",
        "fork.knife",
        "fork.knife.circle",
        "fish",
        "snowflake",
        "archivebox",
        "shippingbox",
        "bag",
        "basket",
        "bottle.wineglass",
        "mug",
        "takeoutbag.and.cup.and.straw.fill",
        "bandage",
        "sparkles",
        "doc.text",
        "tshirt",
        "cart",
        "square.and.pencil",
        "tag"
    ]

    static let colorChoices: [CategoryColorOption] = [
        CategoryColorOption(nameKey: "color.blue", hex: "#007AFF"),
        CategoryColorOption(nameKey: "color.green", hex: "#34C759"),
        CategoryColorOption(nameKey: "color.orange", hex: "#FF9500"),
        CategoryColorOption(nameKey: "color.red", hex: "#FF3B30"),
        CategoryColorOption(nameKey: "color.yellow", hex: "#FFD60A"),
        CategoryColorOption(nameKey: "color.teal", hex: "#5AC8FA"),
        CategoryColorOption(nameKey: "color.purple", hex: "#AF52DE"),
        CategoryColorOption(nameKey: "color.pink", hex: "#FF2D55"),
        CategoryColorOption(nameKey: "color.gray", hex: "#8E8E93")
    ]

    static func seed(for key: String) -> CategorySeed? {
        systemSeeds.first(where: { $0.key == key })
    }

    static func canonicalCategoryKey(_ raw: String?) -> String {
        let trimmed = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if trimmed.isEmpty { return "other" }
        if trimmed == "other" || trimmed == "autre" || trimmed == "category.other" { return "other" }
        let unprefixed = trimmed.hasPrefix("category.") ? String(trimmed.dropFirst("category.".count)) : trimmed
        return legacyToCanonicalCategoryKey[unprefixed] ?? unprefixed
    }
}
