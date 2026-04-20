//
//  WorkoutDetailView.swift
//  FitNotes iOS
//
//  Workout detail popup for a specific date (product_roadmap.md 1.22).
//  Shows all exercises and sets for that day, workout comment,
//  timing info, and allows navigation to exercise overview.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let date: Date

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [TrainingEntry] = []
    @State private var workoutComment: WorkoutComment?
    @State private var workoutSession: WorkoutSession?
    @State private var selectedExercise: Exercise?

    private var groupedByExercise: [(Exercise, [TrainingEntry])] {
        var map: [PersistentIdentifier: (Exercise, [TrainingEntry])] = [:]
        var order: [PersistentIdentifier] = []

        for entry in entries {
            guard let exercise = entry.exercise else { continue }
            let id = exercise.persistentModelID
            if map[id] != nil {
                map[id]!.1.append(entry)
            } else {
                order.append(id)
                map[id] = (exercise, [entry])
            }
        }
        return order.compactMap { map[$0] }
    }

    var body: some View {
        NavigationStack {
            List {
                // Workout header
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(date, format: .dateTime.weekday(.wide).month().day().year())
                            .font(.headline)

                        HStack(spacing: 16) {
                            Label("\(groupedByExercise.count) exercises", systemImage: "dumbbell")
                            Label("\(entries.count) sets", systemImage: "list.bullet")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let session = workoutSession, let duration = session.duration {
                            Label(formatDuration(duration), systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        let totalVol = settingsStore.display(kg: entries.reduce(0) { $0 + $1.volume })
                        if totalVol > 0 {
                            Label("\(String(format: "%.0f", totalVol)) \(settingsStore.weightSymbol) total volume", systemImage: "scalemass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Workout comment
                if let comment = workoutComment {
                    Section("Workout Comment") {
                        Text(comment.text)
                            .font(.subheadline)
                    }
                }

                // Exercises
                ForEach(groupedByExercise, id: \.0.persistentModelID) { exercise, sets in
                    Section {
                        Button {
                            selectedExercise = exercise
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    if let cat = exercise.category {
                                        Circle()
                                            .fill(cat.color)
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(exercise.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { idx, entry in
                                    HStack(spacing: 8) {
                                        Text("\(idx + 1).")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20, alignment: .leading)

                                        setDescription(entry)

                                        Spacer()

                                        if entry.isPersonalRecord {
                                            Image(systemName: "trophy.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.yellow)
                                        }
                                        if entry.comment != nil {
                                            Image(systemName: "text.bubble.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Workout Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseOverviewView(exercise: exercise)
            }
            .task { loadData() }
        }
    }

    @ViewBuilder
    private func setDescription(_ entry: TrainingEntry) -> some View {
        let type = entry.exercise?.exerciseType ?? .weightReps

        switch type {
        case .weightReps:
            HStack(spacing: 4) {
                Text(formatWeight(settingsStore.display(kg: entry.weightKg)))
                    .font(.caption.monospacedDigit())
                Text(settingsStore.weightSymbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(entry.reps)")
                    .font(.caption.monospacedDigit())
            }
        case .cardio:
            HStack(spacing: 8) {
                if entry.distanceMetres > 0 {
                    Text(String(format: "%.2f km", entry.distanceMetres / 1000))
                        .font(.caption.monospacedDigit())
                }
                if entry.durationSeconds > 0 {
                    Text(formatDuration(Double(entry.durationSeconds)))
                        .font(.caption.monospacedDigit())
                }
            }
        case .timed:
            Text(formatDuration(Double(entry.durationSeconds)))
                .font(.caption.monospacedDigit())
        case .unknown:
            Text("--")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadData() {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let entryDescriptor = FetchDescriptor<TrainingEntry>(
            predicate: #Predicate<TrainingEntry> { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        entries = (try? context.fetch(entryDescriptor)) ?? []

        let commentDescriptor = FetchDescriptor<WorkoutComment>(
            predicate: #Predicate<WorkoutComment> { $0.date >= start && $0.date < end }
        )
        workoutComment = try? context.fetch(commentDescriptor).first

        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.date >= start && $0.date < end }
        )
        workoutSession = try? context.fetch(sessionDescriptor).first
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm %02ds", m, s)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
