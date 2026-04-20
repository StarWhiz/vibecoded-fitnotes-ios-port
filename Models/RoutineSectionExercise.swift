//
//  RoutineSectionExercise.swift
//  FitNotes iOS
//
//  RoutineSectionExercise model as defined in technical_architecture.md section 4.13
//  Maps to SQLite `RoutineSectionExercise` table
//

import Foundation
import SwiftData

@Model final class RoutineSectionExercise {
    var populateSetsTypeRaw: Int   // 0 = use planned sets as-is
    var sortOrder: Int
    var legacyID: Int

    var section: RoutineSection?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \RoutineSectionExerciseSet.sectionExercise)
    var plannedSets: [RoutineSectionExerciseSet] = []

    init(populateSetsTypeRaw: Int = 0, sortOrder: Int = 0, legacyID: Int = 0) {
        self.populateSetsTypeRaw = populateSetsTypeRaw
        self.sortOrder           = sortOrder
        self.legacyID            = legacyID
    }
}