//
//  FitNotesWidgetBundle.swift
//  FitNotes iOS Widget Extension
//
//  Bundle registering all home screen widgets and the rest timer Live Activity.
//  This is the @main entry point for the widget extension target.
//  product_roadmap.md sections 3.2 and 3.3.
//

import SwiftUI
import WidgetKit

@main
struct FitNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widgets
        TodayWorkoutWidget()
        StreakCounterWidget()
        NextRoutineWidget()
        LastWorkoutWidget()

        // Live Activity (rest timer on Lock Screen + Dynamic Island)
        RestTimerLiveActivity()
    }
}
