import SwiftUI
import SwiftData
import CloudKit
import CoreData
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.preferred_language_code") private var preferredLanguageCode = "system"
    @AppStorage("settings.notifications_enabled") private var notificationsEnabled = true
    @AppStorage("settings.reminder_lookahead_days") private var reminderLookaheadDays = 2
    @AppStorage("settings.daily_digest_hour") private var dailyDigestHour = 20
    @AppStorage("settings.daily_digest_minute") private var dailyDigestMinute = 0
    @AppStorage("settings.shopping_mode_raw") private var shoppingModeRawValue = ShoppingMode.listOnly.rawValue
    @AppStorage("settings.shopping_capture_mode_raw") private var shoppingCaptureModeRawValue = ShoppingCaptureMode.byItem.rawValue

    @StateObject private var coreDataListsVM = CoreDataListsViewModel()
    @State private var shareSheetPayload: CloudShareSheetPayload?
    @State private var coreDataErrorMessage: String?

    private let languageOptions: [(code: String, label: String)] = [
        ("system", "🌐 System"),
        ("en", "🇬🇧 English"),
        ("fr", "🇫🇷 Français")
    ]

    var body: some View {
        NavigationStack {
            settingsForm
            .navigationTitle(L("settings.title"))
            .sheet(item: $shareSheetPayload) { payload in
                CoreDataCloudSharingController(share: payload.share, container: payload.container)
            }
            .alert("Core Data", isPresented: Binding(
                get: { coreDataErrorMessage != nil },
                set: { if !$0 { coreDataErrorMessage = nil } }
            )) {
                Button(L("common.done"), role: .cancel) {}
            } message: {
                Text(coreDataErrorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                if FeatureFlags.isAnyCoreDataFeatureEnabled {
                    coreDataListsVM.load()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
                guard FeatureFlags.isAnyCoreDataFeatureEnabled else { return }
                coreDataListsVM.load()
            }
        }
    }

    @ViewBuilder
    private var settingsForm: some View {
        Form {
            Section(L("settings.section.reminders")) {
                HStack {
                    Text(L("settings.daily_notifications"))
                    Spacer()
                    Button {
                        toggleNotifications()
                    } label: {
                        Text(notificationsEnabled ? L("common.on") : L("common.off"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(notificationsEnabled ? Color.green.opacity(0.22) : Color.red.opacity(0.22))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                DatePicker(
                    L("settings.digest_time"),
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                from: DateComponents(hour: dailyDigestHour, minute: dailyDigestMinute)
                            ) ?? .now
                        },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            dailyDigestHour = c.hour ?? 20
                            dailyDigestMinute = c.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )

                HStack {
                    Text(L("settings.days_in_notifications"))
                    Spacer()
                    Menu {
                        ForEach(1...7, id: \.self) { day in
                            Button(String(day)) {
                                reminderLookaheadDays = day
                            }
                        }
                    } label: {
                        Text(String(reminderLookaheadDays))
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Section(L("settings.section.language")) {
                HStack {
                    Text(L("settings.language"))
                    Spacer()
                    Menu {
                        ForEach(languageOptions, id: \.code) { option in
                            Button(option.label) {
                                preferredLanguageCode = option.code
                                applyLanguagePreference(code: option.code)
                            }
                        }
                    } label: {
                        Text(languageLabel(for: preferredLanguageCode))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(L("settings.language_restart_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("settings.section.shopping")) {
                HStack {
                    Text(L("settings.shopping_mode"))
                    Spacer()
                    Menu {
                        ForEach(ShoppingMode.allCases) { mode in
                            Button(shoppingModeLabel(mode)) {
                                shoppingModeRawValue = mode.rawValue
                            }
                        }
                    } label: {
                        Text(shoppingModeLabel(selectedShoppingMode))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if selectedShoppingMode == .connected {
                    HStack {
                        Text(L("settings.shopping_capture_mode"))
                        Spacer()
                        Menu {
                            ForEach(ShoppingCaptureMode.allCases) { mode in
                                Button(shoppingCaptureModeLabel(mode)) {
                                    shoppingCaptureModeRawValue = mode.rawValue
                                }
                            }
                        } label: {
                            Text(shoppingCaptureModeLabel(selectedShoppingCaptureMode))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Section(L("settings.section.categories")) {
                NavigationLink(L("settings.manage_categories")) {
                    CoreDataCategoryManagementView()
                }
                NavigationLink(L("settings.manage_category_rules")) {
                    CoreDataCategoryRuleDurationView()
                }
            }

            if FeatureFlags.isAnyCoreDataFeatureEnabled {
                Section(L("settings.section.shared_lists")) {
                    HStack {
                        Text(L("settings.current_list"))
                        Spacer()
                        Menu {
                            ForEach(coreDataListsVM.lists) { list in
                                Button(list.name) {
                                    coreDataListsVM.setActiveList(list.id)
                                }
                            }
                        } label: {
                            Text(coreDataListsVM.currentListName)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Button(L("settings.share_current_list")) {
                        if coreDataListsVM.canShareCurrentList {
                            Task {
                                do {
                                    shareSheetPayload = try await coreDataListsVM.prepareCurrentListShare()
                                } catch {
                                    coreDataErrorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    .disabled(!coreDataListsVM.canShareCurrentList)

                    if !coreDataListsVM.canShareCurrentList {
                        Text(L("settings.cannot_share_shared_list"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(L("settings.join_by_link_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var selectedShoppingMode: ShoppingMode {
        ShoppingMode(rawValue: shoppingModeRawValue) ?? .listOnly
    }

    private var selectedShoppingCaptureMode: ShoppingCaptureMode {
        ShoppingCaptureMode(rawValue: shoppingCaptureModeRawValue) ?? .byItem
    }

    private func toggleNotifications() {
        Task {
            if notificationsEnabled {
                notificationsEnabled = false
                NotificationService.removeDailyDigest()
            } else {
                let granted = await NotificationService.requestPermission()
                notificationsEnabled = granted
            }
        }
    }

    private func languageLabel(for code: String) -> String {
        languageOptions.first(where: { $0.code == code })?.label ?? "🌐 System"
    }
    
    private func shoppingModeLabel(_ mode: ShoppingMode) -> String {
        switch mode {
        case .listOnly: return L("settings.shopping_mode_list_only")
        case .connected: return L("settings.shopping_mode_connected")
        }
    }

    private func shoppingCaptureModeLabel(_ mode: ShoppingCaptureMode) -> String {
        switch mode {
        case .byItem: return L("settings.shopping_capture_by_item")
        case .bulk: return L("settings.shopping_capture_bulk")
        }
    }

    private func applyLanguagePreference(code: String) {
        UserDefaults.standard.set(code, forKey: "app.preferred_language_code")
        UserDefaults.standard.synchronize()
    }
}

@MainActor
private final class CoreDataListsViewModel: ObservableObject {
    @Published var lists: [CoreDataListInfo] = []
    @Published var currentListID: UUID?

    private let listRepository = CoreDataListRepository()

    private var currentList: CoreDataListInfo? {
        guard let currentListID else { return nil }
        return lists.first(where: { $0.id == currentListID })
    }

    var currentListName: String {
        guard let selected = currentList else {
            return L("settings.no_list")
        }

        switch selected.storeScope {
        case .private:
            return selected.name
        case .shared:
            return "\(selected.name) (\(L("settings.shared_badge")))"
        }
    }

    var canShareCurrentList: Bool {
        currentList?.storeScope != .shared
    }

    func load() {
        do {
            let current = try listRepository.ensureDefaultList()
            lists = try listRepository.fetchLists()
            currentListID = current.id
        } catch {
            print("CoreData list load failed: \(error)")
        }
    }

    func setActiveList(_ id: UUID) {
        listRepository.setActiveList(id: id)
        currentListID = id
    }

    func prepareCurrentListShare() async throws -> CloudShareSheetPayload {
        let current = try listRepository.ensureDefaultList()
        let container = CoreDataStack.shared.container
        if let existing = try CoreDataSharingService.fetchShare(for: current.objectID, in: container) {
            return CloudShareSheetPayload(
                share: existing,
                container: CKContainer(identifier: CoreDataStack.cloudKitContainerIdentifier)
            )
        }

        let objects = try listRepository.allManagedObjectsForList(id: current.id)
        let (share, ckContainer) = try await CoreDataSharingService.share(managedObjects: objects, in: container)
        try listRepository.markShared(id: current.id, shareRecordName: share.recordID.recordName)
        load()
        return CloudShareSheetPayload(share: share, container: ckContainer)
    }
}

private struct CloudShareSheetPayload: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

private struct CoreDataCloudSharingController: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}

private struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]

    @State private var editorState: CategoryEditorState?
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text(L("settings.category_link_info"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.06))
                    .padding(.vertical, 4)
            )

            if categories.isEmpty {
                Text(L("settings.no_categories"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    HStack(spacing: 12) {
                        Button {
                            editorState = CategoryEditorState(category: category)
                        } label: {
                            HStack(spacing: 12) {
                                CategorySymbolView(
                                    symbolName: category.symbolName,
                                    tint: category.tintColor
                                )
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let rule = rules.first(where: { $0.categoryRawValue == category.key }) {
                            Button {
                                rule.isExpiryTrackingEnabled.toggle()
                                try? modelContext.save()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: rule.isExpiryTrackingEnabled ? "link" : "link.slash")
                                    Text(rule.isExpiryTrackingEnabled ? L("settings.expiry_enabled") : L("settings.expiry_disabled"))
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(rule.isExpiryTrackingEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                                .foregroundStyle(rule.isExpiryTrackingEnabled ? Color.green : Color.secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if category.key != "other" {
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("settings.manage_categories"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorState = CategoryEditorState(category: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(
            L("settings.delete_category_title"),
            isPresented: $showDeleteConfirm,
            presenting: categoryToDelete
        ) { category in
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) {
                deleteCategory(category)
            }
        } message: { category in
            Text(String(format: L("settings.delete_category_message"), category.displayName))
        }
        .sheet(item: $editorState) { state in
            CategoryEditorView(
                category: state.category,
                onSave: { name, symbolName, tintColorHex in
                    saveCategory(state.category, name: name, symbolName: symbolName, tintColorHex: tintColorHex)
                }
            )
        }
        .onAppear(perform: ensureRules)
        .onChange(of: categories.count) { _, _ in
            ensureRules()
        }
    }

    private func ensureRules() {
        let existing = Set(rules.map(\.categoryRawValue))
        for category in categories where !existing.contains(category.key) {
            let defaultDays = CategoryDefaults.defaultAfterOpeningDaysByKey[category.key] ?? 3
            modelContext.insert(CategoryRule(
                categoryKey: category.key,
                defaultAfterOpeningDays: defaultDays,
                isExpiryTrackingEnabled: true
            ))
        }
        try? modelContext.save()
    }

    private func saveCategory(_ category: Category?, name: String, symbolName: String, tintColorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let category {
            category.name = trimmed
            category.symbolName = symbolName
            category.tintColorHex = tintColorHex
            try? modelContext.save()
        } else {
            let key = "custom:\(UUID().uuidString.lowercased())"
            let newCategory = Category(
                key: key,
                name: trimmed,
                symbolName: symbolName,
                tintColorHex: tintColorHex,
                isSystem: false
            )
            modelContext.insert(newCategory)
            let defaultDays = CategoryDefaults.defaultAfterOpeningDaysByKey[key] ?? 3
            modelContext.insert(CategoryRule(
                categoryKey: key,
                defaultAfterOpeningDays: defaultDays,
                isExpiryTrackingEnabled: true
            ))
            try? modelContext.save()
        }
    }

    private func deleteCategory(_ category: Category) {
        guard category.key != "other" else { return }
        let fallbackKey = "other"

        let key = category.key

        let products = (try? modelContext.fetch(FetchDescriptor<Product>())) ?? []
        let filteredProducts = products.filter { $0.categoryRawValue == key }
        for product in filteredProducts {
            product.categoryRawValue = fallbackKey
        }

        let shoppingItems = (try? modelContext.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        let filteredShoppingItems = shoppingItems.filter { $0.categoryRawValue == key }
        for item in filteredShoppingItems {
            item.categoryRawValue = fallbackKey
        }

        let events = (try? modelContext.fetch(FetchDescriptor<ConsumptionEvent>())) ?? []
        let filteredEvents = events.filter { $0.categoryRawValue == key }
        for event in filteredEvents {
            event.categoryRawValue = fallbackKey
        }

        if let rule = rules.first(where: { $0.categoryRawValue == category.key }) {
            modelContext.delete(rule)
        }

        modelContext.delete(category)
        try? modelContext.save()
    }
}

private struct CategoryRuleDurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]

    var body: some View {
        List {
            ForEach(categories) { category in
                if let rule = rules.first(where: { $0.categoryRawValue == category.key }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                CategorySymbolView(
                                    symbolName: category.symbolName,
                                    tint: category.tintColor
                                )
                                Text(category.displayName)
                            }
                            Toggle(L("settings.expiry_link"), isOn: Binding(
                                get: { rule.isExpiryTrackingEnabled },
                                set: { newValue in
                                    rule.isExpiryTrackingEnabled = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .font(.caption)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                rule.defaultAfterOpeningDays = max(1, rule.defaultAfterOpeningDays - 1)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.bordered)

                            Text("\(rule.defaultAfterOpeningDays)d")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 44)

                            Button {
                                rule.defaultAfterOpeningDays = min(90, rule.defaultAfterOpeningDays + 1)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("settings.manage_category_rules"))
        .onAppear(perform: ensureRules)
        .onChange(of: categories.count) { _, _ in
            ensureRules()
        }
    }

    private func ensureRules() {
        let existing = Set(rules.map(\.categoryRawValue))
        for category in categories where !existing.contains(category.key) {
            let defaultDays = CategoryDefaults.defaultAfterOpeningDaysByKey[category.key] ?? 3
            modelContext.insert(CategoryRule(
                categoryKey: category.key,
                defaultAfterOpeningDays: defaultDays,
                isExpiryTrackingEnabled: true
            ))
        }
        try? modelContext.save()
    }
}

private struct CategoryEditorState: Identifiable {
    let id = UUID()
    let category: Category?
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category?
    let onSave: (_ name: String, _ symbolName: String, _ tintColorHex: String) -> Void

    @State private var name: String = ""
    @State private var symbolName: String = "tag"
    @State private var tintColorHex: String = "#007AFF"

    var body: some View {
        NavigationStack {
            Form {
                Section(L("settings.category_details")) {
                    TextField(L("product.category"), text: $name)

                    CategoryIconPicker(selection: $symbolName)
                    CategoryColorPicker(selection: $tintColorHex)
                }
            }
            .navigationTitle(category == nil ? L("settings.add_category") : L("settings.edit_category"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        onSave(name, symbolName, tintColorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.displayName
                    symbolName = category.symbolName
                    tintColorHex = category.tintColorHex
                }
            }
        }
    }
}

private struct CategoryIconPicker: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 36), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryDefaults.iconChoices, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    Group {
                        if symbol.isLikelyEmojiIcon {
                            Text(symbol)
                                .font(.title3)
                        } else {
                            Image(systemName: symbol)
                                .font(.title3)
                        }
                    }
                        .foregroundStyle(selection == symbol ? .blue : .secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection == symbol ? Color.blue.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CategoryColorPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("settings.category_color"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CategoryDefaults.colorChoices) { option in
                        Button {
                            selection = option.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex) ?? .blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(selection == option.hex ? Color.primary : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class CoreDataCategoryManagementViewModel: ObservableObject {
    @Published var categories: [CoreDataCategory] = []
    @Published var rules: [CoreDataCategoryRuleEntry] = []
    @Published var error: String?

    private let repository = CoreDataCategoryRepository()
    private let ruleRepository = CoreDataCategoryRuleRepository()

    func load() {
        do {
            categories = try repository.fetchCategories()
            rules = try ruleRepository.fetchRules()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rule(for key: String) -> CoreDataCategoryRuleEntry? {
        rules.first(where: { $0.categoryRawValue == key })
    }

    func toggleTracking(for key: String) {
        guard let rule = rule(for: key) else { return }
        do {
            try ruleRepository.upsertRule(
                categoryKey: key,
                defaultAfterOpeningDays: rule.defaultAfterOpeningDays,
                isExpiryTrackingEnabled: !rule.isExpiryTrackingEnabled
            )
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveCategory(_ category: CoreDataCategory?, name: String, symbolName: String, tintColorHex: String) {
        do {
            if let category {
                try repository.updateCategory(id: category.id, name: name, symbolName: symbolName, tintColorHex: tintColorHex)
            } else {
                try repository.addCategory(name: name, symbolName: symbolName, tintColorHex: tintColorHex)
            }
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCategory(_ category: CoreDataCategory) {
        do {
            try repository.deleteCategory(id: category.id)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CoreDataCategoryManagementView: View {
    @StateObject private var vm = CoreDataCategoryManagementViewModel()
    @State private var editorState: CoreDataCategoryEditorState?
    @State private var categoryToDelete: CoreDataCategory?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text(L("settings.category_link_info"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.06))
                    .padding(.vertical, 4)
            )

            if vm.categories.isEmpty {
                Text(L("settings.no_categories"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.categories) { category in
                    HStack(spacing: 12) {
                        Button {
                            editorState = CoreDataCategoryEditorState(category: category)
                        } label: {
                            HStack(spacing: 12) {
                                CategorySymbolView(
                                    symbolName: category.symbolName,
                                    tint: category.tintColor
                                )
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let rule = vm.rule(for: category.key) {
                            Button {
                                vm.toggleTracking(for: category.key)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: rule.isExpiryTrackingEnabled ? "link" : "link.slash")
                                    Text(rule.isExpiryTrackingEnabled ? L("settings.expiry_enabled") : L("settings.expiry_disabled"))
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(rule.isExpiryTrackingEnabled ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                                .foregroundStyle(rule.isExpiryTrackingEnabled ? Color.green : Color.secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if category.key != "other" {
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("settings.manage_categories"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorState = CoreDataCategoryEditorState(category: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(
            L("settings.delete_category_title"),
            isPresented: $showDeleteConfirm,
            presenting: categoryToDelete
        ) { category in
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) {
                vm.deleteCategory(category)
            }
        } message: { category in
            Text(String(format: L("settings.delete_category_message"), category.displayName))
        }
        .alert("Core Data", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(vm.error ?? "")
        }
        .sheet(item: $editorState) { state in
            CoreDataCategoryEditorView(
                category: state.category,
                onSave: { name, symbolName, tintColorHex in
                    vm.saveCategory(state.category, name: name, symbolName: symbolName, tintColorHex: tintColorHex)
                }
            )
        }
        .task { vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
            vm.load()
        }
    }
}

private struct CoreDataCategoryEditorState: Identifiable {
    let id = UUID()
    let category: CoreDataCategory?
}

private struct CoreDataCategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: CoreDataCategory?
    let onSave: (_ name: String, _ symbolName: String, _ tintColorHex: String) -> Void

    @State private var name: String = ""
    @State private var symbolName: String = "tag"
    @State private var tintColorHex: String = "#007AFF"

    var body: some View {
        NavigationStack {
            Form {
                Section(L("settings.category_details")) {
                    TextField(L("product.category"), text: $name)
                    CategoryIconPicker(selection: $symbolName)
                    CategoryColorPicker(selection: $tintColorHex)
                }
            }
            .navigationTitle(category == nil ? L("settings.add_category") : L("settings.edit_category"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        onSave(name, symbolName, tintColorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.displayName
                    symbolName = category.symbolName
                    tintColorHex = category.tintColorHex
                }
            }
        }
    }
}

@MainActor
final class CoreDataCategoryRulesViewModel: ObservableObject {
    @Published var categories: [CoreDataCategory] = []
    @Published var rules: [CoreDataCategoryRuleEntry] = []
    @Published var error: String?

    private let categoryRepository = CoreDataCategoryRepository()
    private let ruleRepository = CoreDataCategoryRuleRepository()

    func load() {
        do {
            categories = try categoryRepository.fetchCategories()
            rules = try ruleRepository.fetchRules()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rule(for key: String) -> CoreDataCategoryRuleEntry? {
        rules.first(where: { $0.categoryRawValue == key })
    }

    func updateRule(categoryKey: String, defaultAfterOpeningDays: Int, isExpiryTrackingEnabled: Bool) {
        do {
            try ruleRepository.upsertRule(
                categoryKey: categoryKey,
                defaultAfterOpeningDays: defaultAfterOpeningDays,
                isExpiryTrackingEnabled: isExpiryTrackingEnabled
            )
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CoreDataCategoryRuleDurationView: View {
    @StateObject private var vm = CoreDataCategoryRulesViewModel()

    var body: some View {
        List {
            ForEach(vm.categories) { category in
                if let rule = vm.rule(for: category.key) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                CategorySymbolView(
                                    symbolName: category.symbolName,
                                    tint: category.tintColor
                                )
                                Text(category.displayName)
                            }
                            Toggle(L("settings.expiry_link"), isOn: Binding(
                                get: { rule.isExpiryTrackingEnabled },
                                set: { newValue in
                                    vm.updateRule(
                                        categoryKey: category.key,
                                        defaultAfterOpeningDays: rule.defaultAfterOpeningDays,
                                        isExpiryTrackingEnabled: newValue
                                    )
                                }
                            ))
                            .font(.caption)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                vm.updateRule(
                                    categoryKey: category.key,
                                    defaultAfterOpeningDays: max(1, rule.defaultAfterOpeningDays - 1),
                                    isExpiryTrackingEnabled: rule.isExpiryTrackingEnabled
                                )
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.bordered)

                            Text("\(rule.defaultAfterOpeningDays)d")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 44)

                            Button {
                                vm.updateRule(
                                    categoryKey: category.key,
                                    defaultAfterOpeningDays: min(90, rule.defaultAfterOpeningDays + 1),
                                    isExpiryTrackingEnabled: rule.isExpiryTrackingEnabled
                                )
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle(L("settings.manage_category_rules"))
        .alert("Core Data", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(vm.error ?? "")
        }
        .task { vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .coreDataActiveListDidChange)) { _ in
            vm.load()
        }
    }
}
