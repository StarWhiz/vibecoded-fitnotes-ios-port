//
//  WorkoutCategory.swift
//  FitNotes iOS
//
//  WorkoutCategory model as defined in technical_architecture.md section 4.2
//  Maps to SQLite `Category` table (named WorkoutCategory to avoid Swift keyword conflict)
//

import Foundation
import SwiftData
import SwiftUI

@Model final class WorkoutCategory {
    var name: String
    var colourARGB: Int32    // Android signed ARGB int
    var sortOrder: Int
    var isBuiltIn: Bool      // iOS addition: prevents deletion of the 8 default categories
    var legacyID: Int        // original Category._id (used during import only)

    @Relationship(deleteRule: .nullify, inverse: \Exercise.category)
    var exercises: [Exercise] = []

    // MARK: - Computed
    var color: Color {
        // Android signed 32-bit ARGB → SwiftUI Color
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(name: String, colourARGB: Int32, sortOrder: Int, isBuiltIn: Bool, legacyID: Int = 0) {
        self.name       = name
        self.colourARGB = colourARGB
        self.sortOrder  = sortOrder
        self.isBuiltIn  = isBuiltIn
        self.legacyID   = legacyID
    }
}