import SwiftUI

private struct CoreDataShoppingSuggestion: Identifiable {
    let id: String
    let name: String
    let categoryKey: String?
}

private struct CoreDataCategoryGroup: Identifiable {
    let categoryKey: String
    let items: [CoreDataShoppingItem]
    var id: String { categoryKey }
}

@MainActor
final class CoreDataShoppingViewModel: ObservableObject {
    @Published var items: [CoreDataShoppingItem] = []
    @Published var rules: [CoreDataCategoryRule] = []
    @Published var lastError: String?

    private let repository: CoreDataShoppingRepository
    private let expirationRepository: CoreDataExpirationRepository

    init(
        repository: CoreDataShoppingRepository = CoreDataShoppingRepository(),
        expirationRepository: CoreDataExpirationRepository = CoreDataExpirationRepository()
    ) {
        self.repository = repository
        self.expirationRepository = expirationRepository
    }

    func load() {
        do {
            items = try repository.fetchShoppingItems()
            rules = try expirationRepository.fetchCategoryRules()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addItem(name: String, categoryRawValue: String?, quantity: Int = 1) {
        do {
            try repository.addShoppingItem(name: name, categoryRawValue: categoryRawValue, quantity: quantity)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ item: CoreDataShoppingItem) {
        do {
            try repository.deleteShoppingItem(id: item.id)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleBought(_ item: CoreDataShoppingItem) {
        do {
            try repository.toggleBought(id: item.id)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func update(_ item: CoreDataShoppingItem, quantity: Int, categoryRawValue: String?) {
        do {
            try repository.updateShoppingItem(id: item.id, quantity: quantity, categoryRawValue: categoryRawValue)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setBoughtState(_ item: CoreDataShoppingItem, isBought: Bool, needsExpiryCapture: Bool, pendingExpiryDate: Date?) {
        do {
            try repository.setBoughtState(
                id: item.id,
                isBought: isBought,
                needsExpiryCapture: needsExpiryCapture,
                pendingExpiryDate: pendingExpiryDate
            )
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updatePendingDate(_ item: CoreDataShoppingItem, pendingDate: Date?) {
        do {
            try repository.updatePendingExpiryDate(id: item.id, pendingExpiryDate: pendingDate)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func captureBoughtItem(_ item: CoreDataShoppingItem, quantity: Int, expiryDate: Date) {
        do {
            try repository.captureBoughtItem(id: item.id, quantity: quantity, expiryDate: expiryDate)
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    var toBuyItems: [CoreDataShoppingItem] {
        items.filter { !$0.isBought }
    }

    var boughtItems: [CoreDataShoppingItem] {
        items.filter { $0.isBought }
    }

    fileprivate func grouped(_ source: [CoreDataShoppingItem]) -> [CoreDataCategoryGroup] {
        let grouped = Dictionary(grouping: source) { item in
            normalizedCategoryKey(item.categoryRawValue)
        }

        return grouped
            .map { key, items in
                CoreDataCategoryGroup(
                    categoryKey: key,
                    items: items.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.categoryKey.localizedCaseInsensitiveCompare($1.categoryKey) == .orderedAscending
            }
    }

    func isExpiryTrackingEnabled(for item: CoreDataShoppingItem) -> Bool {
        let key = normalizedCategoryKey(item.categoryRawValue)
        if let rule = rules.first(where: { $0.categoryRawValue == key }) {
            return rule.isExpiryTrackingEnabled
        }
        return CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[key] ?? true
    }

    private func normalizedCategoryKey(_ raw: String?) -> String {
        CategoryDefaults.canonicalCategoryKey(raw)
    }
}

struct CoreDataShoppingView: View {
    @StateObject private var vm = CoreDataShoppingViewModel()
    @StateObject private var categoryVM = CoreDataCategoryViewModel()
    @AppStorage("settings.shopping_mode_raw") private var shoppingModeRawValue = ShoppingMode.listOnly.rawValue
    @AppStorage("settings.shopping_capture_mode_raw") private var shoppingCaptureModeRawValue = ShoppingCaptureMode.byItem.rawValue

    @State private var showAddSheet = false
    @State private var selectedItem: CoreDataShoppingItem?
    @State private var captureItem: CoreDataShoppingItem?
    @State private var showShoppingModeInfo = false
    @State private var searchText = ""

    private func categoryForKey(_ key: String) -> CoreDataCategory {
        categoryVM.categoryForKey(key)
    }

    private func sortToBuyGroups(_ lhs: CoreDataCategoryGroup, _ rhs: CoreDataCategoryGroup) -> Bool {
        let lhsCategory = categoryForKey(lhs.categoryKey)
        let rhsCategory = categoryForKey(rhs.categoryKey)
        let lhsIsOther = CategoryDefaults.canonicalCategoryKey(lhsCategory.key) == "other"
        let rhsIsOther = CategoryDefaults.canonicalCategoryKey(rhsCategory.key) == "other"
        if lhsIsOther != rhsIsOther {
            return !lhsIsOther
        }
        return lhsCategory.displayName.localizedCaseInsensitiveCompare(rhsCategory.displayName) == .orderedAscending
    }

    private var shoppingMode: ShoppingMode {
        ShoppingMode(rawValue: shoppingModeRawValue) ?? .listOnly
    }

    private var shoppingCaptureMode: ShoppingCaptureMode {
        ShoppingCaptureMode(rawValue: shoppingCaptureModeRawValue) ?? .byItem
    }

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 8) {
                    if isListOnlyMode {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text(shoppingLinkInfoCompactTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(shoppingLinkCompactTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Button {
                        showShoppingModeInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(shoppingLinkCompactTextColor)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 1)
                .listRowBackground(
                    Rectangle()
                        .fill(shoppingLinkCompactBackgroundColor)
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

                Button {
                    searchText = ""
                    showAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text(L("shopping.add_product_banner"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.black)
                        Spacer()
                        Text(L("common.add"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(
                    Rectangle()
                        .fill(Color.blue.opacity(0.08))
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue.opacity(0.45), lineWidth: 1)
                        )
                )
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))

                Section {
                    if vm.toBuyItems.isEmpty {
                        Text(L("shopping.empty.to_buy"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.grouped(vm.toBuyItems).sorted(by: sortToBuyGroups)) { group in
                            categoryHeader(categoryForKey(group.categoryKey))
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                row(
                                    item,
                                    isDimmed: false,
                                    showSeparator: index < group.items.count - 1
                                )
                            }
                        }
                    }
                } header: {
                    headerRow(L("shopping.section.to_buy"), isDimmed: false)
                }

                Section {
                    if vm.boughtItems.isEmpty {
                        Text(L("shopping.empty.bought"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(vm.boughtItems.enumerated()), id: \.element.id) { index, item in
                            row(
                                item,
                                isDimmed: true,
                                showSeparator: index < vm.boughtItems.count - 1
                            )
                        }
                    }
                } header: {
                    headerRow(L("shopping.section.bought"), isDimmed: true)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(8)
            .listSectionSeparator(.hidden)
            .environment(\.defaultMinListRowHeight, 34)
            .navigationTitle(L("shopping.title"))
            .task {
                vm.load()
                categoryVM.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
                vm.load()
                categoryVM.load()
            }
            .sheet(isPresented: $showAddSheet) {
                addSheet
            }
            .sheet(item: $selectedItem) { item in
                editSheet(item: item)
            }
            .sheet(item: $captureItem) { item in
                CoreDataBoughtItemCaptureView(
                    item: item,
                    onSkip: {
                        vm.setBoughtState(
                            item,
                            isBought: true,
                            needsExpiryCapture: true,
                            pendingExpiryDate: item.pendingExpiryDate ?? .now
                        )
                    },
                    onSave: { quantity, expiryDate in
                        vm.captureBoughtItem(item, quantity: quantity, expiryDate: expiryDate)
                    }
                )
            }
            .sheet(isPresented: $showShoppingModeInfo) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: isListOnlyMode ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(isListOnlyMode ? .orange : shoppingLinkCompactTextColor)
                            Text(shoppingLinkInfoCompactTitle)
                                .font(.headline)
                                .foregroundStyle(shoppingLinkCompactTextColor)
                        }
                        Text(shoppingLinkInfoText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle(L("settings.shopping_mode"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L("common.done")) { showShoppingModeInfo = false }
                        }
                    }
                }
                .presentationDetents([.height(220), .medium])
            }
            .alert("Core Data", isPresented: Binding(
                get: { vm.lastError != nil },
                set: { if !$0 { vm.lastError = nil } }
            )) {
                Button(L("common.done"), role: .cancel) {}
            } message: {
                Text(vm.lastError ?? "")
            }
        }
    }

    @ViewBuilder
    private func row(_ item: CoreDataShoppingItem, isDimmed: Bool, showSeparator: Bool) -> some View {
        let nameColor: Color = isDimmed ? .secondary : .primary
        let quantityColor: Color = isDimmed ? Color.secondary.opacity(0.9) : .secondary
        let toggleColor: Color = isDimmed ? .gray : (item.isBought ? .green : .blue)

        VStack(spacing: 3) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedProductName(item.name))
                            .font(.body)
                            .foregroundStyle(nameColor)
                    }

                    Spacer()

                    Text("x\(item.quantity)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(quantityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItem = item
                }

                Button {
                    toggleBought(item)
                } label: {
                    Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(toggleColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if showSeparator {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.leading, 0)
            }
        }
        .padding(.vertical, 1)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var shoppingLinkInfoText: String {
        switch shoppingMode {
        case .listOnly:
            return L("shopping.linked_info_list_only")
        case .connected:
            switch shoppingCaptureMode {
            case .byItem:
                return L("shopping.linked_info_connected_by_item")
            case .bulk:
                return L("shopping.linked_info_connected_bulk")
            }
        }
    }

    private var shoppingLinkInfoCompactTitle: String {
        switch shoppingMode {
        case .listOnly:
            return L("settings.shopping_mode_list_only")
        case .connected:
            switch shoppingCaptureMode {
            case .byItem:
                return "\(L("settings.shopping_mode_connected")) · \(L("settings.shopping_capture_by_item"))"
            case .bulk:
                return "\(L("settings.shopping_mode_connected")) · \(L("settings.shopping_capture_bulk"))"
            }
        }
    }

    private var isListOnlyMode: Bool {
        shoppingMode == .listOnly
    }

    private var shoppingLinkCompactTextColor: Color {
        .secondary
    }

    private var shoppingLinkCompactBackgroundColor: Color {
        isListOnlyMode ? Color.orange.opacity(0.10) : Color.gray.opacity(0.12)
    }

    private func toggleBought(_ item: CoreDataShoppingItem) {
        let currentItem = vm.items.first(where: { $0.id == item.id }) ?? item

        if currentItem.isBought {
            vm.setBoughtState(currentItem, isBought: false, needsExpiryCapture: false, pendingExpiryDate: nil)
            return
        }

        if !vm.isExpiryTrackingEnabled(for: currentItem) {
            vm.setBoughtState(currentItem, isBought: true, needsExpiryCapture: false, pendingExpiryDate: nil)
            return
        }

        if shoppingMode == .listOnly {
            vm.setBoughtState(currentItem, isBought: true, needsExpiryCapture: false, pendingExpiryDate: nil)
            return
        }

        switch shoppingCaptureMode {
        case .byItem:
            vm.setBoughtState(currentItem, isBought: true, needsExpiryCapture: false, pendingExpiryDate: nil)
            captureItem = currentItem
        case .bulk:
            vm.setBoughtState(currentItem, isBought: true, needsExpiryCapture: true, pendingExpiryDate: currentItem.pendingExpiryDate ?? .now)
        }
    }

    @ViewBuilder
    private func categoryHeader(_ category: CoreDataCategory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                CategorySymbolView(
                    symbolName: category.symbolName,
                    tint: category.tintColor,
                    font: .subheadline,
                    width: 18
                )
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.tintColor)
            }

            Rectangle()
                .fill(category.tintColor.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: 1)
        }
        .padding(.top, 3)
        .padding(.bottom, 1)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func headerRow(_ title: String, isDimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(isDimmed ? .gray : .blue)
            Rectangle()
                .fill(isDimmed ? Color.gray.opacity(0.6) : Color.blue)
                .frame(maxWidth: .infinity, maxHeight: 3)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var addSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("product.search_placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredSuggestions) { suggestion in
                            Button {
                                vm.addItem(name: suggestion.name, categoryRawValue: suggestion.categoryKey)
                                showAddSheet = false
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
                                let customName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                vm.addItem(name: customName, categoryRawValue: "other")
                                showAddSheet = false
                            } label: {
                                HStack {
                                    Text(String(format: L("product.use_custom"), searchText.trimmingCharacters(in: .whitespacesAndNewlines)))
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

    private func editSheet(item: CoreDataShoppingItem) -> some View {
        CoreDataShoppingItemEditView(
            item: item,
            categories: editCategories(for: item),
            rules: vm.rules,
            onDelete: {
                vm.delete(item)
                selectedItem = nil
            },
            onToggleBought: {
                toggleBought(item)
                selectedItem = nil
            },
            onUpdate: { quantity, categoryRawValue in
                vm.update(item, quantity: quantity, categoryRawValue: categoryRawValue)
            }
        )
    }

    private func editCategories(for item: CoreDataShoppingItem) -> [CoreDataCategory] {
        if !categoryVM.categories.isEmpty {
            return categoryVM.categories
        }

        return [CoreDataCategory.fallbackOther()]
    }

    private var defaultSuggestions: [CoreDataShoppingSuggestion] {
        ProductCatalogService.suggestions().map { suggestion in
            CoreDataShoppingSuggestion(
                id: suggestion.id,
                name: suggestion.name,
                categoryKey: suggestion.categoryKey
            )
        }
    }

    private var historySuggestions: [CoreDataShoppingSuggestion] {
        let grouped = Dictionary(grouping: vm.items) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var ranked: [(count: Int, suggestion: CoreDataShoppingSuggestion)] = []

        for (key, items) in grouped {
            guard !key.isEmpty, let representative = items.first else { continue }
            let totalQuantity = items.reduce(0) { partial, item in
                partial + item.quantity
            }
            ranked.append((
                count: totalQuantity,
                suggestion: CoreDataShoppingSuggestion(
                    id: "history-\(key)",
                    name: representative.name,
                    categoryKey: representative.categoryRawValue
                )
            ))
        }

        ranked.sort { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.suggestion.name.localizedCaseInsensitiveCompare(rhs.suggestion.name) == .orderedAscending
        }

        return Array(ranked.prefix(16)).map(\.suggestion)
    }

    private var mergedSuggestions: [CoreDataShoppingSuggestion] {
        var merged: [CoreDataShoppingSuggestion] = []
        var seen = Set<String>()
        for suggestion in historySuggestions + defaultSuggestions {
            let key = suggestion.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(suggestion)
        }
        return merged
    }

    private var filteredSuggestions: [CoreDataShoppingSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return mergedSuggestions }
        return mergedSuggestions.filter { $0.name.lowercased().contains(query) }
    }

    private var canUseCustomName: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let query = trimmed.lowercased()
        return !mergedSuggestions.contains { $0.name.lowercased() == query }
    }
}

private struct CoreDataShoppingItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    let item: CoreDataShoppingItem
    let categories: [CoreDataCategory]
    let rules: [CoreDataCategoryRule]
    let onDelete: () -> Void
    let onToggleBought: () -> Void
    let onUpdate: (_ quantity: Int, _ categoryRawValue: String?) -> Void

    @State private var quantity: Int
    @State private var categoryKey: String

    init(
        item: CoreDataShoppingItem,
        categories: [CoreDataCategory],
        rules: [CoreDataCategoryRule],
        onDelete: @escaping () -> Void,
        onToggleBought: @escaping () -> Void,
        onUpdate: @escaping (_ quantity: Int, _ categoryRawValue: String?) -> Void
    ) {
        self.item = item
        self.categories = categories
        self.rules = rules
        self.onDelete = onDelete
        self.onToggleBought = onToggleBought
        self.onUpdate = onUpdate
        _quantity = State(initialValue: max(1, item.quantity))
        let normalizedKey = CategoryDefaults.canonicalCategoryKey(item.categoryRawValue)
        let hasCurrentCategory = categories.contains(where: { $0.key == normalizedKey })
        _categoryKey = State(initialValue: hasCurrentCategory ? normalizedKey : "other")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(localizedProductName(item.name))
                        .font(.headline)

                    Stepper(value: $quantity, in: 1...999) {
                        Text(String(format: L("shopping.quantity"), quantity))
                    }

                    Picker(L("product.category"), selection: $categoryKey) {
                        ForEach(categories) { category in
                            Text(category.displayName).tag(category.key)
                        }
                    }
                    .onChange(of: categoryKey) { _, newValue in
                        onUpdate(quantity, newValue)
                    }
                    .onChange(of: quantity) { _, newValue in
                        onUpdate(max(1, newValue), categoryKey)
                    }
                }

                Section(L("product.section.open_rule")) {
                    HStack {
                        Text(L("settings.expiry_link"))
                        Spacer()
                        Text(isExpiryTrackingEnabled ? L("settings.expiry_enabled") : L("settings.expiry_disabled"))
                            .foregroundStyle(isExpiryTrackingEnabled ? .green : .secondary)
                    }

                    if isExpiryTrackingEnabled {
                        Text(String(format: L("product.after_opening_days"), afterOpeningDays))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(item.isBought ? L("shopping.mark_to_buy") : L("shopping.mark_bought")) {
                        onToggleBought()
                    }

                    Button(L("common.delete"), role: .destructive) {
                        onDelete()
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

    private var normalizedCategoryKey: String {
        CategoryDefaults.canonicalCategoryKey(categoryKey)
    }

    private var isExpiryTrackingEnabled: Bool {
        if let rule = rules.first(where: { CategoryDefaults.canonicalCategoryKey($0.categoryRawValue) == normalizedCategoryKey }) {
            return rule.isExpiryTrackingEnabled
        }
        return CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[normalizedCategoryKey] ?? true
    }

    private var afterOpeningDays: Int {
        if let rule = rules.first(where: { CategoryDefaults.canonicalCategoryKey($0.categoryRawValue) == normalizedCategoryKey }) {
            return max(1, rule.defaultAfterOpeningDays)
        }
        return CategoryDefaults.defaultAfterOpeningDaysByKey[normalizedCategoryKey] ?? 3
    }
}

private struct CoreDataBoughtItemCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let item: CoreDataShoppingItem
    let onSkip: () -> Void
    let onSave: (_ quantity: Int, _ expiryDate: Date) -> Void

    @State private var quantity: Int
    @State private var expiryDate: Date

    init(
        item: CoreDataShoppingItem,
        onSkip: @escaping () -> Void,
        onSave: @escaping (_ quantity: Int, _ expiryDate: Date) -> Void
    ) {
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

struct CoreDataBulkCaptureEntry: Identifiable {
    let item: CoreDataShoppingItem
    var quantity: Int
    var expiryDate: Date
    var id: UUID { item.id }
}

struct CoreDataBulkExpiryCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [CoreDataShoppingItem]
    let onSaveSingle: (_ item: CoreDataShoppingItem, _ quantity: Int, _ expiryDate: Date) -> Void
    let onSkip: (_ item: CoreDataShoppingItem) -> Void
    let onSaveAll: (_ entries: [CoreDataBulkCaptureEntry]) -> Void

    @State private var entries: [CoreDataBulkCaptureEntry] = []
    @State private var datePickerItemID: UUID?
    @State private var processedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleEntries) { entry in
                    row(entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                                    onSkip(entries[index].item)
                                    processedIDs.insert(entry.id)
                                }
                            } label: {
                                Text(L("common.skip"))
                            }
                        }
                }

                if visibleEntries.isEmpty {
                    Text(L("shopping.empty.bought"))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .navigationTitle(L("shopping.bulk_capture_title"))
            .sheet(item: Binding(
                get: { dateEntryForSheet },
                set: { _ in datePickerItemID = nil }
            )) { entry in
                NavigationStack {
                    Form {
                        DatePicker(
                            L("shopping.expiry_date_label"),
                            selection: Binding(
                                get: { entry.expiryDate },
                                set: { newDate in
                                    if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                                        entries[index].expiryDate = newDate
                                    }
                                }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)

                        HStack {
                            Text(localizedProductName(entry.item.name))
                            Spacer()
                            Text(shortDate(entry.expiryDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle(L("shopping.expiry_date_label"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L("common.done")) { datePickerItemID = nil }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("shopping.bulk_save_all")) {
                        onSaveAll(visibleEntries)
                        dismiss()
                    }
                    .disabled(visibleEntries.isEmpty)
                }
            }
            .onAppear {
                if entries.isEmpty {
                    entries = items.map { item in
                        CoreDataBulkCaptureEntry(
                            item: item,
                            quantity: max(1, item.quantity),
                            expiryDate: item.pendingExpiryDate ?? .now
                        )
                    }
                }
            }
        }
    }

    private var visibleEntries: [CoreDataBulkCaptureEntry] {
        entries.filter { !processedIDs.contains($0.id) }
    }

    private var dateEntryForSheet: CoreDataBulkCaptureEntry? {
        guard let datePickerItemID else { return nil }
        return visibleEntries.first(where: { $0.id == datePickerItemID })
    }

    @ViewBuilder
    private func row(_ entry: CoreDataBulkCaptureEntry) -> some View {
        HStack(spacing: 14) {
            Text(localizedProductName(entry.item.name))
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            Menu {
                ForEach(1...99, id: \.self) { value in
                    Button("\(value)") {
                        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                            entries[index].quantity = value
                        }
                    }
                }
            } label: {
                Text("\(entry.quantity)")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Circle())
            }

            Button {
                datePickerItemID = entry.id
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                    Text(shortDate(entry.expiryDate))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.primary)
                .frame(width: 54)
            }
            .buttonStyle(.plain)

            Button(L("common.add")) {
                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                    let selected = entries[index]
                    onSaveSingle(selected.item, selected.quantity, selected.expiryDate)
                    processedIDs.insert(entry.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 10)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.08))
                .padding(.vertical, 4)
        )
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func appLocale() -> Locale {
        let code = UserDefaults.standard.string(forKey: "app.preferred_language_code") ?? "system"
        if code == "system" { return .current }
        return Locale(identifier: code)
    }
}
