//
//  ExerciseStatusIntent.swift
//  FitNotes iOS
//
//  Siri Shortcut: "How's my bench press?"
//  Reads back the last session's sets for a given exercise. product_roadmap.md section 3.5.
//

import AppIntents
import Foundation
import SwiftData

struct ExerciseStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Exercise Status"
    static var description = IntentDescription("Check how your last session went for an exercise.")
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

        // Get last session's entries (most recent date with data for this exercise)
        let exerciseID = exercise.persistentModelID
        let entryDescriptor = FetchDescriptor<TrainingEntry>(
            predicate: #Predicate<TrainingEntry> {
                $0.exercise?.persistentModelID == exerciseID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allEntries = try context.fetch(entryDescriptor)
        guard let lastDate = allEntries.first?.date else {
            return .result(dialog: "No history found for \(exercise.name).")
        }

        let dayStart = Calendar.current.startOfDay(for: lastDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let lastSessionEntries = allEntries.filter { $0.date >= dayStart && $0.date < dayEnd }

        // Determine units
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(settingsDescriptor).first ?? AppSettings()
        let unitSymbol = settings.isImperial ? "lbs" : "kg"

        // Build summary
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let setDescriptions = lastSessionEntries.map { entry in
            let weight = settings.isImperial ? entry.weightLbs : entry.weightKg
            let pr = entry.isPersonalRecord ? " (PR!)" : ""
            return "\(Int(weight)) \(unitSymbol) x \(entry.reps)\(pr)"
        }

        let dateStr = dateFormatter.string(from: dayStart)
        let summary = setDescriptions.joined(separator: ", ")

        return .result(
            dialog: "Your last \(exercise.name) session was on \(dateStr): \(summary)."
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("How's my \(\.$exerciseName)?")
    }
}
