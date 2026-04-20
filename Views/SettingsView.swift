//
//  SettingsView.swift
//  FitNotes iOS
//
//  Settings screen (product_roadmap.md 1.24, 1.25).
//  Global app configuration, data management, and navigation
//  to category/exercise management.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @State private var showRecalculatePRs = false
    @State private var showDeleteHistory = false
    @State private var showImportBackup = false
    @State private var isRecalculating = false

    var body: some View {
        @Bindable var settings = settingsStore

        List {
            // Units
            Section("Units") {
                Toggle("Imperial (lbs / inches)", isOn: $settings.isImperial)

                HStack {
                    Text("Default Weight Increment")
                    Spacer()
                    Text("\(formatWeight(settingsStore.display(kg: settingsStore.defaultWeightIncrementKg))) \(settingsStore.weightSymbol)")
                        .foregroundStyle(.secondary)
                }

                Picker("First Day of Week", selection: $settings.firstDayOfWeek) {
                    Text("Sunday").tag(0)
                    Text("Monday").tag(1)
                }
            }

            // Workout Behavior
            Section("Workout Behavior") {
                Toggle("Track Personal Records", isOn: $settings.trackPersonalRecords)
                Toggle("Mark Sets Complete", isOn: $settings.markSetsComplete)
                Toggle("Auto-Select Next Set", isOn: $settings.autoSelectNextSet)
            }

            // Rest Timer
            Section("Rest Timer") {
                Stepper(value: $settings.restTimerSeconds, in: 10...600, step: 10) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(settingsStore.restTimerSeconds)s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Toggle("Auto-Start After Save", isOn: $settings.restTimerAutoStart)
            }

            // Appearance
            Section("Appearance") {
                Picker("Theme", selection: $settings.appThemeID) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
            }

            // Manage
            Section("Manage") {
                NavigationLink {
                    CategoryManagementView()
                } label: {
                    Label("Categories", systemImage: "folder.fill")
                }

                NavigationLink {
                    ExerciseManagementView()
                } label: {
                    Label("Exercises", systemImage: "dumbbell.fill")
                }

                NavigationLink {
                    RoutineListView()
                } label: {
                    Label("Routines", systemImage: "list.bullet.rectangle")
                }
            }

            // Data
            Section("Data") {
                Button {
                    showRecalculatePRs = true
                } label: {
                    HStack {
                        Label("Recalculate Personal Records", systemImage: "arrow.clockwise")
                        if isRecalculating {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRecalculating)

                Button {
                    showImportBackup = true
                } label: {
                    Label("Import Backup", systemImage: "square.and.arrow.down")
                }

                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteHistory = true
                } label: {
                    Label("Delete Workout History...", systemImage: "trash")
                }
            }

            // About
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Data", value: "FitNotes iOS")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .alert("Recalculate PRs?", isPresented: $showRecalculatePRs) {
            Button("Cancel", role: .cancel) { }
            Button("Recalculate") {
                recalculatePRs()
            }
        } message: {
            Text("This will reprocess all workout history to recalculate personal record flags. This may take a moment.")
        }
        .alert("Delete History", isPresented: $showDeleteHistory) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                // Intentionally left as confirmation only — full implementation would
                // need date range / exercise filters from a dedicated sheet
            }
        } message: {
            Text("This will permanently delete workout history. This cannot be undone.")
        }
    }

    private func recalculatePRs() {
        isRecalculating = true
        Task {
            let descriptor = FetchDescriptor<Exercise>()
            let exercises = (try? context.fetch(descriptor)) ?? []

            for exercise in exercises {
                let sorted = exercise.trainingEntries.sorted { $0.date < $1.date }
                let results = PRCalculator.recalculateAll(entries: sorted)
                for (entry, isRecord, isFirst) in results {
                    entry.isPersonalRecord = isRecord
                    entry.isPersonalRecordFirst = isFirst
                }
            }
            try? context.save()
            isRecalculating = false
        }
    }

    private func exportCSV() {
        // CSV export would generate a file and present a share sheet
        // Full implementation depends on platform file APIs
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
