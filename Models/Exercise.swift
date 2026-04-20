//
//  Exercise.swift
//  FitNotes iOS
//
//  Exercise model as defined in technical_architecture.md section 4.3
//  Maps to SQLite `exercise` table
//

import Foundation
import SwiftData

@Model final class Exercise {
    var name: String
    var exerciseTypeRaw: Int         // ExerciseType.rawValue
    var notes: String?
    var weightIncrementKg: Double?   // per-exercise override (legacy: kg × 1000 → divide on import)
    var defaultGraphID: Int?         // which graph metric is default
    var defaultRestTimeSeconds: Int? // per-exercise rest override
    var weightUnitRaw: Int           // WeightUnit.rawValue
    var isFavourite: Bool            // exercise.is_favourite
    var legacyID: Int

    var category: WorkoutCategory?

    @Relationship(deleteRule: .cascade, inverse: \TrainingEntry.exercise)
    var trainingEntries: [TrainingEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.exercise)
    var goals: [Goal] = []

    @Relationship(deleteRule: .cascade, inverse: \ExerciseGraphFavourite.exercise)
    var graphFavourites: [ExerciseGraphFavourite] = []

    @Relationship(deleteRule: .cascade, inverse: \RepMaxGridFavourite.primaryExercise)
    var repMaxGridFavourites: [RepMaxGridFavourite] = []

    // MARK: - Computed
    var exerciseType: ExerciseType { ExerciseType(rawValue: exerciseTypeRaw) }
    var weightUnit: WeightUnit     { WeightUnit(rawValue: weightUnitRaw) ?? .kilograms }

    init(name: String, exerciseTypeRaw: Int = 0, weightUnitRaw: Int = 0,
         isFavourite: Bool = false, legacyID: Int = 0) {
        self.name            = name
        self.exerciseTypeRaw = exerciseTypeRaw
        self.weightUnitRaw   = weightUnitRaw
        self.isFavourite     = isFavourite
        self.legacyID        = legacyID
    }
}