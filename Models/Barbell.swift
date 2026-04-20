//
//  Barbell.swift
//  FitNotes iOS
//
//  Barbell model as defined in technical_architecture.md section 4.12
//  Maps to SQLite `Barbell` table
//

import Foundation
import SwiftData

@Model final class Barbell {
    var name: String?
    var weightKg: Double
    var legacyID: Int

    init(name: String? = nil, weightKg: Double = 0, legacyID: Int = 0) {
        self.name     = name
        self.weightKg = weightKg
        self.legacyID = legacyID
    }
}