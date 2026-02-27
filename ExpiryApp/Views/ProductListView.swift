import SwiftUI
import SwiftData

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @State private var editingProduct: Product?
    @State private var productPendingUnopen: Product?
    @State private var showUnopenConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if products.isEmpty {
                    Text(L("list.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(products) { product in
                        let effectiveExpiry = ExpiryCalculator.effectiveExpiryDate(product: product, rules: rules)
                        ProductRowView(
                            product: product,
                            effectiveExpiry: effectiveExpiry,
                            onToggleOpened: { toggleOpened(product) },
                            onConsumeOne: { consumeOne(product) }
                        )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingProduct = product
                            }
                            .swipeActions {
                                Button(L("common.delete"), role: .destructive) {
                                    modelContext.delete(product)
                                    try? modelContext.save()
                                }
                            }
                    }
                }
            }
            .navigationTitle(L("app.title"))
            .sheet(item: $editingProduct) { product in
                AddEditProductView(product: product)
            }
            .alert(
                L("product.unopen_confirm_title"),
                isPresented: $showUnopenConfirmation,
                presenting: productPendingUnopen
            ) { product in
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("product.unopen_confirm_action"), role: .destructive) {
                    unopen(product)
                }
            } message: { _ in
                Text(L("product.unopen_confirm_message"))
            }
        }
    }

    private func toggleOpened(_ product: Product) {
        if product.openedAt == nil {
            openOne(product)
            return
        }

        productPendingUnopen = product
        showUnopenConfirmation = true
    }

    private func openOne(_ product: Product) {
        if product.quantity <= 1 {
            if let existingOpened = matchingOpenedProduct(for: product, excluding: product.id) {
                existingOpened.quantity += 1
                existingOpened.openedAt = min(existingOpened.openedAt ?? .now, .now)
                modelContext.delete(product)
            } else {
                product.openedAt = .now
            }
            try? modelContext.save()
            return
        }

        product.quantity -= 1
        if let existingOpened = matchingOpenedProduct(for: product, excluding: product.id) {
            existingOpened.quantity += 1
            existingOpened.openedAt = min(existingOpened.openedAt ?? .now, .now)
        } else {
            let openedCopy = Product(
                name: product.name,
                category: product.category,
                expiryDate: product.expiryDate,
                openedAt: .now,
                quantity: 1,
                customAfterOpeningDays: product.customAfterOpeningDays
            )
            modelContext.insert(openedCopy)
        }
        try? modelContext.save()
    }

    private func unopen(_ product: Product) {
        if let existingUnopened = matchingUnopenedProduct(for: product, excluding: product.id) {
            existingUnopened.quantity += product.quantity
            modelContext.delete(product)
        } else {
            product.openedAt = nil
        }
        try? modelContext.save()
        productPendingUnopen = nil
    }

    private func consumeOne(_ product: Product) {
        if product.quantity > 1 {
            product.quantity -= 1
        } else {
            modelContext.delete(product)
        }
        try? modelContext.save()
    }

    private func matchingOpenedProduct(for product: Product, excluding id: UUID) -> Product? {
        products.first {
            $0.id != id &&
            $0.openedAt != nil &&
            $0.name.caseInsensitiveCompare(product.name) == .orderedSame &&
            $0.categoryRawValue == product.categoryRawValue &&
            Calendar.current.isDate($0.expiryDate, inSameDayAs: product.expiryDate) &&
            $0.customAfterOpeningDays == product.customAfterOpeningDays
        }
    }

    private func matchingUnopenedProduct(for product: Product, excluding id: UUID) -> Product? {
        products.first {
            $0.id != id &&
            $0.openedAt == nil &&
            $0.name.caseInsensitiveCompare(product.name) == .orderedSame &&
            $0.categoryRawValue == product.categoryRawValue &&
            Calendar.current.isDate($0.expiryDate, inSameDayAs: product.expiryDate) &&
            $0.customAfterOpeningDays == product.customAfterOpeningDays
        }
    }
}
