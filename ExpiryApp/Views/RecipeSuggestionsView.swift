import SwiftUI
import SwiftData

private struct ShoppingSuggestion: Identifiable {
    let id: String
    let name: String
    let categoryKey: String?
    let count: Int
}

private struct ShoppingCategoryGroup: Identifiable {
    let category: Category
    let items: [ShoppingItem]

    var id: String { category.key }
}

struct RecipeSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ShoppingItem.createdAt, order: .reverse)])
    private var shoppingItems: [ShoppingItem]

    @Query(sort: [SortDescriptor(\Product.createdAt, order: .reverse)])
    private var existingProducts: [Product]

    @Query(sort: \CategoryRule.categoryRawValue)
    private var rules: [CategoryRule]

    @Query(sort: \Category.createdAt)
    private var categories: [Category]

    @Query private var settingsList: [UserSettings]

    @State private var showAddSheet = false
    @State private var shoppingSearchText = ""
    @State private var captureItem: ShoppingItem?
    @State private var editingItem: ShoppingItem?

    private var settings: UserSettings? { settingsList.first }

    private var categoryLookup: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })
    }

    private func categoryForKey(_ key: String?) -> Category {
        guard let key else { return categoryLookup["other"] ?? fallbackCategory }
        return categoryLookup[key] ?? categoryLookup["other"] ?? fallbackCategory
    }

    private var fallbackCategory: Category {
        Category(
            key: "other",
            name: "category.other",
            symbolName: "shippingbox",
            tintColorHex: "#8E8E93",
            isSystem: true
        )
    }

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

                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text(shoppingLinkInfoText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.06))
                        .padding(.vertical, 4)
                )

                Section {
                    if toBuyItems.isEmpty {
                        Text(L("shopping.empty.to_buy"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groupByCategory(toBuyItems)) { group in
                            categoryHeader(group.category)
                            ForEach(group.items) { item in
                                shoppingRow(item)
                            }
                        }
                    }
                } header: {
                    headerRow(L("shopping.section.to_buy"))
                }

                Section {
                    if boughtItems.isEmpty {
                        Text(L("shopping.empty.bought"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(boughtItems) { item in
                            shoppingRow(item)
                        }
                    }
                } header: {
                    headerRow(L("shopping.section.bought"))
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(6)
            .listSectionSeparator(.hidden)
            .environment(\.defaultMinListRowHeight, 40)
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
                            categoryKey: item.categoryRawValue ?? "other",
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
        ProductCatalogService.suggestions().map { suggestion in
            ShoppingSuggestion(
                id: suggestion.id,
                name: suggestion.name,
                categoryKey: suggestion.categoryKey,
                count: 0
            )
        }
    }

    private var historySuggestions: [ShoppingSuggestion] {
        var bucket: [String: (name: String, count: Int, categoryKey: String?)] = [:]

        for item in shoppingItems {
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let quantity = max(1, item.quantity)

            if var existing = bucket[key] {
                existing.count += quantity
                if existing.categoryKey == nil, let categoryKey = item.categoryRawValue {
                    existing.categoryKey = categoryKey
                }
                bucket[key] = existing
            } else {
                bucket[key] = (
                    name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    count: quantity,
                    categoryKey: item.categoryRawValue
                )
            }
        }

        for product in existingProducts {
            let key = product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let quantity = max(1, product.quantity)

            if var existing = bucket[key] {
                existing.count += quantity
                if existing.categoryKey == nil {
                    existing.categoryKey = product.categoryRawValue
                }
                bucket[key] = existing
            } else {
                bucket[key] = (
                    name: product.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    count: quantity,
                    categoryKey: product.categoryRawValue
                )
            }
        }

        return bucket.map { key, value in
            ShoppingSuggestion(
                id: "history-\(key)",
                name: value.name,
                categoryKey: value.categoryKey,
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

    private func groupByCategory(_ items: [ShoppingItem]) -> [ShoppingCategoryGroup] {
        let grouped = Dictionary(grouping: items) { normalizedCategoryKey($0.categoryRawValue) }
        return grouped
            .map { key, items in
                let sortedItems = items.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return ShoppingCategoryGroup(category: categoryForKey(key), items: sortedItems)
            }
            .sorted {
                $0.category.displayName.localizedCaseInsensitiveCompare($1.category.displayName) == .orderedAscending
            }
    }

    private var shoppingLinkInfoText: String {
        let mode = settings?.shoppingMode ?? .listOnly
        switch mode {
        case .listOnly:
            return L("shopping.linked_info_list_only")
        case .connected:
            let captureMode = settings?.shoppingCaptureMode ?? .byItem
            switch captureMode {
            case .byItem:
                return L("shopping.linked_info_connected_by_item")
            case .bulk:
                return L("shopping.linked_info_connected_bulk")
            }
        }
    }

    @ViewBuilder
    private func shoppingRow(_ item: ShoppingItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedProductName(item.name))
                    .font(.body)
            }

            Spacer()

            Text("x\(item.quantity)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
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
        .padding(.vertical, 0)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
    }

    @ViewBuilder
    private func categoryHeader(_ category: Category) -> some View {
        HStack(spacing: 2) {
            CategorySymbolView(
                symbolName: category.symbolName,
                tint: category.tintColor
            )
            Text(category.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(category.tintColor)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.16))
        )
        .padding(.top, 1)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func headerRow(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.blue)
            Rectangle()
                .fill(Color.blue)
                .frame(maxWidth: .infinity, maxHeight: 3)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
                                addSuggestion(name: suggestion.name, categoryKey: suggestion.categoryKey)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(localizedProductName(suggestion.name))
                                            .foregroundStyle(.primary)
                                        if let key = suggestion.categoryKey {
                                            Text(categoryForKey(key).displayName)
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
                                addSuggestion(name: customName, categoryKey: "other")
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

    private func addSuggestion(name: String, categoryKey: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let normalizedNameValue = normalizedName(trimmedName)
        let normalizedCategoryValue = normalizedCategoryKey(categoryKey)

        let matches = toBuyItems.filter { existing in
            normalizedName(existing.name) == normalizedNameValue
        }
        if let existing = matches.first(where: {
            normalizedCategoryKey($0.categoryRawValue) == normalizedCategoryValue
        }) {
            existing.quantity += 1
            try? modelContext.save()
            showAddSheet = false
            return
        }
        if matches.count == 1, let existing = matches.first {
            existing.quantity += 1
            if existing.categoryRawValue == nil {
                existing.categoryRawValue = normalizedCategoryValue
            }
            try? modelContext.save()
            showAddSheet = false
            return
        }

        let item = ShoppingItem(
            name: trimmedName,
            categoryKey: normalizedCategoryValue,
            quantity: 1
        )
        modelContext.insert(item)
        try? modelContext.save()
        showAddSheet = false
    }

    private func normalizedCategoryKey(_ raw: String?) -> String {
        let trimmed = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if trimmed.isEmpty { return "other" }
        if trimmed == "other" || trimmed == "autre" { return "other" }
        if trimmed == "category.other" { return "other" }
        if trimmed.hasPrefix("category.") {
            return String(trimmed.dropFirst("category.".count))
        }
        return trimmed
    }

    private func normalizedName(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
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

        if !isExpiryTrackingEnabled(for: item) {
            item.needsExpiryCapture = false
            item.pendingExpiryDate = nil
            try? modelContext.save()
            return
        }

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

    private func isExpiryTrackingEnabled(for item: ShoppingItem) -> Bool {
        guard let key = item.categoryRawValue else { return true }
        if let rule = rules.first(where: { $0.categoryRawValue == key }) {
            return rule.isExpiryTrackingEnabled
        }
        return true
    }
}

private struct ShoppingItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]
    @Query(sort: \Category.createdAt) private var categories: [Category]

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
                        get: { item.categoryRawValue ?? "other" },
                        set: { newKey in
                            item.categoryRawValue = newKey
                            if item.isBought && !isExpiryTrackingEnabled(for: item) {
                                item.needsExpiryCapture = false
                                item.pendingExpiryDate = nil
                            }
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(categories) { category in
                            Text(category.displayName).tag(category.key)
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

    private func isExpiryTrackingEnabled(for item: ShoppingItem) -> Bool {
        guard let key = item.categoryRawValue else { return true }
        if let rule = rules.first(where: { $0.categoryRawValue == key }) {
            return rule.isExpiryTrackingEnabled
        }
        return true
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
