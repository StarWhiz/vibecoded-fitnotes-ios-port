//
//  RoutineSection.swift
//  FitNotes iOS
//
//  RoutineSection model as defined in technical_architecture.md section 4.13
//  Maps to SQLite `RoutineSection` table (e.g., "Day A", "Day B")
//

import Foundation
import SwiftData

@Model final class RoutineSection {
    var name: String
    var sortOrder: Int
    var legacyID: Int

    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineSectionExercise.section)
    var exercises: [RoutineSectionExercise] = []

    init(name: String, sortOrder: Int = 0, legacyID: Int = 0) {
        self.name      = name
        self.sortOrder = sortOrder
        self.legacyID  = legacyID
    }
}