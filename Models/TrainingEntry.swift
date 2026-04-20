//
//  TrainingEntry.swift
//  FitNotes iOS
//
//  TrainingEntry model as defined in technical_architecture.md section 4.4
//  Maps to SQLite `training_log` table (each row is one logged set)
//

import Foundation
import SwiftData

@Model final class TrainingEntry {
    var date: Date               // Converted from 'YYYY-MM-DD' text; time component = midnight UTC
    var weightKg: Double         // ALWAYS kg. Legacy: metric_weight REAL stored as kg
    var reps: Int
    var weightUnitRaw: Int       // Display unit for this set (0=kg, 2=lbs)
    var routineSetLegacyID: Int  // 0 = ad-hoc; non-zero links to RoutineSectionExerciseSet
    var timerAutoStart: Bool
    var isPersonalRecord: Bool
    var isPersonalRecordFirst: Bool
    var isComplete: Bool
    var isPendingUpdate: Bool
    var distanceMetres: Double   // cardio: metres. Legacy stores metres × 1000 — divide on import
    var durationSeconds: Int     // cardio / timed exercises
    var sortOrder: Int           // iOS addition: explicit display order of exercises within a day
    var legacyID: Int

    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetComment.trainingEntry)
    var comment: SetComment?

    var workoutGroup: WorkoutGroup?

    var routineSet: RoutineSectionExerciseSet?

    // MARK: - Computed display helpers
    var weightLbs: Double { weightKg * 2.20462 }

    /// Returns the weight in the user's preferred unit given an AppSettings reference.
    func displayWeight(isImperial: Bool) -> Double {
        isImperial ? weightLbs : weightKg
    }

    var volume: Double { weightKg * Double(reps) }  // in kg; convert at display site

    var estimatedOneRepMaxKg: Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        if reps == 1 { return weightKg }
        // Epley formula: w × (1 + r/30)
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    init(date: Date, weightKg: Double = 0, reps: Int = 0,
         weightUnitRaw: Int = 2, legacyID: Int = 0) {
        self.date            = date
        self.weightKg        = weightKg
        self.reps            = reps
        self.weightUnitRaw   = weightUnitRaw
        self.routineSetLegacyID = 0
        self.timerAutoStart  = false
        self.isPersonalRecord      = false
        self.isPersonalRecordFirst = false
        self.isComplete      = false
        self.isPendingUpdate = false
        self.distanceMetres  = 0
        self.durationSeconds = 0
        self.sortOrder       = 0
        self.legacyID        = legacyID
    }
}