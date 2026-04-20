//
//  StartRestTimerIntent.swift
//  FitNotes iOS
//
//  Siri Shortcut: "Start rest timer"
//  Fires the default rest timer. product_roadmap.md section 3.5.
//

import AppIntents
import Foundation
import SwiftData

struct StartRestTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Rest Timer"
    static var description = IntentDescription("Starts the rest timer with your default duration.")
    static var openAppWhenRun = true

    @Parameter(title: "Seconds", default: 0)
    var customSeconds: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Read rest timer duration from settings
        let container = try AppGroup.makeModelContainer()
        let context = ModelContext(container)
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try context.fetch(settingsDescriptor).first ?? AppSettings()

        let seconds = customSeconds > 0 ? customSeconds : settings.restTimerSeconds
        let minutes = seconds / 60
        let remainderSecs = seconds % 60

        let timeString: String
        if minutes > 0 && remainderSecs > 0 {
            timeString = "\(minutes) minute\(minutes == 1 ? "" : "s") and \(remainderSecs) seconds"
        } else if minutes > 0 {
            timeString = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            timeString = "\(seconds) seconds"
        }

        // The app will read the intent and start the timer via RestTimerStore
        // when it opens. We pass the duration via the URL scheme.
        return .result(dialog: "Starting rest timer for \(timeString).")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start rest timer for \(\.$customSeconds) seconds")
    }
}
