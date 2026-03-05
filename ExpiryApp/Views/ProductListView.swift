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

    @Query(sort: [SortDescriptor(\ShoppingItem.createdAt, order: .reverse)])
    private var shoppingItems: [ShoppingItem]

    @State private var editingProduct: Product?
    @State private var productPendingUnopen: Product?
    @State private var showUnopenConfirmation = false
    @State private var showBulkCaptureSheet = false

    let focusedDate: Date?
    let onFocusedDateConsumed: (() -> Void)?
    let onAddProductTap: (() -> Void)?

    init(
        focusedDate: Date? = nil,
        onFocusedDateConsumed: (() -> Void)? = nil,
        onAddProductTap: (() -> Void)? = nil
    ) {
        self.focusedDate = focusedDate
        self.onFocusedDateConsumed = onFocusedDateConsumed
        self.onAddProductTap = onAddProductTap
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Button {
                        onAddProductTap?()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text(L("home.add_expiry_product"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !pendingBulkItems.isEmpty {
                        Button {
                            showBulkCaptureSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "cart.badge.plus")
                                    .foregroundStyle(.blue)
                                Text(String(format: L("shopping.pending_banner"), pendingBulkItemsCount))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

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
            .sheet(isPresented: $showBulkCaptureSheet) {
                BulkExpiryCaptureView(items: pendingBulkItems)
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

    private var pendingBulkItems: [ShoppingItem] {
        shoppingItems.filter { $0.isBought && $0.needsExpiryCapture }
    }

    private var pendingBulkItemsCount: Int {
        pendingBulkItems.reduce(0) { $0 + $1.quantity }
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

private struct BulkExpiryCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let items: [ShoppingItem]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedProductName(item.name))
                            .font(.headline)

                        HStack {
                            Text(L("shopping.quantity_label"))
                            Spacer()
                            Stepper(value: Binding(
                                get: { item.quantity },
                                set: {
                                    item.quantity = max(1, $0)
                                    try? modelContext.save()
                                }
                            ), in: 1...99) {
                                Text("\(item.quantity)")
                                    .monospacedDigit()
                            }
                        }

                        DatePicker(
                            L("shopping.expiry_date_label"),
                            selection: Binding(
                                get: { item.pendingExpiryDate ?? .now },
                                set: {
                                    item.pendingExpiryDate = $0
                                    try? modelContext.save()
                                }
                            ),
                            displayedComponents: .date
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L("shopping.bulk_capture_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("shopping.bulk_save_all")) {
                        saveAll()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAll() {
        for item in items {
            let product = Product(
                name: item.name,
                category: item.category ?? .other,
                expiryDate: item.pendingExpiryDate ?? .now,
                quantity: max(1, item.quantity)
            )
            modelContext.insert(product)
            item.needsExpiryCapture = false
            item.pendingExpiryDate = nil
        }
        try? modelContext.save()
    }
}
