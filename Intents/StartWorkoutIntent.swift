//
//  StartWorkoutIntent.swift
//  FitNotes iOS
//
//  Siri Shortcut: "Start my workout"
//  Opens the training screen for today. product_roadmap.md section 3.5.
//

import AppIntents
import Foundation

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Opens the training screen for today's workout.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The app's URL scheme handler navigates to today's training screen
        // when the app opens from this intent.
        return .result(dialog: "Starting your workout. Let's go!")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start today's workout")
    }
}
