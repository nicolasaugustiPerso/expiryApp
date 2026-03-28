import SwiftUI
import SwiftData

private enum AddStep: Int {
    case product
    case category
    case quantity
    case date
}

private struct ProductSuggestion: Identifiable {
    let id: String
    let name: String
    let categoryKey: String?
}

struct AddEditProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Product.createdAt, order: .reverse)])
    private var existingProducts: [Product]

    @Query(sort: \Category.createdAt)
    private var categories: [Category]

    let product: Product?

    @State private var name: String = ""
    @State private var categoryKey: String = "other"
    @State private var expiryDate: Date = .now
    @State private var quantity: Int = 1
    @State private var hasCustomOpenRule: Bool = false
    @State private var customAfterOpeningDays: Int = 3

    @State private var addStep: AddStep = .product
    @State private var searchText: String = ""

    private var isEditing: Bool { product != nil }
    private var categoryLookup: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })
    }

    private var fallbackCategoryKey: String {
        categoryLookup["other"]?.key ?? "other"
    }

    private func categoryDisplayName(for key: String?) -> String {
        guard let key else { return L("category.other") }
        return categoryLookup[key]?.displayName ?? key.capitalized
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    editForm
                } else {
                    addWizard
                }
            }
            .navigationTitle(isEditing ? L("product.edit") : L("product.add"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private var addWizard: some View {
        VStack(spacing: 16) {
            stepIndicator

            Group {
                switch addStep {
                case .product:
                    productStep
                case .category:
                    categoryStep
                case .quantity:
                    quantityStep
                case .date:
                    dateStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: 12) {
                if addStep != .product {
                    Button(L("common.back")) {
                        moveBack()
                    }
                    .buttonStyle(.bordered)
                }

                if addStep != .product {
                    Button(primaryTitle) {
                        primaryAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPrimaryDisabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding()
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            stepDot(for: .product)
            stepDot(for: .category)
            stepDot(for: .quantity)
            stepDot(for: .date)
        }
    }

    private func stepDot(for step: AddStep) -> some View {
        Circle()
            .fill(addStep.rawValue >= step.rawValue ? Color.blue : Color.gray.opacity(0.25))
            .frame(width: 10, height: 10)
    }

    private var productStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(L("product.search_placeholder"), text: $searchText)
                .textFieldStyle(.roundedBorder)

            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("\(L("product.name")): \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredSuggestions) { suggestion in
                        Button {
                            name = suggestion.name
                            categoryKey = suggestion.categoryKey ?? fallbackCategoryKey
                            searchText = suggestion.name
                            moveToNextStepAfterProductSelection(isSuggestion: true)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.name)
                                        .foregroundStyle(.primary)
                                    Text(categoryDisplayName(for: suggestion.categoryKey))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                            name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            categoryKey = fallbackCategoryKey
                            moveToNextStepAfterProductSelection(isSuggestion: false)
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
    
    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name)
                .font(.title3.weight(.semibold))
            Text(L("product.category_hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(categories) { current in
                        Button {
                            categoryKey = current.key
                        } label: {
                            HStack(spacing: 12) {
                                CategorySymbolView(
                                    symbolName: current.symbolName,
                                    tint: categoryKey == current.key ? .blue : .secondary,
                                    width: 20
                                )
                                Text(current.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if categoryKey == current.key {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.08))
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
            Text(name)
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

            Text(String(format: L("product.quantity"), quantity))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
        .onChange(of: quantity) { _, newValue in
            quantity = min(max(newValue, 1), 999)
        }
    }

    private var dateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(name)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var editForm: some View {
        Form {
            Section(L("product.section.main")) {
                TextField(L("product.name"), text: $name)
                Picker(L("product.category"), selection: $categoryKey) {
                    ForEach(categories) { category in
                        Text(category.displayName)
                            .tag(category.key)
                    }
                }
                DatePicker(
                    L("product.expiry_date"),
                    selection: $expiryDate,
                    displayedComponents: .date
                )
                Stepper(value: $quantity, in: 1...999) {
                    let format = L("product.quantity")
                    Text(String(format: format, quantity))
                }
            }

            Section(L("product.section.open_rule")) {
                Toggle(L("product.custom_rule_enabled"), isOn: $hasCustomOpenRule)

                if hasCustomOpenRule {
                    Stepper(value: $customAfterOpeningDays, in: 1...90) {
                        let format = L("product.after_opening_days")
                        Text(String(format: format, customAfterOpeningDays))
                    }
                }
            }

            Button(L("common.save")) {
                save()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var defaultSuggestions: [ProductSuggestion] {
        ProductCatalogService.suggestions().map { suggestion in
            ProductSuggestion(
                id: suggestion.id,
                name: suggestion.name,
                categoryKey: suggestion.categoryKey
            )
        }
    }

    private var filteredSuggestions: [ProductSuggestion] {
        var merged: [ProductSuggestion] = []
        var seen = Set<String>()

        for suggestion in historySuggestions + defaultSuggestions {
            let key = suggestion.name.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            merged.append(suggestion)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return merged }
        return merged.filter { $0.name.lowercased().contains(query) }
    }

    private var historySuggestions: [ProductSuggestion] {
        let grouped = Dictionary(grouping: existingProducts) { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var ranked: [(count: Int, suggestion: ProductSuggestion)] = []

        for (key, products) in grouped {
            guard !key.isEmpty, let representative = products.first else { continue }
            let totalQuantity = products.reduce(0) { partial, product in
                partial + product.quantity
            }
            ranked.append((
                count: totalQuantity,
                suggestion: ProductSuggestion(
                    id: "history-\(key)",
                    name: representative.name,
                    categoryKey: representative.categoryRawValue
                )
            ))
        }

        ranked.sort { lhs, rhs in
            lhs.count > rhs.count
        }

        return Array(ranked.prefix(12)).map { $0.suggestion }
    }

    private var canUseCustomName: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !filteredSuggestions.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private var primaryTitle: String {
        switch addStep {
        case .product, .category, .quantity:
            return L("common.next")
        case .date:
            return L("common.save")
        }
    }

    private var isPrimaryDisabled: Bool {
        switch addStep {
        case .product:
            return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .category:
            return false
        case .quantity:
            return quantity < 1
        case .date:
            return false
        }
    }

    private func primaryAction() {
        switch addStep {
        case .product:
            addStep = .category
        case .category:
            addStep = .quantity
        case .quantity:
            addStep = .date
        case .date:
            save()
        }
    }

    private func moveBack() {
        switch addStep {
        case .product:
            break
        case .category:
            addStep = .product
        case .quantity:
            addStep = .category
        case .date:
            addStep = .quantity
        }
    }
    
    private func moveToNextStepAfterProductSelection(isSuggestion: Bool) {
        if isSuggestion {
            addStep = .quantity
        } else {
            addStep = .category
        }
    }

    private func hydrate() {
        guard let product else { return }
        name = product.name
        categoryKey = categoryLookup[product.categoryRawValue]?.key ?? product.categoryRawValue
        expiryDate = product.expiryDate
        quantity = product.quantity
        if let custom = product.customAfterOpeningDays {
            hasCustomOpenRule = true
            customAfterOpeningDays = custom
        }
    }

    private func save() {
        if let product {
            product.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            product.categoryRawValue = categoryKey
            product.expiryDate = expiryDate
            product.quantity = max(1, quantity)
            product.customAfterOpeningDays = hasCustomOpenRule ? customAfterOpeningDays : nil
        } else {
            let newProduct = Product(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryKey: categoryKey,
                expiryDate: expiryDate,
                quantity: max(1, quantity),
                customAfterOpeningDays: hasCustomOpenRule ? customAfterOpeningDays : nil
            )
            modelContext.insert(newProduct)
        }

        try? modelContext.save()
        dismiss()
    }
}
