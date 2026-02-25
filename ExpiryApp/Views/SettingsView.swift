import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CategoryRule.categoryRawValue) private var rules: [CategoryRule]
    @Query private var settingsList: [UserSettings]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsList.first {
                    settingsForm(settings: settings)
                } else {
                    ProgressView()
                        .task {
                            SeedService.seedIfNeeded(context: modelContext)
                        }
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func settingsForm(settings: UserSettings) -> some View {
        Form {
            Section(NSLocalizedString("settings.section.reminders", comment: "")) {
                Stepper(value: Binding(
                    get: { settings.reminderLookaheadDays },
                    set: { settings.reminderLookaheadDays = $0; try? modelContext.save() }
                ), in: 1...14) {
                    let format = NSLocalizedString("settings.lookahead_days", comment: "")
                    Text(String(format: format, settings.reminderLookaheadDays))
                }

                DatePicker(
                    NSLocalizedString("settings.digest_time", comment: ""),
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
            }

            Section(NSLocalizedString("settings.section.rules", comment: "")) {
                ForEach(rules) { rule in
                    HStack {
                        Text(rule.category.displayName)
                        Spacer()
                        Stepper(value: Binding(
                            get: { rule.defaultAfterOpeningDays },
                            set: { rule.defaultAfterOpeningDays = $0; try? modelContext.save() }
                        ), in: 1...90) {
                            Text("\(rule.defaultAfterOpeningDays)d")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }
}
