//
//  RepMaxGridFavourite.swift
//  FitNotes iOS
//
//  RepMaxGridFavourite model as defined in technical_architecture.md section 4.14
//  Maps to SQLite `RepMaxGridFavourite` table (schema partially documented; stored defensively)
//

import Foundation
import SwiftData

@Model final class RepMaxGridFavourite {
    var primaryExerciseLegacyID: Int    // stored for post-import resolution
    var secondaryExerciseLegacyID: Int  // 0 if single-exercise grid
    var legacyID: Int

    var primaryExercise: Exercise?
    var secondaryExercise: Exercise?

    init(primaryExerciseLegacyID: Int = 0, secondaryExerciseLegacyID: Int = 0,
         legacyID: Int = 0) {
        self.primaryExerciseLegacyID   = primaryExerciseLegacyID
        self.secondaryExerciseLegacyID = secondaryExerciseLegacyID
        self.legacyID                  = legacyID
    }
}