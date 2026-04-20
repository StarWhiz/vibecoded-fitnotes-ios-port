//
//  MeasurementRecord.swift
//  FitNotes iOS
//
//  MeasurementRecord model as defined in technical_architecture.md section 4.11
//  Maps to SQLite `MeasurementRecord` table
//

import Foundation
import SwiftData

@Model final class MeasurementRecord {
    var recordedAt: Date    // Combines legacy 'date' + 'time' fields on import
    var value: Double
    var comment: String?
    var legacyID: Int

    var measurement: Measurement?

    init(recordedAt: Date, value: Double = 0, comment: String? = nil, legacyID: Int = 0) {
        self.recordedAt = recordedAt
        self.value      = value
        self.comment    = comment
        self.legacyID   = legacyID
    }
}