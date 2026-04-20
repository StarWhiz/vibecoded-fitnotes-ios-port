//
//  RoutineSectionExerciseSet.swift
//  FitNotes iOS
//
//  RoutineSectionExerciseSet model as defined in technical_architecture.md section 4.13
//  Maps to SQLite `RoutineSectionExerciseSet` table (planned sets in a routine)
//

import Foundation
import SwiftData

@Model final class RoutineSectionExerciseSet {
    var weightKg: Double
    var reps: Int
    var weightUnitRaw: Int
    var distanceMetres: Double
    var durationSeconds: Int
    var sortOrder: Int
    var legacyID: Int

    var sectionExercise: RoutineSectionExercise?

    // Back-link: which live entries originated from this planned set
    @Relationship(deleteRule: .nullify, inverse: \TrainingEntry.routineSet)
    var loggedEntries: [TrainingEntry] = []

    init(weightKg: Double = 0, reps: Int = 0, weightUnitRaw: Int = 0,
         distanceMetres: Double = 0, durationSeconds: Int = 0,
         sortOrder: Int = 0, legacyID: Int = 0) {
        self.weightKg         = weightKg
        self.reps             = reps
        self.weightUnitRaw    = weightUnitRaw
        self.distanceMetres   = distanceMetres
        self.durationSeconds  = durationSeconds
        self.sortOrder        = sortOrder
        self.legacyID         = legacyID
    }
}