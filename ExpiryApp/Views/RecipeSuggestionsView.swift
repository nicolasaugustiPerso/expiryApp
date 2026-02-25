import SwiftUI
import SwiftData

private struct RecipeTemplate: Identifiable {
    let id = UUID()
    let titleKey: String
    let subtitleKey: String
    let keywords: [String]
    let categories: [ProductCategory]
}

private struct RecipeSuggestion: Identifiable {
    let id = UUID()
    let template: RecipeTemplate
    let matchedProducts: [String]
}

struct RecipeSuggestionsView: View {
    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    private let templates: [RecipeTemplate] = [
        RecipeTemplate(
            titleKey: "recipe.omelet.title",
            subtitleKey: "recipe.omelet.subtitle",
            keywords: ["egg", "eggs", "cheese", "milk"],
            categories: [.cheese, .milk]
        ),
        RecipeTemplate(
            titleKey: "recipe.toast.title",
            subtitleKey: "recipe.toast.subtitle",
            keywords: ["bread", "cheese", "tomato"],
            categories: [.bread, .cheese, .vegetable]
        ),
        RecipeTemplate(
            titleKey: "recipe.soup.title",
            subtitleKey: "recipe.soup.subtitle",
            keywords: ["carrot", "potato", "onion", "leek"],
            categories: [.vegetable]
        ),
        RecipeTemplate(
            titleKey: "recipe.smoothie.title",
            subtitleKey: "recipe.smoothie.subtitle",
            keywords: ["banana", "berries", "yogurt", "milk"],
            categories: [.fruit, .yogurt, .milk]
        ),
        RecipeTemplate(
            titleKey: "recipe.pasta.title",
            subtitleKey: "recipe.pasta.subtitle",
            keywords: ["tomato", "cheese", "cream"],
            categories: [.pantry, .cheese]
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                if soonExpiringProducts.isEmpty {
                    Text(NSLocalizedString("recipe.empty", comment: ""))
                        .foregroundStyle(.secondary)
                } else {
                    Section(NSLocalizedString("recipe.expiring_section", comment: "")) {
                        ForEach(soonExpiringProducts) { product in
                            let effective = ExpiryCalculator.effectiveExpiryDate(product: product, rules: rules)
                            ProductRowView(product: product, effectiveExpiry: effective)
                        }
                    }

                    Section(NSLocalizedString("recipe.suggestions_section", comment: "")) {
                        if recipeSuggestions.isEmpty {
                            Text(NSLocalizedString("recipe.no_match", comment: ""))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(recipeSuggestions) { suggestion in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(NSLocalizedString(suggestion.template.titleKey, comment: ""))
                                        .font(.headline)
                                    Text(NSLocalizedString(suggestion.template.subtitleKey, comment: ""))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    let productsLine = suggestion.matchedProducts.joined(separator: ", ")
                                    Text(String(format: NSLocalizedString("recipe.use", comment: ""), productsLine))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("recipe.title", comment: ""))
        }
    }

    private var soonExpiringProducts: [Product] {
        products.filter {
            let days = ExpiryCalculator.daysUntilExpiry(
                ExpiryCalculator.effectiveExpiryDate(product: $0, rules: rules)
            )
            return days >= 0 && days <= 7
        }
    }

    private var recipeSuggestions: [RecipeSuggestion] {
        templates.compactMap { template in
            let matches = soonExpiringProducts.filter { product in
                let name = product.name.lowercased()
                let keywordMatch = template.keywords.contains { name.contains($0) }
                let categoryMatch = template.categories.contains(product.category)
                return keywordMatch || categoryMatch
            }

            guard !matches.isEmpty else { return nil }
            return RecipeSuggestion(template: template, matchedProducts: matches.map(\.name))
        }
    }
}
