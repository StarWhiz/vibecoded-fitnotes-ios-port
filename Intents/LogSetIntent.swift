//
//  LogSetIntent.swift
//  FitNotes iOS
//
//  Siri Shortcut: "Log a set"
//  Voice-input weight + reps for the current exercise. product_roadmap.md section 3.5.
//

import AppIntents
import Foundation
import SwiftData

struct LogSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Set"
    static var description = IntentDescription(
        "Log a set with weight and reps for your current exercise."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Weight")
    var weight: Double

    @Parameter(title: "Reps")
    var reps: Int

    @Parameter(title: "Exercise", optionsProvider: ExerciseOptionsProvider())
    var exerciseName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard reps > 0 else {
            return .result(dialog: "Reps must be at least 1.")
        }
        guard weight > 0 else {
            return .result(dialog: "Weight must be greater than zero.")
        }

        let container = try AppGroup.makeModelContainer()
        let context = ModelContext(container)

        // Find the exercise
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        let exercises = try context.fetch(descriptor)

        let exercise: Exercise?
        if let name = exerciseName {
            exercise = exercises.first { $0.name.localizedCaseInsensitiveContains(name) }
        } else {
            // Fall back to most recently used exercise today
            let today = Calendar.current.startOfDay(for: .now)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let entryDescriptor = FetchDescriptor<TrainingEntry>(
                predicate: #Predicate<TrainingEntry> {
                    $0.date >= today && $0.date < tomorrow
                },
                sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
            )
            let todayEntries = try context.fetch(entryDescriptor)
            exercise = todayEntries.last?.exercise
        }

        guard let exercise else {
            return .result(dialog: "I couldn't find the exercise. Please specify which exercise to log.")
        }

        // Determine unit system from settings
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(settingsDescriptor).first ?? AppSettings()
        let weightKg = settings.isImperial ? weight / 2.20462 : weight
        let unitSymbol = settings.isImperial ? "lbs" : "kg"

        let entry = TrainingEntry(date: .now, weightKg: weightKg, reps: reps)
        entry.exercise = exercise
        entry.weightUnitRaw = settings.isImperial ? 2 : 0
        context.insert(entry)
        try context.save()

        return .result(
            dialog: "Logged \(Int(weight)) \(unitSymbol) x \(reps) reps for \(exercise.name)."
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$weight) x \(\.$reps) for \(\.$exerciseName)")
    }
}

// MARK: - Exercise options provider

struct ExerciseOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let container = try AppGroup.makeModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map(\.name)
    }
}
