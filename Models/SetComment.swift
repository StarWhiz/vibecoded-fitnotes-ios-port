//
//  SetComment.swift
//  FitNotes iOS
//
//  SetComment model as defined in technical_architecture.md section 4.5
//  Flattened from the polymorphic SQLite `Comment` table
//

import Foundation
import SwiftData

@Model final class SetComment {
    var text: String
    var legacyID: Int

    var trainingEntry: TrainingEntry?

    init(text: String, legacyID: Int = 0) {
        self.text     = text
        self.legacyID = legacyID
    }
}