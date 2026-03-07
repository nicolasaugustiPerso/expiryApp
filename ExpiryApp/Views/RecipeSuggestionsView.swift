import SwiftUI
import SwiftData

private struct ShoppingSuggestion: Identifiable {
    let id: String
    let name: String
    let category: ProductCategory?
    let count: Int
}

struct RecipeSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ShoppingItem.createdAt, order: .reverse)])
    private var shoppingItems: [ShoppingItem]

    @Query(sort: [SortDescriptor(\Product.createdAt, order: .reverse)])
    private var existingProducts: [Product]

    @Query private var settingsList: [UserSettings]

    @State private var showAddSheet = false
    @State private var shoppingSearchText = ""
    @State private var captureItem: ShoppingItem?
    @State private var editingItem: ShoppingItem?

    private var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    shoppingSearchText = ""
                    showAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text(L("shopping.add_product_banner"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                        Spacer()
                        Text(L("common.add"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.08))
                        .padding(.vertical, 2)
                )

                Section(L("shopping.section.to_buy")) {
                    if toBuyItems.isEmpty {
                        Text(L("shopping.empty.to_buy"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(toBuyItems) { item in
                            shoppingRow(item)
                        }
                    }
                }

                Section(L("shopping.section.bought")) {
                    if boughtItems.isEmpty {
                        Text(L("shopping.empty.bought"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(boughtItems) { item in
                            shoppingRow(item)
                        }
                    }
                }
            }
            .navigationTitle(L("shopping.title"))
            .sheet(isPresented: $showAddSheet) {
                addItemSheet
            }
            .sheet(item: $captureItem) { item in
                BoughtItemCaptureView(
                    item: item,
                    onSkip: {
                        item.needsExpiryCapture = true
                        item.pendingExpiryDate = item.pendingExpiryDate ?? .now
                        try? modelContext.save()
                    },
                    onSave: { quantity, expiryDate in
                        item.quantity = max(1, quantity)
                        item.needsExpiryCapture = false
                        item.pendingExpiryDate = nil

                        let product = Product(
                            name: item.name,
                            category: item.category ?? .other,
                            expiryDate: expiryDate,
                            quantity: max(1, quantity)
                        )
                        modelContext.insert(product)
                        try? modelContext.save()
                    }
                )
            }
            .sheet(item: $editingItem) { item in
                ShoppingItemEditView(
                    item: item,
                    onDelete: {
                        modelContext.delete(item)
                        try? modelContext.save()
                    },
                    onToggleBought: {
                        toggleBought(item)
                    }
                )
            }
        }
    }

    private var toBuyItems: [ShoppingItem] {
        shoppingItems.filter { !$0.isBought }
    }

    private var boughtItems: [ShoppingItem] {
        shoppingItems.filter { $0.isBought }
    }

    private var defaultSuggestions: [ShoppingSuggestion] {
        [
            ShoppingSuggestion(id: "milk", name: L("suggestion.milk"), category: .milk, count: 0),
            ShoppingSuggestion(id: "bread", name: L("suggestion.bread"), category: .bread, count: 0),
            ShoppingSuggestion(id: "yogurt", name: L("suggestion.yogurt"), category: .yogurt, count: 0),
            ShoppingSuggestion(id: "cheese", name: L("suggestion.cheese"), category: .cheese, count: 0),
            ShoppingSuggestion(id: "eggs", name: L("suggestion.eggs"), category: .pantry, count: 0),
            ShoppingSuggestion(id: "apples", name: L("suggestion.apples"), category: .fruit, count: 0),
            ShoppingSuggestion(id: "bananas", name: L("suggestion.bananas"), category: .fruit, count: 0),
            ShoppingSuggestion(id: "tomatoes", name: L("suggestion.tomatoes"), category: .vegetable, count: 0),
            ShoppingSuggestion(id: "chicken", name: L("suggestion.chicken"), category: .meat, count: 0),
            ShoppingSuggestion(id: "fish", name: L("suggestion.fish"), category: .fish, count: 0)
        ]
    }

    private var historySuggestions: [ShoppingSuggestion] {
        var bucket: [String: (name: String, count: Int, category: ProductCategory?)] = [:]

        for item in shoppingItems {
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let quantity = max(1, item.quantity)

            if var existing = bucket[key] {
                existing.count += quantity
                if existing.category == nil, let category = item.category {
                    existing.category = category
                }
                bucket[key] = existing
            } else {
                bucket[key] = (
                    name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    count: quantity,
                    category: item.category
                )
            }
        }

        for product in existingProducts {
            let key = product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let quantity = max(1, product.quantity)

            if var existing = bucket[key] {
                existing.count += quantity
                if existing.category == nil {
                    existing.category = product.category
                }
                bucket[key] = existing
            } else {
                bucket[key] = (
                    name: product.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    count: quantity,
                    category: product.category
                )
            }
        }

        return bucket.map { key, value in
            ShoppingSuggestion(
                id: "history-\(key)",
                name: value.name,
                category: value.category,
                count: value.count
            )
        }
        .sorted { left, right in
            if left.count != right.count { return left.count > right.count }
            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
        .prefix(12)
        .map { $0 }
    }

    private var filteredSuggestions: [ShoppingSuggestion] {
        var merged: [ShoppingSuggestion] = []
        var seen = Set<String>()

        for suggestion in historySuggestions + defaultSuggestions {
            let key = suggestion.name.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            merged.append(suggestion)
        }

        let query = shoppingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return merged }
        return merged.filter { $0.name.lowercased().contains(query) }
    }

    private var canUseCustomName: Bool {
        let trimmed = shoppingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !filteredSuggestions.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    @ViewBuilder
    private func shoppingRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedProductName(item.name))
                    .font(.headline)
                if let category = item.category {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("x\(item.quantity)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())

            Button {
                toggleBought(item)
            } label: {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isBought ? .green : .blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
    }

    private var addItemSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("product.search_placeholder"), text: $shoppingSearchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredSuggestions) { suggestion in
                            Button {
                                addSuggestion(name: suggestion.name, category: suggestion.category)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(localizedProductName(suggestion.name))
                                            .foregroundStyle(.primary)
                                        if let category = suggestion.category {
                                            Text(category.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        if canUseCustomName {
                            Button {
                                let customName = shoppingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                addSuggestion(name: customName, category: .other)
                            } label: {
                                HStack {
                                    Text(String(format: L("product.use_custom"), shoppingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle(L("shopping.add_item"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { showAddSheet = false }
                }
            }
        }
    }

    private func addSuggestion(name: String, category: ProductCategory?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let item = ShoppingItem(
            name: trimmedName,
            category: category,
            quantity: 1
        )
        modelContext.insert(item)
        try? modelContext.save()
        showAddSheet = false
    }

    private func toggleBought(_ item: ShoppingItem) {
        if item.isBought {
            item.isBought = false
            item.boughtAt = nil
            item.needsExpiryCapture = false
            item.pendingExpiryDate = nil
            try? modelContext.save()
            return
        }

        item.isBought = true
        item.boughtAt = .now

        let mode = settings?.shoppingMode ?? .listOnly
        if mode == .listOnly {
            item.needsExpiryCapture = false
            item.pendingExpiryDate = nil
            try? modelContext.save()
            return
        }

        let captureMode = settings?.shoppingCaptureMode ?? .byItem
        switch captureMode {
        case .byItem:
            item.needsExpiryCapture = false
            item.pendingExpiryDate = nil
            try? modelContext.save()
            captureItem = item
        case .bulk:
            item.needsExpiryCapture = true
            item.pendingExpiryDate = item.pendingExpiryDate ?? .now
            try? modelContext.save()
        }
    }
}

private struct ShoppingItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: ShoppingItem
    let onDelete: () -> Void
    let onToggleBought: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(localizedProductName(item.name))
                        .font(.headline)

                    Stepper(value: Binding(
                        get: { item.quantity },
                        set: { newValue in
                            item.quantity = max(1, newValue)
                            try? modelContext.save()
                        }
                    ), in: 1...999) {
                        Text(String(format: L("shopping.quantity"), item.quantity))
                    }

                    Picker(L("product.category"), selection: Binding(
                        get: { item.category ?? .other },
                        set: { newCategory in
                            item.category = newCategory
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ProductCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section {
                    Button(item.isBought ? L("shopping.mark_to_buy") : L("shopping.mark_bought")) {
                        onToggleBought()
                        dismiss()
                    }

                    Button(L("common.delete"), role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle(L("shopping.item_details"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct BoughtItemCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ShoppingItem
    let onSkip: () -> Void
    let onSave: (_ quantity: Int, _ expiryDate: Date) -> Void

    @State private var quantity: Int
    @State private var expiryDate: Date

    init(item: ShoppingItem, onSkip: @escaping () -> Void, onSave: @escaping (_ quantity: Int, _ expiryDate: Date) -> Void) {
        self.item = item
        self.onSkip = onSkip
        self.onSave = onSave
        _quantity = State(initialValue: max(1, item.quantity))
        _expiryDate = State(initialValue: item.pendingExpiryDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("shopping.capture_title")) {
                    Text(localizedProductName(item.name))
                        .font(.headline)
                    Stepper(value: $quantity, in: 1...99) {
                        Text(String(format: L("shopping.quantity"), quantity))
                    }
                    DatePicker(
                        L("product.expiry_date"),
                        selection: $expiryDate,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(L("shopping.capture_nav"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.skip")) {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        onSave(quantity, expiryDate)
                        dismiss()
                    }
                }
            }
        }
    }
}
