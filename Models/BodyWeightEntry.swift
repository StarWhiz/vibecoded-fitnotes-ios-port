//
//  BodyWeightEntry.swift
//  FitNotes iOS
//
//  BodyWeightEntry model as defined in technical_architecture.md section 4.10
//  Maps to SQLite `BodyWeight` table (always stored in kg; convert for display)
//

import Foundation
import SwiftData

@Model final class BodyWeightEntry {
    var date: Date
    var weightKg: Double       // BodyWeight.body_weight_metric — always kg
    var bodyFatPercent: Double // 0.0 if not tracked
    var comment: String?
    var legacyID: Int

    var weightLbs: Double { weightKg * 2.20462 }

    func displayWeight(isImperial: Bool) -> Double {
        isImperial ? weightLbs : weightKg
    }

    init(date: Date, weightKg: Double = 0, bodyFatPercent: Double = 0,
         comment: String? = nil, legacyID: Int = 0) {
        self.date           = date
        self.weightKg       = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.comment        = comment
        self.legacyID       = legacyID
    }
}