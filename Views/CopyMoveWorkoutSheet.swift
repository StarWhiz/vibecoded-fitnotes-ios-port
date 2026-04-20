//
//  CopyMoveWorkoutSheet.swift
//  FitNotes iOS
//
//  Copy/Move workout sheet (product_roadmap.md 1.26).
//  Allows selecting exercises/sets to copy or move to a target date.
//  Copy duplicates rows; Move changes the date on existing rows.
//

import SwiftUI
import SwiftData

struct CopyMoveWorkoutSheet: View {
    enum Mode: String {
        case copy = "Copy"
        case move = "Move"
    }

    let mode: Mode

    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var targetDate = Date.now
    @State private var selectedSessions: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Target Date") {
                    DatePicker(
                        "\(mode.rawValue) to",
                        selection: $targetDate,
                        displayedComponents: .date
                    )
                }

                Section("Select Exercises") {
                    ForEach(workoutStore.sessions) { session in
                        Button {
                            if selectedSessions.contains(session.id) {
                                selectedSessions.remove(session.id)
                            } else {
                                selectedSessions.insert(session.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedSessions.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSessions.contains(session.id) ? .blue : .secondary)
                                VStack(alignment: .leading) {
                                    Text(session.exercise.name)
                                        .foregroundStyle(.primary)
                                    Text("\(session.sets.count) sets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        // Select all
                        selectedSessions = Set(workoutStore.sessions.map(\.id))
                    } label: {
                        Text("Select All")
                    }
                }

                Section {
                    Button {
                        performAction()
                        dismiss()
                    } label: {
                        Label("\(mode.rawValue) \(selectedSessions.count) exercise(s)", systemImage: mode == .copy ? "doc.on.doc" : "arrow.right.doc.on.clipboard")
                    }
                    .disabled(selectedSessions.isEmpty)
                }
            }
            .navigationTitle("\(mode.rawValue) Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Default: select all
                selectedSessions = Set(workoutStore.sessions.map(\.id))
                targetDate = Calendar.current.date(byAdding: .day, value: 1, to: workoutStore.date) ?? .now
            }
        }
    }

    private func performAction() {
        let target = Calendar.current.startOfDay(for: targetDate)
        let sessionsToProcess = workoutStore.sessions.filter { selectedSessions.contains($0.id) }

        switch mode {
        case .copy:
            for session in sessionsToProcess {
                for entry in session.sets {
                    let copy = TrainingEntry(
                        date: target,
                        weightKg: entry.weightKg,
                        reps: entry.reps,
                        weightUnitRaw: entry.weightUnitRaw
                    )
                    copy.distanceMetres = entry.distanceMetres
                    copy.durationSeconds = entry.durationSeconds
                    copy.sortOrder = entry.sortOrder
                    copy.exercise = entry.exercise
                    context.insert(copy)
                }
            }

        case .move:
            for session in sessionsToProcess {
                for entry in session.sets {
                    entry.date = target
                }
            }
        }

        try? context.save()

        // Reload the store to reflect changes
        try? workoutStore.load(for: workoutStore.date, context: context)
    }
}
