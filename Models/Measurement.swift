//
//  Measurement.swift
//  FitNotes iOS
//
//  Measurement model as defined in technical_architecture.md section 4.11
//  Maps to SQLite `Measurement` table
//

import Foundation
import SwiftData

@Model final class Measurement {
    var name: String
    var unitID: Int            // FK → MeasurementUnit.legacyID
    var goalTypeRaw: Int
    var goalValue: Double
    var isCustom: Bool         // 0=built-in, 1=user-created
    var isEnabled: Bool
    var sortOrder: Int
    var legacyID: Int

    @Relationship(deleteRule: .cascade, inverse: \MeasurementRecord.measurement)
    var records: [MeasurementRecord] = []

    @Relationship(deleteRule: .nullify)
    var unit: MeasurementUnit?

    init(name: String, unitID: Int = 0, goalTypeRaw: Int = 0, goalValue: Double = 0,
         isCustom: Bool = false, isEnabled: Bool = false, sortOrder: Int = 0,
         legacyID: Int = 0) {
        self.name        = name
        self.unitID      = unitID
        self.goalTypeRaw = goalTypeRaw
        self.goalValue   = goalValue
        self.isCustom    = isCustom
        self.isEnabled   = isEnabled
        self.sortOrder   = sortOrder
        self.legacyID    = legacyID
    }
}