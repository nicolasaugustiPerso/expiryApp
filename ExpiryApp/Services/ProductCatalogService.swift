import Foundation

struct ProductCatalogSuggestion {
    let id: String
    let name: String
    let categoryKey: String
}

enum ProductCatalogService {
    private struct CatalogPayload: Decodable {
        let products: [CatalogProduct]
    }

    private struct CatalogProduct: Decodable {
        let id: String
        let nameFR: String
        let nameEN: String
        let category: String
        let aliases: [String]?

        enum CodingKeys: String, CodingKey {
            case id
            case nameFR = "name_fr"
            case nameEN = "name_en"
            case category
            case aliases
        }
    }

    private static var cachedProducts: [CatalogProduct]?

    static func suggestions() -> [ProductCatalogSuggestion] {
        let language = preferredLanguageCode()
        return loadProducts().map { product in
            ProductCatalogSuggestion(
                id: product.id,
                name: language == "fr" ? product.nameFR : product.nameEN,
                categoryKey: CategoryDefaults.canonicalCategoryKey(product.category)
            )
        }
    }

    static func localizedName(for rawName: String) -> String? {
        let normalized = normalize(rawName)
        guard !normalized.isEmpty else { return nil }

        let language = preferredLanguageCode()
        for product in loadProducts() {
            let allKeys = [product.nameFR, product.nameEN] + (product.aliases ?? [])
            if allKeys.contains(where: { normalize($0) == normalized }) {
                return language == "fr" ? product.nameFR : product.nameEN
            }
        }
        return nil
    }

    private static func loadProducts() -> [CatalogProduct] {
        if let cachedProducts { return cachedProducts }

        let bundle = Bundle.main
        let candidateURLs: [URL?] = [
            bundle.url(forResource: "products", withExtension: "json"),
            bundle.url(forResource: "products", withExtension: "json", subdirectory: "data")
        ]

        for url in candidateURLs {
            guard let url else { continue }
            if let decoded = decodeProducts(from: url) {
                cachedProducts = decoded
                return decoded
            }
        }

        let fallback: [CatalogProduct] = [
            CatalogProduct(id: "milk", nameFR: "Lait", nameEN: "Milk", category: "dairy", aliases: ["lait", "milk"]),
            CatalogProduct(id: "bread", nameFR: "Pain", nameEN: "Bread", category: "bakery", aliases: ["pain", "bread"]),
            CatalogProduct(id: "eggs", nameFR: "Oeufs", nameEN: "Eggs", category: "pantry", aliases: ["oeufs", "eggs"])
        ]
        cachedProducts = fallback
        return fallback
    }

    private static func decodeProducts(from url: URL) -> [CatalogProduct]? {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(CatalogPayload.self, from: data)
            return decoded.products
        } catch {
            print("ProductCatalogService decode failed: \(error)")
            return nil
        }
    }

    private static func preferredLanguageCode() -> String {
        let configured = UserDefaults.standard.string(forKey: "app.preferred_language_code") ?? "system"
        if configured == "fr" || configured == "en" {
            return configured
        }

        let system = Locale.preferredLanguages.first ?? "en"
        return system.lowercased().hasPrefix("fr") ? "fr" : "en"
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
