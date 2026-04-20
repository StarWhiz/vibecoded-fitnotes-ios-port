//
//  WorkoutComment.swift
//  FitNotes iOS
//
//  WorkoutComment model as defined in technical_architecture.md section 4.6
//  Maps to SQLite `WorkoutComment` table (free-text note for an entire training day)
//

import Foundation
import SwiftData

@Model final class WorkoutComment {
    var date: Date   // one comment per date
    var text: String
    var legacyID: Int

    init(date: Date, text: String, legacyID: Int = 0) {
        self.date     = date
        self.text     = text
        self.legacyID = legacyID
    }
}