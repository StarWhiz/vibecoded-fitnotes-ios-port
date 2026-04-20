//
//  WorkoutGroup.swift
//  FitNotes iOS
//
//  WorkoutGroup model as defined in technical_architecture.md section 4.7
//  Maps to SQLite `WorkoutGroup` table (groups exercises into a superset/circuit for a given day)
//

import Foundation
import SwiftData
import SwiftUI

@Model final class WorkoutGroup {
    var name: String?
    var colourARGB: Int32   // Android signed ARGB — same decoding as WorkoutCategory.color
    var date: Date
    var legacyID: Int

    @Relationship(deleteRule: .nullify, inverse: \TrainingEntry.workoutGroup)
    var entries: [TrainingEntry] = []

    var color: Color {
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(name: String? = nil, colourARGB: Int32, date: Date, legacyID: Int = 0) {
        self.name       = name
        self.colourARGB = colourARGB
        self.date       = date
        self.legacyID   = legacyID
    }
}