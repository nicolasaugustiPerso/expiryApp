import SwiftUI

private struct CoreDataShoppingSuggestion: Identifiable {
    let id: String
    let name: String
    let category: ProductCategory?
}

private struct CoreDataCategoryGroup: Identifiable {
    let category: ProductCategory
    let items: [CoreDataShoppingItem]
    var id: String { category.rawValue }
}

@MainActor
final class CoreDataShoppingViewModel: ObservableObject {
    @Published var items: [CoreDataShoppingItem] = []
    @Published var lastError: String?

    private let repository: CoreDataShoppingRepository

    init(repository: CoreDataShoppingRepository = CoreDataShoppingRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.fetchShoppingItems()
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

    var toBuyItems: [CoreDataShoppingItem] {
        items.filter { !$0.isBought }
    }

    var boughtItems: [CoreDataShoppingItem] {
        items.filter { $0.isBought }
    }

    func grouped(_ source: [CoreDataShoppingItem]) -> [CoreDataCategoryGroup] {
        let grouped = Dictionary(grouping: source) { item -> ProductCategory in
            guard let raw = item.categoryRawValue else { return .other }
            return ProductCategory(rawValue: raw) ?? .other
        }

        return grouped
            .map { category, items in
                CoreDataCategoryGroup(
                    category: category,
                    items: items.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.category.displayName.localizedCaseInsensitiveCompare($1.category.displayName) == .orderedAscending
            }
    }
}

struct CoreDataShoppingView: View {
    @StateObject private var vm = CoreDataShoppingViewModel()

    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var selectedItem: CoreDataShoppingItem?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Button {
                    searchText = ""
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

                if vm.toBuyItems.isEmpty {
                    Section(L("shopping.section.to_buy")) {
                        Text(L("shopping.empty.to_buy"))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(vm.grouped(vm.toBuyItems)) { group in
                        Section("\(L("shopping.section.to_buy")) · \(group.category.displayName)") {
                            ForEach(group.items) { item in
                                row(item)
                            }
                        }
                    }
                }

                if vm.boughtItems.isEmpty {
                    Section(L("shopping.section.bought")) {
                        Text(L("shopping.empty.bought"))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(vm.grouped(vm.boughtItems)) { group in
                        Section("\(L("shopping.section.bought")) · \(group.category.displayName)") {
                            ForEach(group.items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("shopping.title"))
            .task { vm.load() }
            .sheet(isPresented: $showAddSheet) {
                addSheet
            }
            .sheet(isPresented: $showEditSheet) {
                if let selectedItem {
                    editSheet(item: selectedItem)
                }
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
    private func row(_ item: CoreDataShoppingItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedProductName(item.name))
                    .font(.headline)
                if let raw = item.categoryRawValue, let category = ProductCategory(rawValue: raw) {
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
                vm.toggleBought(item)
            } label: {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isBought ? .green : .blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
            showEditSheet = true
        }
    }

    private var addSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L("product.search_placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(defaultSuggestions.filter { suggestion in
                            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if query.isEmpty { return true }
                            return suggestion.name.lowercased().contains(query.lowercased())
                        }) { suggestion in
                            Button {
                                vm.addItem(name: suggestion.name, categoryRawValue: suggestion.category?.rawValue)
                                showAddSheet = false
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
            onDelete: {
                vm.delete(item)
                showEditSheet = false
            },
            onToggleBought: {
                vm.toggleBought(item)
                showEditSheet = false
            },
            onUpdate: { quantity, categoryRawValue in
                vm.update(item, quantity: quantity, categoryRawValue: categoryRawValue)
            }
        )
    }

    private var defaultSuggestions: [CoreDataShoppingSuggestion] {
        [
            CoreDataShoppingSuggestion(id: "milk", name: L("suggestion.milk"), category: .milk),
            CoreDataShoppingSuggestion(id: "bread", name: L("suggestion.bread"), category: .bread),
            CoreDataShoppingSuggestion(id: "yogurt", name: L("suggestion.yogurt"), category: .yogurt),
            CoreDataShoppingSuggestion(id: "cheese", name: L("suggestion.cheese"), category: .cheese),
            CoreDataShoppingSuggestion(id: "eggs", name: L("suggestion.eggs"), category: .pantry),
            CoreDataShoppingSuggestion(id: "apples", name: L("suggestion.apples"), category: .fruit),
            CoreDataShoppingSuggestion(id: "bananas", name: L("suggestion.bananas"), category: .fruit),
            CoreDataShoppingSuggestion(id: "tomatoes", name: L("suggestion.tomatoes"), category: .vegetable),
            CoreDataShoppingSuggestion(id: "chicken", name: L("suggestion.chicken"), category: .meat),
            CoreDataShoppingSuggestion(id: "fish", name: L("suggestion.fish"), category: .fish)
        ]
    }
}

private struct CoreDataShoppingItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    let item: CoreDataShoppingItem
    let onDelete: () -> Void
    let onToggleBought: () -> Void
    let onUpdate: (_ quantity: Int, _ categoryRawValue: String?) -> Void

    @State private var quantity: Int
    @State private var category: ProductCategory

    init(
        item: CoreDataShoppingItem,
        onDelete: @escaping () -> Void,
        onToggleBought: @escaping () -> Void,
        onUpdate: @escaping (_ quantity: Int, _ categoryRawValue: String?) -> Void
    ) {
        self.item = item
        self.onDelete = onDelete
        self.onToggleBought = onToggleBought
        self.onUpdate = onUpdate
        _quantity = State(initialValue: max(1, item.quantity))
        _category = State(initialValue: ProductCategory(rawValue: item.categoryRawValue ?? "") ?? .other)
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

                    Picker(L("product.category"), selection: $category) {
                        ForEach(ProductCategory.allCases) { current in
                            Text(current.displayName).tag(current)
                        }
                    }
                    .onChange(of: category) { _, newValue in
                        onUpdate(quantity, newValue.rawValue)
                    }
                    .onChange(of: quantity) { _, newValue in
                        onUpdate(max(1, newValue), category.rawValue)
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
}
