//
//  WorkoutSession.swift
//  FitNotes iOS
//
//  WorkoutSession model as defined in technical_architecture.md section 4.8
//  Maps to SQLite `WorkoutTime` table (renamed to avoid conflict with HealthKit's HKWorkout)
//

import Foundation
import SwiftData

@Model final class WorkoutSession {
    var date: Date
    var startDateTime: Date?
    var endDateTime: Date?
    var legacyID: Int

    var duration: TimeInterval? {
        guard let start = startDateTime, let end = endDateTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var isActive: Bool { startDateTime != nil && endDateTime == nil }

    init(date: Date, legacyID: Int = 0) {
        self.date     = date
        self.legacyID = legacyID
    }
}