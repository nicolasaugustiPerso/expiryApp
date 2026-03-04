import SwiftUI
import SwiftData

private struct ProductDateGroup: Identifiable {
    let date: Date
    let products: [Product]
    var id: Date { date }
}

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Product.expiryDate), SortDescriptor(\Product.name)])
    private var products: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @State private var editingProduct: Product?
    @State private var productPendingUnopen: Product?
    @State private var showUnopenConfirmation = false

    let focusedDate: Date?
    let onFocusedDateConsumed: (() -> Void)?

    init(focusedDate: Date? = nil, onFocusedDateConsumed: (() -> Void)? = nil) {
        self.focusedDate = focusedDate
        self.onFocusedDateConsumed = onFocusedDateConsumed
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if products.isEmpty {
                        Text(L("list.empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dateGroups) { group in
                            Section {
                                ForEach(group.products) { product in
                                    let effectiveExpiry = ExpiryCalculator.effectiveExpiryDate(product: product, rules: rules)
                                    ProductRowView(
                                        product: product,
                                        effectiveExpiry: effectiveExpiry,
                                        subtitleStyle: .openedStatus,
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
                            } header: {
                                Text(group.date.formatted(date: .complete, time: .omitted))
                                    .textCase(nil)
                                    .foregroundStyle(.blue)
                            }
                            .id(group.date)
                        }
                    }
                }
                .onAppear {
                    scrollToFocusedDateIfNeeded(proxy: proxy)
                }
                .onChange(of: focusedDate) { _, _ in
                    scrollToFocusedDateIfNeeded(proxy: proxy)
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

    private var dateGroups: [ProductDateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: products) { product in
            let effective = ExpiryCalculator.effectiveExpiryDate(product: product, rules: rules)
            return calendar.startOfDay(for: effective)
        }

        let sortedDates = grouped.keys.sorted()
        return sortedDates.compactMap { date in
            guard let items = grouped[date] else { return nil }
            let sortedItems = items.sorted {
                let left = ExpiryCalculator.effectiveExpiryDate(product: $0, rules: rules)
                let right = ExpiryCalculator.effectiveExpiryDate(product: $1, rules: rules)
                if left != right { return left < right }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return ProductDateGroup(date: date, products: sortedItems)
        }
    }

    private func scrollToFocusedDateIfNeeded(proxy: ScrollViewProxy) {
        guard let focusedDate else { return }
        let key = Calendar.current.startOfDay(for: focusedDate)
        guard dateGroups.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: key) }) else {
            onFocusedDateConsumed?()
            return
        }

        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(key, anchor: .top)
            }
            onFocusedDateConsumed?()
        }
    }
}
