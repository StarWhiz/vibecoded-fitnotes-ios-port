//
//  ExerciseGraphFavourite.swift
//  FitNotes iOS
//
//  ExerciseGraphFavourite model as defined in technical_architecture.md section 4.14
//  Maps to SQLite `ExerciseGraphFavourite` table
//

import Foundation
import SwiftData

@Model final class ExerciseGraphFavourite {
    var graphMetricRaw: Int   // which graph metric is pinned
    var legacyID: Int

    var exercise: Exercise?

    init(graphMetricRaw: Int = 0, legacyID: Int = 0) {
        self.graphMetricRaw = graphMetricRaw
        self.legacyID       = legacyID
    }
}