//
//  AppSettings.swift
//  FitNotes iOS
//
//  AppSettings model as defined in technical_architecture.md section 4.1
//  Maps to SQLite `settings` table (always a single row, _id = 1)
//

import Foundation
import SwiftData

@Model final class AppSettings {
    // Unit system
    var isImperial: Bool                  // settings.metric == 0

    // Calendar
    var firstDayOfWeek: Int              // 0 = Sunday, 1 = Monday

    // Increments (stored in kg)
    var defaultWeightIncrementKg: Double  // settings.weight_increment
    var bodyWeightIncrementKg: Double     // settings.body_weight_increment

    // Behaviour flags
    var trackPersonalRecords: Bool
    var markSetsComplete: Bool
    var autoSelectNextSet: Bool

    // Rest timer
    var restTimerSeconds: Int
    var restTimerAutoStart: Bool

    // Theme (iOS mapping: 0=system, 1=light, 2=dark)
    var appThemeID: Int

    init() {
        isImperial               = true
        firstDayOfWeek           = 1
        defaultWeightIncrementKg = 1.13398  // ≈ 2.5 lbs
        bodyWeightIncrementKg    = 0.1
        trackPersonalRecords     = true
        markSetsComplete         = true
        autoSelectNextSet        = true
        restTimerSeconds         = 120
        restTimerAutoStart       = true
        appThemeID               = 0
    }
}