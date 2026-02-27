import SwiftUI
import SwiftData

@main
struct ExpiryAppApp: App {
    @AppStorage("app.preferred_language_code") private var preferredLanguageCode = "system"

    var body: some Scene {
        WindowGroup {
            MainRootView()
                .id(preferredLanguageCode)
                .modelContainer(for: [Product.self, CategoryRule.self, UserSettings.self])
        }
    }
}

func L(_ key: String) -> String {
    let code = UserDefaults.standard.string(forKey: "app.preferred_language_code") ?? "system"
    guard code != "system" else { return NSLocalizedString(key, comment: "") }
    guard
        let path = Bundle.main.path(forResource: code, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return NSLocalizedString(key, comment: "")
    }
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}

func localizedProductName(_ rawName: String) -> String {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return rawName }

    let canonicalByAlias: [String: String] = [
        "milk": "suggestion.milk", "lait": "suggestion.milk",
        "bread": "suggestion.bread", "pain": "suggestion.bread",
        "yogurt": "suggestion.yogurt", "yaourt": "suggestion.yogurt",
        "cheese": "suggestion.cheese", "fromage": "suggestion.cheese",
        "eggs": "suggestion.eggs", "egg": "suggestion.eggs", "oeufs": "suggestion.eggs", "oeuf": "suggestion.eggs", "œufs": "suggestion.eggs", "œuf": "suggestion.eggs",
        "apples": "suggestion.apples", "apple": "suggestion.apples", "pommes": "suggestion.apples", "pomme": "suggestion.apples",
        "bananas": "suggestion.bananas", "banana": "suggestion.bananas", "bananes": "suggestion.bananas", "banane": "suggestion.bananas",
        "tomatoes": "suggestion.tomatoes", "tomato": "suggestion.tomatoes", "tomates": "suggestion.tomatoes", "tomate": "suggestion.tomatoes",
        "chicken": "suggestion.chicken", "poulet": "suggestion.chicken",
        "fish": "suggestion.fish", "poisson": "suggestion.fish"
    ]

    let normalized = trimmed
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()

    guard let key = canonicalByAlias[normalized] else { return rawName }
    return L(key)
}
