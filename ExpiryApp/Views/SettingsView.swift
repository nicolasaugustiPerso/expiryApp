import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var settingsList: [UserSettings]

    @State private var notificationsAuthorized = false
    @State private var settingsInitFailed = false

    private let languageOptions: [(code: String, label: String)] = [
        ("system", "🌐 System"),
        ("en", "🇬🇧 English"),
        ("fr", "🇫🇷 Français")
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsList.first {
                    settingsForm(settings: settings)
                } else if settingsInitFailed {
                    VStack(spacing: 12) {
                        Text(L("settings.init_failed"))
                            .foregroundStyle(.secondary)
                        Button(L("settings.retry")) {
                            settingsInitFailed = false
                            ensureSettingsIfNeeded()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(L("settings.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) {
                        dismiss()
                    }
                }
            }
            .task {
                ensureSettingsIfNeeded()
                notificationsAuthorized = await NotificationService.notificationsAuthorized()
                if settingsList.first == nil {
                    settingsInitFailed = true
                }
            }
        }
    }

    @ViewBuilder
    private func settingsForm(settings: UserSettings) -> some View {
        Form {
            Section(L("settings.section.reminders")) {
                HStack {
                    Text(L("settings.daily_notifications"))
                    Spacer()
                    Button {
                        toggleNotifications(settings: settings)
                    } label: {
                        Text(settings.notificationsEnabled ? L("common.on") : L("common.off"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(settings.notificationsEnabled ? Color.green.opacity(0.22) : Color.red.opacity(0.22))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                DatePicker(
                    L("settings.digest_time"),
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                from: DateComponents(hour: settings.dailyDigestHour, minute: settings.dailyDigestMinute)
                            ) ?? .now
                        },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            settings.dailyDigestHour = c.hour ?? 20
                            settings.dailyDigestMinute = c.minute ?? 0
                            try? modelContext.save()
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
                                settings.reminderLookaheadDays = day
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        Text(String(settings.reminderLookaheadDays))
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
                                settings.preferredLanguageCode = option.code
                                applyLanguagePreference(code: option.code)
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        Text(languageLabel(for: settings.preferredLanguageCode))
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

            Section(L("settings.section.categories")) {
                NavigationLink(L("settings.manage_categories")) {
                    CategoryManagementView()
                }
                NavigationLink(L("settings.manage_category_rules")) {
                    CategoryRuleDurationView()
                }
            }
        }
    }

    private func toggleNotifications(settings: UserSettings) {
        Task {
            if settings.notificationsEnabled {
                settings.notificationsEnabled = false
                NotificationService.removeDailyDigest()
            } else {
                let granted = await NotificationService.requestPermission()
                notificationsAuthorized = await NotificationService.notificationsAuthorized()
                settings.notificationsEnabled = granted || notificationsAuthorized
            }
            try? modelContext.save()
        }
    }

    private func languageLabel(for code: String) -> String {
        languageOptions.first(where: { $0.code == code })?.label ?? "🌐 System"
    }

    private func applyLanguagePreference(code: String) {
        UserDefaults.standard.set(code, forKey: "app.preferred_language_code")
        UserDefaults.standard.synchronize()
    }

    private func ensureSettingsIfNeeded() {
        if settingsList.first != nil { return }

        SeedService.seedIfNeeded(context: modelContext)
        if settingsList.first != nil { return }

        modelContext.insert(UserSettings())
        do {
            try modelContext.save()
        } catch {
            settingsInitFailed = true
            print("Settings init failed: \(error)")
            return
        }

        if settingsList.first == nil {
            settingsInitFailed = true
        }
    }
}

private struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]

    @State private var ruleToDelete: CategoryRule?
    @State private var showDeleteConfirm = false
    @State private var showAddSheet = false

    var body: some View {
        List {
            if rules.isEmpty {
                Text(L("settings.no_categories"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rules) { rule in
                    HStack {
                        Text(rule.category.displayName)
                        Spacer()
                        Button(role: .destructive) {
                            ruleToDelete = rule
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L("settings.manage_categories"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(
            L("settings.delete_category_title"),
            isPresented: $showDeleteConfirm,
            presenting: ruleToDelete
        ) { rule in
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) {
                modelContext.delete(rule)
                try? modelContext.save()
            }
        } message: { rule in
            Text(String(format: L("settings.delete_category_message"), rule.category.displayName))
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                List {
                    if availableCategories.isEmpty {
                        Text(L("settings.no_category_to_add"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableCategories) { category in
                            Button {
                                let defaultDays = CategoryDefaults.afterOpeningDays[category] ?? 3
                                modelContext.insert(CategoryRule(category: category, defaultAfterOpeningDays: defaultDays))
                                try? modelContext.save()
                                showAddSheet = false
                            } label: {
                                HStack {
                                    Text(category.displayName)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(L("settings.add_category"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("common.done")) {
                            showAddSheet = false
                        }
                    }
                }
            }
        }
    }

    private var availableCategories: [ProductCategory] {
        let existing = Set(rules.map(\.category))
        return ProductCategory.allCases.filter { !existing.contains($0) }
    }
}

private struct CategoryRuleDurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]

    var body: some View {
        List {
            ForEach(rules) { rule in
                HStack {
                    Text(rule.category.displayName)
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
        .navigationTitle(L("settings.manage_category_rules"))
    }
}
