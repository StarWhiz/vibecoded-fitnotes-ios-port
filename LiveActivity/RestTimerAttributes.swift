//
//  RestTimerAttributes.swift
//  FitNotes iOS
//
//  ActivityKit attributes for the rest timer Live Activity as defined in
//  product_roadmap.md section 3.2. Shared between the main app and the
//  widget extension target.
//
//  Dynamic Island compact: remaining seconds + exercise name.
//  Lock Screen: full countdown ring + exercise name + "Skip" button.
//

import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {

    /// Static context that doesn't change during the activity's lifecycle.
    var exerciseName: String
    var totalSeconds: Int

    /// Dynamic state updated as the timer progresses.
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var timerState: TimerActivityState

        enum TimerActivityState: String, Codable, Hashable {
            case running
            case expired
            case paused
        }
    }
}
