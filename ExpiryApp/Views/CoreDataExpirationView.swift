import SwiftUI

private struct CoreDataProductDateGroup: Identifiable {
    let date: Date
    let products: [CoreDataProduct]
    var id: Date { date }
}

@MainActor
final class CoreDataExpirationViewModel: ObservableObject {
    @Published var products: [CoreDataProduct] = []
    @Published var rules: [CoreDataCategoryRule] = []
    @Published var pendingBulkItems: [CoreDataShoppingItem] = []
    @Published var error: String?

    private let repository: CoreDataExpirationRepository
    private let shoppingRepository: CoreDataShoppingRepository
    private let calendar = Calendar.current

    init(
        repository: CoreDataExpirationRepository = CoreDataExpirationRepository(),
        shoppingRepository: CoreDataShoppingRepository = CoreDataShoppingRepository()
    ) {
        self.repository = repository
        self.shoppingRepository = shoppingRepository
    }

    func load() {
        do {
            products = try repository.fetchProducts()
            rules = try repository.fetchCategoryRules()
            pendingBulkItems = try shoppingRepository.fetchShoppingItems()
                .filter { $0.isBought && $0.needsExpiryCapture && isExpiryTrackingEnabled(categoryKey: $0.categoryRawValue) }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ product: CoreDataProduct) {
        do {
            try repository.deleteProduct(id: product.id)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleOpened(_ product: CoreDataProduct) {
        do {
            try repository.toggleOpened(id: product.id)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func consumeOne(_ product: CoreDataProduct) {
        do {
            try repository.consumeOne(id: product.id, effectiveExpiryDate: effectiveExpiryDate(for: product))
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func captureBoughtItem(_ item: CoreDataShoppingItem, quantity: Int, expiryDate: Date) {
        do {
            try shoppingRepository.captureBoughtItem(id: item.id, quantity: quantity, expiryDate: expiryDate)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func skipPendingCapture(_ item: CoreDataShoppingItem) {
        do {
            try shoppingRepository.setBoughtState(
                id: item.id,
                isBought: true,
                needsExpiryCapture: false,
                pendingExpiryDate: nil
            )
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addProduct(name: String, categoryRawValue: String?, quantity: Int, expiryDate: Date) {
        do {
            try repository.addProduct(
                name: name,
                categoryRawValue: categoryRawValue,
                quantity: quantity,
                expiryDate: expiryDate
            )
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateProduct(
        _ product: CoreDataProduct,
        name: String,
        categoryRawValue: String?,
        quantity: Int,
        expiryDate: Date,
        customAfterOpeningDays: Int?
    ) {
        do {
            try repository.updateProduct(
                id: product.id,
                name: name,
                categoryRawValue: categoryRawValue,
                quantity: quantity,
                expiryDate: expiryDate,
                customAfterOpeningDays: customAfterOpeningDays
            )
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func effectiveExpiryDate(for product: CoreDataProduct) -> Date {
        guard let openedAt = product.openedAt else { return product.expiryDate }
        let ruleDays = product.customAfterOpeningDays ?? defaultAfterOpeningDays(for: product.categoryRawValue)
        let openedExpiry = calendar.date(byAdding: .day, value: max(1, ruleDays), to: openedAt) ?? product.expiryDate
        return min(product.expiryDate, openedExpiry)
    }

    func daysUntil(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    fileprivate func groupedByDate() -> [CoreDataProductDateGroup] {
        let grouped = Dictionary(grouping: products) { product in
            calendar.startOfDay(for: effectiveExpiryDate(for: product))
        }

        return grouped.keys.sorted().compactMap { day in
            guard let items = grouped[day] else { return nil }
            let sorted = items.sorted {
                let left = effectiveExpiryDate(for: $0)
                let right = effectiveExpiryDate(for: $1)
                if left != right { return left < right }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return CoreDataProductDateGroup(date: day, products: sorted)
        }
    }

    var urgentCounts: (expired: Int, today: Int, tomorrow: Int) {
        var expired = 0
        var today = 0
        var tomorrow = 0

        for product in products {
            let days = daysUntil(effectiveExpiryDate(for: product))
            if days < 0 { expired += product.quantity }
            else if days == 0 { today += product.quantity }
            else if days == 1 { tomorrow += product.quantity }
        }
        return (expired, today, tomorrow)
    }

    private func defaultAfterOpeningDays(for categoryRawValue: String) -> Int {
        let categoryKey = CategoryDefaults.canonicalCategoryKey(categoryRawValue)
        if let rule = rules.first(where: { $0.categoryRawValue == categoryKey }) {
            return max(1, rule.defaultAfterOpeningDays)
        }
        return CategoryDefaults.defaultAfterOpeningDaysByKey[categoryKey] ?? 3
    }

    private func isExpiryTrackingEnabled(categoryKey: String?) -> Bool {
        let key = CategoryDefaults.canonicalCategoryKey(categoryKey)
        if let rule = rules.first(where: { $0.categoryRawValue == key }) {
            return rule.isExpiryTrackingEnabled
        }
        return CategoryDefaults.defaultIsExpiryTrackingEnabledByKey[key] ?? true
    }
}

struct CoreDataExpirationView: View {
    @StateObject private var vm = CoreDataExpirationViewModel()
    @StateObject private var categoryVM = CoreDataCategoryViewModel()
    @State private var showAddProductSheet = false
    @State private var showBulkCaptureSheet = false
    @State private var selectedProduct: CoreDataProduct?

    var body: some View {
        NavigationStack {
            List {
                if urgentTotal > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                        Text(String(format: L("home.urgent_one_line"), urgentTotal, urgentWindowDays))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 1)
                    .listRowBackground(
                        Rectangle()
                            .fill(Color.red.opacity(0.06))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }

                if !vm.pendingBulkItems.isEmpty {
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                            Text(String(format: L("shopping.pending_no_dates"), pendingBulkItemsCount))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Button(L("common.add")) {
                            showBulkCaptureSheet = true
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 1)
                    .listRowBackground(
                        Rectangle()
                            .fill(Color.orange.opacity(0.2))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }

                Button {
                    showAddProductSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text(L("home.add_expiry_product"))
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

                ForEach(vm.groupedByDate()) { group in
                    Section {
                        ForEach(group.products) { product in
                            row(product)
                                .swipeActions {
                                    Button(L("common.delete"), role: .destructive) {
                                        vm.delete(product)
                                    }
                                }
                        }
                    } header: {
                        Text(capitalizedDateHeader(group.date))
                            .textCase(nil)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(8)
            .environment(\.defaultMinListRowHeight, 34)
            .navigationTitle(L("app.title"))
            .task {
                vm.load()
                categoryVM.load()
            }
            .sheet(isPresented: $showAddProductSheet) {
                CoreDataAddExpirationProductSheet(
                    historySuggestions: historySuggestions,
                    onSave: { name, categoryKey, quantity, expiryDate in
                        vm.addProduct(
                            name: name,
                            categoryRawValue: categoryKey,
                            quantity: quantity,
                            expiryDate: expiryDate
                        )
                    }
                )
            }
            .sheet(isPresented: $showBulkCaptureSheet) {
                CoreDataBulkExpiryCaptureView(
                    items: vm.pendingBulkItems,
                    onSaveSingle: { item, quantity, expiryDate in
                        vm.captureBoughtItem(item, quantity: quantity, expiryDate: expiryDate)
                    },
                    onSkip: { item in
                        vm.skipPendingCapture(item)
                    },
                    onSaveAll: { entries in
                        for entry in entries {
                            vm.captureBoughtItem(entry.item, quantity: entry.quantity, expiryDate: entry.expiryDate)
                        }
                    }
                )
            }
            .sheet(item: $selectedProduct) { product in
                CoreDataExpirationItemEditView(
                    product: product,
                    categories: categoryVM.categories,
                    rules: vm.rules,
                    onUpdate: { name, categoryKey, quantity, expiryDate, customAfterOpeningDays in
                        vm.updateProduct(
                            product,
                            name: name,
                            categoryRawValue: categoryKey,
                            quantity: quantity,
                            expiryDate: expiryDate,
                            customAfterOpeningDays: customAfterOpeningDays
                        )
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
                vm.load()
                categoryVM.load()
            }
            .alert("Core Data", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button(L("common.done"), role: .cancel) {}
            } message: {
                Text(vm.error ?? "")
            }
        }
    }

    private var historySuggestions: [CoreDataExpirationSuggestion] {
        let grouped = Dictionary(grouping: vm.products) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var ranked: [(count: Int, suggestion: CoreDataExpirationSuggestion)] = []

        for (key, products) in grouped {
            guard !key.isEmpty, let representative = products.first else { continue }
            let totalQuantity = products.reduce(0) { partial, product in
                partial + product.quantity
            }
            ranked.append((
                count: totalQuantity,
                suggestion: CoreDataExpirationSuggestion(
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

    private func row(_ product: CoreDataProduct) -> some View {
        let effectiveExpiry = vm.effectiveExpiryDate(for: product)
        let days = vm.daysUntil(effectiveExpiry)
        let stateColor: Color = days < 0 ? .red : (days <= 2 ? .orange : .green)

        return HStack(spacing: 12) {
            HStack(spacing: 12) {
                CategorySymbolView(
                    symbolName: categoryVM.categoryForKey(product.categoryRawValue).symbolName,
                    tint: stateColor,
                    font: .title3,
                    width: 28
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(localizedProductName(product.name))
                            .font(.headline)
                        Text("x\(product.quantity)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProduct = product
                    }

                    HStack(spacing: 6) {
                        Button {
                            vm.toggleOpened(product)
                        } label: {
                            Image(systemName: product.openedAt == nil ? "square" : "checkmark.square.fill")
                                .foregroundStyle(product.openedAt == nil ? Color.secondary : Color.green)
                        }
                        .buttonStyle(.plain)

                        Text(openedLabel(product.openedAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(daysLabel(days))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(stateColor.opacity(0.15))
                .clipShape(Capsule())

            Button {
                vm.consumeOne(product)
            } label: {
                Image(systemName: "fork.knife.circle")
                    .font(.title3)
                    .foregroundStyle(Color.green)
            }
            .buttonStyle(.plain)
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days < 0 { return L("status.expired") }
        if days == 0 { return L("status.today") }
        let format = L("status.in_days")
        return String(format: format, days)
    }

    private func openedLabel(_ openedAt: Date?) -> String {
        guard let openedAt else { return L("product.not_opened") }
        return String(format: L("product.opened_on"), openedAt.formatted(.dateTime.day().month(.abbreviated)))
    }

    private var urgentTotal: Int {
        vm.urgentCounts.expired + vm.urgentCounts.today + vm.urgentCounts.tomorrow
    }

    private var pendingBulkItemsCount: Int {
        vm.pendingBulkItems.reduce(0) { $0 + $1.quantity }
    }

    private var urgentWindowDays: Int {
        2
    }

    private func capitalizedDateHeader(_ date: Date) -> String {
        let formatted = date.formatted(date: .complete, time: .omitted)
        guard let first = formatted.first else { return formatted }
        return String(first).uppercased() + formatted.dropFirst()
    }
}

private struct CoreDataExpirationItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    let product: CoreDataProduct
    let categories: [CoreDataCategory]
    let rules: [CoreDataCategoryRule]
    let onUpdate: (_ name: String, _ categoryKey: String, _ quantity: Int, _ expiryDate: Date, _ customAfterOpeningDays: Int?) -> Void

    @State private var name: String
    @State private var categoryKey: String
    @State private var quantity: Int
    @State private var expiryDate: Date
    @State private var hasCustomOpenRule: Bool
    @State private var customAfterOpeningDays: Int
    @State private var customAfterOpeningInput: String

    init(
        product: CoreDataProduct,
        categories: [CoreDataCategory],
        rules: [CoreDataCategoryRule],
        onUpdate: @escaping (_ name: String, _ categoryKey: String, _ quantity: Int, _ expiryDate: Date, _ customAfterOpeningDays: Int?) -> Void
    ) {
        self.product = product
        self.categories = categories
        self.rules = rules
        self.onUpdate = onUpdate
        let hasCurrentCategory = categories.contains(where: { $0.key == product.categoryRawValue })
        _name = State(initialValue: product.name)
        _categoryKey = State(initialValue: hasCurrentCategory ? product.categoryRawValue : "other")
        _quantity = State(initialValue: max(1, product.quantity))
        _expiryDate = State(initialValue: product.expiryDate)
        if let custom = product.customAfterOpeningDays {
            _hasCustomOpenRule = State(initialValue: true)
            _customAfterOpeningDays = State(initialValue: max(1, custom))
            _customAfterOpeningInput = State(initialValue: String(max(1, custom)))
        } else {
            let key = CategoryDefaults.canonicalCategoryKey(hasCurrentCategory ? product.categoryRawValue : "other")
            let defaultDays = rules.first(where: { CategoryDefaults.canonicalCategoryKey($0.categoryRawValue) == key })?.defaultAfterOpeningDays
                ?? CategoryDefaults.defaultAfterOpeningDaysByKey[key]
                ?? 3
            _hasCustomOpenRule = State(initialValue: false)
            _customAfterOpeningDays = State(initialValue: max(1, defaultDays))
            _customAfterOpeningInput = State(initialValue: String(max(1, defaultDays)))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("product.name"), text: $name)

                    Picker(L("product.category"), selection: $categoryKey) {
                        ForEach(categories) { category in
                            Text(category.displayName).tag(category.key)
                        }
                    }

                    Stepper(value: $quantity, in: 1...999) {
                        Text(String(format: L("shopping.quantity"), quantity))
                    }

                    DatePicker(
                        L("product.expiry_date"),
                        selection: $expiryDate,
                        displayedComponents: .date
                    )
                }

                Section(L("product.section.open_rule")) {
                    HStack {
                        Text(L("settings.expiry_link"))
                        Spacer()
                        Text(isExpiryTrackingEnabled ? L("settings.expiry_enabled") : L("settings.expiry_disabled"))
                            .foregroundStyle(isExpiryTrackingEnabled ? .green : .secondary)
                    }

                    if isExpiryTrackingEnabled {
                        Toggle(L("product.custom_rule_enabled"), isOn: $hasCustomOpenRule)
                            .onChange(of: hasCustomOpenRule) { _, isEnabled in
                                if isEnabled {
                                    customAfterOpeningInput = String(max(1, customAfterOpeningDays))
                                }
                            }

                        if hasCustomOpenRule {
                            HStack {
                                Text(L("product.after_opening_days_label"))
                                Spacer()
                                HStack(spacing: 10) {
                                    Button {
                                        customAfterOpeningDays = max(1, customAfterOpeningDays - 1)
                                        customAfterOpeningInput = String(customAfterOpeningDays)
                                    } label: {
                                        Image(systemName: "minus")
                                    }
                                    .buttonStyle(.plain)

                                    TextField("", text: $customAfterOpeningInput)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 44)
                                        .onChange(of: customAfterOpeningInput) { _, newValue in
                                            let digits = newValue.filter(\.isNumber)
                                            if digits != newValue {
                                                customAfterOpeningInput = digits
                                            }
                                            guard !digits.isEmpty else { return }
                                            if let parsed = Int(digits) {
                                                let clamped = min(90, max(1, parsed))
                                                customAfterOpeningDays = clamped
                                                if String(clamped) != digits {
                                                    customAfterOpeningInput = String(clamped)
                                                }
                                            }
                                        }

                                    Button {
                                        customAfterOpeningDays = min(90, customAfterOpeningDays + 1)
                                        customAfterOpeningInput = String(customAfterOpeningDays)
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        else {
                            Text(String(format: L("product.after_opening_days"), afterOpeningDays))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L("product.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        onUpdate(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            categoryKey,
                            max(1, quantity),
                            expiryDate,
                            hasCustomOpenRule && isExpiryTrackingEnabled ? max(1, customAfterOpeningDays) : nil
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        if hasCustomOpenRule && isExpiryTrackingEnabled {
            return max(1, customAfterOpeningDays)
        }
        if let rule = rules.first(where: { CategoryDefaults.canonicalCategoryKey($0.categoryRawValue) == normalizedCategoryKey }) {
            return max(1, rule.defaultAfterOpeningDays)
        }
        return CategoryDefaults.defaultAfterOpeningDaysByKey[normalizedCategoryKey] ?? 3
    }
}

private enum CoreDataExpirationAddStep: Int {
    case product
    case quantity
    case date
}

private struct CoreDataExpirationSuggestion: Identifiable {
    let id: String
    let name: String
    let categoryKey: String
}

private struct CoreDataAddExpirationProductSheet: View {
    @Environment(\.dismiss) private var dismiss

    let historySuggestions: [CoreDataExpirationSuggestion]
    let onSave: (_ name: String, _ categoryKey: String, _ quantity: Int, _ expiryDate: Date) -> Void

    @State private var step: CoreDataExpirationAddStep = .product
    @State private var searchText: String = ""
    @State private var selectedName: String = ""
    @State private var selectedCategoryKey: String = "other"
    @State private var quantity: Int = 1
    @State private var expiryDate: Date = .now

    private var defaultSuggestions: [CoreDataExpirationSuggestion] {
        ProductCatalogService.suggestions().map {
            CoreDataExpirationSuggestion(id: $0.id, name: $0.name, categoryKey: $0.categoryKey)
        }
    }

    private var suggestions: [CoreDataExpirationSuggestion] {
        var merged: [CoreDataExpirationSuggestion] = []
        var seen = Set<String>()
        for suggestion in historySuggestions + defaultSuggestions {
            let key = suggestion.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(suggestion)
        }
        return merged
    }

    private var filteredSuggestions: [CoreDataExpirationSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return suggestions }
        return suggestions.filter { $0.name.lowercased().contains(query) }
    }

    private var canUseCustomName: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.lowercased()
        return !suggestions.contains { $0.name.lowercased() == normalized }
    }

    private var primaryTitle: String {
        switch step {
        case .product:
            return L("common.next")
        case .quantity:
            return L("common.next")
        case .date:
            return L("common.save")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                stepIndicator

                Group {
                    switch step {
                    case .product:
                        productStep
                    case .quantity:
                        quantityStep
                    case .date:
                        dateStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                HStack(spacing: 12) {
                    if step != .product {
                        Button(L("common.back")) {
                            moveBack()
                        }
                        .buttonStyle(.bordered)
                    }

                    if step != .product {
                        Button(primaryTitle) {
                            primaryAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding()
            .navigationTitle(L("product.add"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: quantity) { _, newValue in
            quantity = min(max(newValue, 1), 999)
        }
    }

    private var productStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(L("product.search_placeholder"), text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredSuggestions) { suggestion in
                        Button {
                            selectedName = suggestion.name
                            selectedCategoryKey = suggestion.categoryKey
                            step = .quantity
                        } label: {
                            HStack {
                                Text(localizedProductName(suggestion.name))
                                    .foregroundStyle(.primary)
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
                            selectedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            selectedCategoryKey = "other"
                            step = .quantity
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
    }

    private var quantityStep: some View {
        VStack(spacing: 20) {
            Text(localizedProductName(selectedName))
                .font(.title2.weight(.semibold))

            Button {
                quantity = 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: quantity == 1 ? "checkmark.circle.fill" : "circle")
                    Text(L("product.quantity_one"))
                }
                .font(.headline)
            }
            .buttonStyle(.bordered)
            .tint(quantity == 1 ? .blue : .gray)

            HStack(spacing: 20) {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.plain)

                TextField("", value: $quantity, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button {
                    quantity = min(999, quantity + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
    }

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizedProductName(selectedName))
                .font(.title2.weight(.semibold))

            DatePicker(
                L("product.expiry_date"),
                selection: $expiryDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)

            Text(expiryDate.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            stepDot(for: .product)
            stepDot(for: .quantity)
            stepDot(for: .date)
        }
    }

    private func stepDot(for value: CoreDataExpirationAddStep) -> some View {
        Circle()
            .fill(step.rawValue >= value.rawValue ? Color.blue : Color.gray.opacity(0.25))
            .frame(width: 10, height: 10)
    }

    private func moveBack() {
        switch step {
        case .product:
            break
        case .quantity:
            step = .product
        case .date:
            step = .quantity
        }
    }

    private func primaryAction() {
        switch step {
        case .product:
            break
        case .quantity:
            step = .date
        case .date:
            onSave(
                selectedName.trimmingCharacters(in: .whitespacesAndNewlines),
                selectedCategoryKey,
                max(1, quantity),
                expiryDate
            )
            dismiss()
        }
    }
}
