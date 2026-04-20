//
//  RoutineListView.swift
//  FitNotes iOS
//
//  Routine management (product_roadmap.md 1.21).
//  Browse routines, view sections (days), manage exercises and planned sets.
//  "Log All" materializes routine sets into training_log.
//

import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Query(sort: \Routine.name)
    private var routines: [Routine]

    @Environment(\.modelContext) private var context

    @State private var showAddRoutine = false

    var body: some View {
        List {
            if routines.isEmpty {
                ContentUnavailableView {
                    Label("No Routines", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Create workout templates to quickly log planned sessions.")
                }
            } else {
                ForEach(routines) { routine in
                    NavigationLink {
                        RoutineDetailView(routine: routine)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.name)
                                .font(.body.weight(.medium))
                            Text("\(routine.sections.count) day(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(routines[index])
                    }
                    try? context.save()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddRoutine = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Routine", isPresented: $showAddRoutine) {
            AddRoutineAlert()
        }
    }
}

// MARK: - Add Routine Alert

private struct AddRoutineAlert: View {
    @Environment(\.modelContext) private var context
    @State private var name = ""

    var body: some View {
        TextField("Routine Name", text: $name)
        Button("Cancel", role: .cancel) { }
        Button("Create") {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            let routine = Routine(name: name.trimmingCharacters(in: .whitespaces))
            context.insert(routine)
            try? context.save()
        }
    }
}

// MARK: - Routine Detail View

struct RoutineDetailView: View {
    @Bindable var routine: Routine

    @Environment(\.modelContext) private var context
    @Environment(ActiveWorkoutStore.self) private var workoutStore

    @State private var showAddSection = false
    @State private var showLogAll = false
    @State private var selectedSection: RoutineSection?

    private var sortedSections: [RoutineSection] {
        routine.sections.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            ForEach(sortedSections) { section in
                Section {
                    let sortedExercises = section.exercises.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(sortedExercises) { sectionExercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sectionExercise.exercise?.name ?? "Unknown")
                                .font(.subheadline)

                            let sets = sectionExercise.plannedSets.sorted { $0.sortOrder < $1.sortOrder }
                            ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { idx, plannedSet in
                                HStack(spacing: 8) {
                                    Text("Set \(idx + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, alignment: .leading)

                                    if plannedSet.weightKg > 0 || plannedSet.reps > 0 {
                                        Text("\(formatWeight(plannedSet.weightKg * 2.20462)) lbs x \(plannedSet.reps)")
                                            .font(.caption.monospacedDigit())
                                    } else {
                                        Text("Auto-fill from last session")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if sets.isEmpty {
                                Text("No planned sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Log section button
                    Button {
                        selectedSection = section
                        showLogAll = true
                    } label: {
                        Label("Log This Day", systemImage: "play.circle.fill")
                    }
                } header: {
                    Text(section.name)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(routine.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddSection = true
                    } label: {
                        Label("Add Day", systemImage: "plus")
                    }
                    Button {
                        duplicateRoutine()
                    } label: {
                        Label("Duplicate Routine", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("New Day", isPresented: $showAddSection) {
            AddSectionAlert(routine: routine)
        }
        .confirmationDialog("Log Routine", isPresented: $showLogAll, titleVisibility: .visible) {
            Button("Log All Sets") {
                if let section = selectedSection {
                    logSection(section)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let section = selectedSection {
                Text("Log all planned sets from \(section.name) to today's workout?")
            }
        }
    }

    private func logSection(_ section: RoutineSection) {
        let today = Calendar.current.startOfDay(for: .now)
        let sortedExercises = section.exercises.sorted { $0.sortOrder < $1.sortOrder }

        for sectionExercise in sortedExercises {
            guard let exercise = sectionExercise.exercise else { continue }

            workoutStore.addExercise(exercise, context: context)

            let plannedSets = sectionExercise.plannedSets.sorted { $0.sortOrder < $1.sortOrder }
            for plannedSet in plannedSets {
                let entry = TrainingEntry(date: today)
                entry.exercise = exercise

                if plannedSet.weightKg > 0 || plannedSet.reps > 0 {
                    entry.weightKg = plannedSet.weightKg
                    entry.reps = plannedSet.reps
                    entry.distanceMetres = plannedSet.distanceMetres
                    entry.durationSeconds = plannedSet.durationSeconds
                } else {
                    // Auto-fill from last session
                    if let lastEntry = exercise.trainingEntries
                        .filter({ !Calendar.current.isDate($0.date, inSameDayAs: today) })
                        .sorted(by: { $0.date > $1.date })
                        .first {
                        entry.weightKg = lastEntry.weightKg
                        entry.reps = lastEntry.reps
                    }
                }

                entry.weightUnitRaw = plannedSet.weightUnitRaw
                entry.routineSet = plannedSet
                entry.routineSetLegacyID = plannedSet.legacyID

                context.insert(entry)
            }
        }

        try? context.save()
        try? workoutStore.load(for: today, context: context)
    }

    private func duplicateRoutine() {
        let copy = Routine(name: "\(routine.name) (Copy)")

        for section in routine.sections {
            let sectionCopy = RoutineSection(name: section.name, sortOrder: section.sortOrder)
            sectionCopy.routine = copy

            for sExercise in section.exercises {
                let exCopy = RoutineSectionExercise(
                    populateSetsTypeRaw: sExercise.populateSetsTypeRaw,
                    sortOrder: sExercise.sortOrder
                )
                exCopy.exercise = sExercise.exercise
                exCopy.section = sectionCopy

                for pSet in sExercise.plannedSets {
                    let setCopy = RoutineSectionExerciseSet()
                    setCopy.weightKg = pSet.weightKg
                    setCopy.reps = pSet.reps
                    setCopy.weightUnitRaw = pSet.weightUnitRaw
                    setCopy.distanceMetres = pSet.distanceMetres
                    setCopy.durationSeconds = pSet.durationSeconds
                    setCopy.sortOrder = pSet.sortOrder
                    setCopy.sectionExercise = exCopy
                    context.insert(setCopy)
                }
                context.insert(exCopy)
            }
            context.insert(sectionCopy)
        }

        context.insert(copy)
        try? context.save()
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Add Section Alert

private struct AddSectionAlert: View {
    let routine: Routine
    @Environment(\.modelContext) private var context
    @State private var name = ""

    var body: some View {
        TextField("Day Name (e.g., Day A)", text: $name)
        Button("Cancel", role: .cancel) { }
        Button("Add") {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            let section = RoutineSection(
                name: name.trimmingCharacters(in: .whitespaces),
                sortOrder: routine.sections.count
            )
            section.routine = routine
            context.insert(section)
            try? context.save()
        }
    }
}
