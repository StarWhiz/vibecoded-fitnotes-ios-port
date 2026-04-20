//
//  OneRMIntent.swift
//  FitNotes iOS
//
//  Siri Shortcut: "What's my 1RM?"
//  Reads back the estimated 1RM for an exercise. product_roadmap.md section 3.5.
//

import AppIntents
import Foundation
import SwiftData

struct OneRMIntent: AppIntent {
    static var title: LocalizedStringResource = "Check 1RM"
    static var description = IntentDescription("Check your estimated one-rep max for an exercise.")
    static var openAppWhenRun = false

    @Parameter(title: "Exercise", optionsProvider: ExerciseOptionsProvider())
    var exerciseName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try AppGroup.makeModelContainer()
        let context = ModelContext(container)

        // Find the exercise
        let exerciseDescriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        let exercises = try context.fetch(exerciseDescriptor)
        guard let exercise = exercises.first(where: {
            $0.name.localizedCaseInsensitiveContains(exerciseName)
        }) else {
            return .result(dialog: "I couldn't find an exercise matching \"\(exerciseName)\".")
        }

        // Find the best estimated 1RM across all entries
        let exerciseID = exercise.persistentModelID
        let entryDescriptor = FetchDescriptor<TrainingEntry>(
            predicate: #Predicate<TrainingEntry> {
                $0.exercise?.persistentModelID == exerciseID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entries = try context.fetch(entryDescriptor)

        guard !entries.isEmpty else {
            return .result(dialog: "No data found for \(exercise.name).")
        }

        // Find the entry that produces the highest estimated 1RM
        let bestEntry = entries.max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg })!
        let best1RMKg = bestEntry.estimatedOneRepMaxKg

        // Determine units
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(settingsDescriptor).first ?? AppSettings()
        let unitSymbol = settings.isImperial ? "lbs" : "kg"
        let displayWeight = settings.isImperial ? best1RMKg * 2.20462 : best1RMKg

        let sourceWeight = settings.isImperial ? bestEntry.weightLbs : bestEntry.weightKg

        return .result(
            dialog: "Your estimated 1RM for \(exercise.name) is \(Int(displayWeight)) \(unitSymbol), based on \(Int(sourceWeight)) \(unitSymbol) for \(bestEntry.reps) reps."
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("What's my 1RM for \(\.$exerciseName)?")
    }
}
