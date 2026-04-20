//
//  Goal.swift
//  FitNotes iOS
//
//  Goal model as defined in technical_architecture.md section 4.9
//  Maps to SQLite `Goal` table
//

import Foundation
import SwiftData

@Model final class Goal {
    var goalTypeRaw: Int      // GoalType.rawValue
    var targetValue: Double
    var legacyID: Int

    var exercise: Exercise?

    var goalType: GoalType { GoalType(rawValue: goalTypeRaw) ?? .increase }

    init(goalTypeRaw: Int = 0, targetValue: Double = 0, legacyID: Int = 0) {
        self.goalTypeRaw = goalTypeRaw
        self.targetValue = targetValue
        self.legacyID    = legacyID
    }
}