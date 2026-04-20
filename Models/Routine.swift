//
//  Routine.swift
//  FitNotes iOS
//
//  Routine model as defined in technical_architecture.md section 4.13
//  Maps to SQLite `Routine` table (top of the routine hierarchy)
//

import Foundation
import SwiftData

@Model final class Routine {
    var name: String
    var legacyID: Int

    @Relationship(deleteRule: .cascade, inverse: \RoutineSection.routine)
    var sections: [RoutineSection] = []

    init(name: String, legacyID: Int = 0) {
        self.name     = name
        self.legacyID = legacyID
    }
}