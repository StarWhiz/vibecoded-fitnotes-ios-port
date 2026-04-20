//
//  ExerciseOverviewView.swift
//  FitNotes iOS
//
//  Unified exercise modal with 5 tabs (product_roadmap.md 1.17):
//  History, Graph, Records, Stats, Goals.
//  Accessible from Calendar, Training History, Progress Graphs, etc.
//

import SwiftUI
import SwiftData

struct ExerciseOverviewView: View {
    let exercise: Exercise

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: OverviewTab = .history

    enum OverviewTab: String, CaseIterable {
        case history = "History"
        case graph = "Graph"
        case records = "Records"
        case stats = "Stats"
        case goals = "Goals"

        var icon: String {
            switch self {
            case .history: return "clock"
            case .graph: return "chart.xyaxis.line"
            case .records: return "trophy"
            case .stats: return "number"
            case .goals: return "target"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(OverviewTab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.blue.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Content
                switch selectedTab {
                case .history:
                    TrainingHistoryTab(exercise: exercise)
                case .graph:
                    ProgressGraphTab(exercise: exercise)
                case .records:
                    PersonalRecordsTab(exercise: exercise)
                case .stats:
                    StatisticsTab(exercise: exercise)
                case .goals:
                    GoalsTab(exercise: exercise)
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Training History Tab (1.14)

struct TrainingHistoryTab: View {
    let exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore

    private var entriesByDate: [(Date, [TrainingEntry])] {
        let entries = exercise.trainingEntries.sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            ForEach(entriesByDate, id: \.0) { date, sets in
                Section {
                    ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { idx, entry in
                        SetRowView(entry: entry, setNumber: idx + 1)
                    }

                    // Aggregates
                    if exercise.exerciseType.usesWeight {
                        let totalVol = settingsStore.display(kg: sets.reduce(0) { $0 + $1.volume })
                        let totalReps = sets.reduce(0) { $0 + $1.reps }
                        HStack {
                            Text("Total Volume: \(String(format: "%.0f", totalVol)) \(settingsStore.weightSymbol)")
                                .font(.caption)
                            Spacer()
                            Text("Total Reps: \(totalReps)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(date, format: .dateTime.weekday(.abbreviated).month().day().year())
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if entriesByDate.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("No sets logged for this exercise."))
            }
        }
    }
}

// MARK: - Progress Graph Tab (1.12)

struct ProgressGraphTab: View {
    let exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore

    @State private var metric: GraphMetric = .estimated1RM

    enum GraphMetric: String, CaseIterable {
        case estimated1RM = "Est. 1RM"
        case maxWeight = "Max Weight"
        case volume = "Volume"
        case totalReps = "Total Reps"

        var icon: String {
            switch self {
            case .estimated1RM: return "arrow.up.right"
            case .maxWeight: return "scalemass"
            case .volume: return "chart.bar"
            case .totalReps: return "number"
            }
        }
    }

    private var dataPoints: [(Date, Double)] {
        let entriesByDate = Dictionary(grouping: exercise.trainingEntries) {
            Calendar.current.startOfDay(for: $0.date)
        }
        let sorted = entriesByDate.sorted { $0.key < $1.key }

        return sorted.compactMap { date, entries in
            let value: Double
            switch metric {
            case .estimated1RM:
                value = settingsStore.display(kg: entries.map(\.estimatedOneRepMaxKg).max() ?? 0)
            case .maxWeight:
                value = settingsStore.display(kg: entries.map(\.weightKg).max() ?? 0)
            case .volume:
                value = settingsStore.display(kg: entries.reduce(0) { $0 + $1.volume })
            case .totalReps:
                value = Double(entries.reduce(0) { $0 + $1.reps })
            }
            return value > 0 ? (date, value) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Metric", selection: $metric) {
                ForEach(GraphMetric.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if dataPoints.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Log some sets to see your progress."))
            } else {
                // Simple text-based data display (Charts framework integration is a future enhancement)
                List {
                    ForEach(dataPoints.suffix(30).reversed(), id: \.0) { date, value in
                        HStack {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)

                            // Simple bar
                            GeometryReader { geo in
                                let maxVal = dataPoints.map(\.1).max() ?? 1
                                let width = geo.size.width * (value / maxVal)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.opacity(0.7))
                                    .frame(width: max(width, 2), height: 16)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }

                            Text(formatValue(value))
                                .font(.caption.monospacedDigit())
                                .frame(width: 60, alignment: .trailing)
                        }
                        .frame(height: 24)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        if metric == .totalReps { return String(format: "%.0f", v) }
        return "\(String(format: "%.0f", v)) \(settingsStore.weightSymbol)"
    }
}

// MARK: - Personal Records Tab (1.13)

struct PersonalRecordsTab: View {
    let exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore

    private var recordsByReps: [(Int, TrainingEntry)] {
        var bestAtReps: [Int: TrainingEntry] = [:]
        for entry in exercise.trainingEntries where entry.reps > 0 && entry.weightKg > 0 {
            if let existing = bestAtReps[entry.reps] {
                if entry.weightKg > existing.weightKg {
                    bestAtReps[entry.reps] = entry
                }
            } else {
                bestAtReps[entry.reps] = entry
            }
        }
        return bestAtReps.sorted { $0.key < $1.key }
    }

    private var estimatedRecords: [OneRMCalculator.RepMax] {
        guard let bestEntry = exercise.trainingEntries
            .filter({ $0.reps > 0 && $0.weightKg > 0 })
            .max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }) else { return [] }
        let displayW = settingsStore.display(kg: bestEntry.weightKg)
        return OneRMCalculator.repMaxTable(weight: displayW, reps: bestEntry.reps)
    }

    var body: some View {
        List {
            if !recordsByReps.isEmpty {
                Section("Actual Records") {
                    ForEach(recordsByReps, id: \.0) { reps, entry in
                        HStack {
                            Text("\(reps) reps")
                                .monospacedDigit()
                                .frame(width: 60, alignment: .leading)
                            Text(formatWeight(settingsStore.display(kg: entry.weightKg)))
                                .font(.body.monospacedDigit().bold())
                            Text(settingsStore.weightSymbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if entry.isPersonalRecord {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }

            if !estimatedRecords.isEmpty {
                Section("Estimated Rep Maxes") {
                    ForEach(estimatedRecords) { rm in
                        HStack {
                            Text("\(rm.reps) RM")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .leading)
                            Text(formatWeight(rm.weight))
                                .monospacedDigit()
                            Text(settingsStore.weightSymbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%.0f", rm.percentage))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if recordsByReps.isEmpty {
                ContentUnavailableView("No Records", systemImage: "trophy", description: Text("Log weight training sets to track PRs."))
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Statistics Tab (1.15)

struct StatisticsTab: View {
    let exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore

    @State private var period: StatPeriod = .all

    enum StatPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All"

        var dateOffset: DateComponents? {
            switch self {
            case .week: return DateComponents(day: -7)
            case .month: return DateComponents(month: -1)
            case .year: return DateComponents(year: -1)
            case .all: return nil
            }
        }
    }

    private var filteredEntries: [TrainingEntry] {
        guard let offset = period.dateOffset,
              let cutoff = Calendar.current.date(byAdding: offset, to: .now) else {
            return exercise.trainingEntries
        }
        return exercise.trainingEntries.filter { $0.date >= cutoff }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $period) {
                ForEach(StatPeriod.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                let entries = filteredEntries

                if entries.isEmpty {
                    ContentUnavailableView("No Data", systemImage: "chart.bar", description: Text("No sets in this time period."))
                } else {
                    Section("Summary") {
                        LabeledContent("Workouts") {
                            let dates = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
                            Text("\(dates.count)")
                        }
                        LabeledContent("Total Sets") {
                            Text("\(entries.count)")
                        }
                    }

                    if exercise.exerciseType.usesWeight {
                        Section("Weight Stats") {
                            let maxW = settingsStore.display(kg: entries.map(\.weightKg).max() ?? 0)
                            LabeledContent("Max Weight") {
                                Text("\(formatWeight(maxW)) \(settingsStore.weightSymbol)")
                            }

                            let totalVol = settingsStore.display(kg: entries.reduce(0) { $0 + $1.volume })
                            LabeledContent("Total Volume") {
                                Text("\(formatWeight(totalVol)) \(settingsStore.weightSymbol)")
                            }

                            let totalReps = entries.reduce(0) { $0 + $1.reps }
                            LabeledContent("Total Reps") {
                                Text("\(totalReps)")
                            }

                            let best1RM = settingsStore.display(kg: entries.map(\.estimatedOneRepMaxKg).max() ?? 0)
                            LabeledContent("Best Est. 1RM") {
                                Text("\(formatWeight(best1RM)) \(settingsStore.weightSymbol)")
                            }

                            if entries.count > 0 {
                                let avgW = settingsStore.display(kg: entries.reduce(0) { $0 + $1.weightKg } / Double(entries.count))
                                LabeledContent("Avg Weight") {
                                    Text("\(formatWeight(avgW)) \(settingsStore.weightSymbol)")
                                }
                            }
                        }
                    }

                    if exercise.exerciseType == .cardio {
                        Section("Cardio Stats") {
                            let totalDist = entries.reduce(0.0) { $0 + $1.distanceMetres } / 1000
                            LabeledContent("Total Distance") {
                                Text(String(format: "%.1f km", totalDist))
                            }
                            let totalTime = entries.reduce(0) { $0 + $1.durationSeconds }
                            LabeledContent("Total Time") {
                                Text(formatDuration(totalTime))
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Goals Tab (1.16)

struct GoalsTab: View {
    let exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @State private var showAddGoal = false
    @State private var newGoalValue = ""
    @State private var newGoalType: GoalType = .increase

    var body: some View {
        List {
            if exercise.goals.isEmpty {
                ContentUnavailableView("No Goals", systemImage: "target", description: Text("Set goals to track your progress."))
            } else {
                ForEach(exercise.goals) { goal in
                    HStack {
                        Image(systemName: goalIcon(goal.goalType))
                            .foregroundStyle(goalColor(goal.goalType))
                        VStack(alignment: .leading) {
                            Text("\(formatWeight(settingsStore.display(kg: goal.targetValue))) \(settingsStore.weightSymbol)")
                                .font(.body.bold())
                            Text(goal.goalType.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        // Progress indicator
                        let current = exercise.trainingEntries.map(\.estimatedOneRepMaxKg).max() ?? 0
                        let displayCurrent = settingsStore.display(kg: current)
                        let displayTarget = settingsStore.display(kg: goal.targetValue)
                        if displayTarget > 0 {
                            let pct = min(displayCurrent / displayTarget, 1.0)
                            ProgressView(value: pct)
                                .frame(width: 60)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(exercise.goals[index])
                    }
                    try? context.save()
                }
            }

            Section {
                Button {
                    showAddGoal = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert("Add Goal", isPresented: $showAddGoal) {
            TextField("Target weight (\(settingsStore.weightSymbol))", text: $newGoalValue)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                guard let value = Double(newGoalValue), value > 0 else { return }
                let goal = Goal()
                goal.goalTypeRaw = newGoalType.rawValue
                goal.targetValue = settingsStore.kg(from: value)
                goal.exercise = exercise
                context.insert(goal)
                try? context.save()
                newGoalValue = ""
            }
        }
    }

    private func goalIcon(_ type: GoalType) -> String {
        switch type {
        case .increase: return "arrow.up.circle.fill"
        case .decrease: return "arrow.down.circle.fill"
        case .specific: return "target"
        }
    }

    private func goalColor(_ type: GoalType) -> Color {
        switch type {
        case .increase: return .green
        case .decrease: return .red
        case .specific: return .blue
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

extension GoalType {
    var label: String {
        switch self {
        case .increase: return "Increase"
        case .decrease: return "Decrease"
        case .specific: return "Specific Value"
        }
    }
}
