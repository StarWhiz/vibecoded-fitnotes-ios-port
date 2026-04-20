//
//  FitNotesShortcuts.swift
//  FitNotes iOS
//
//  AppShortcutsProvider registering all Siri phrases and their corresponding intents.
//  product_roadmap.md section 3.5.
//

import AppIntents

struct FitNotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Start workout in \(.applicationName)",
                "Open \(.applicationName) workout",
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: LogSetIntent(),
            phrases: [
                "Log a set in \(.applicationName)",
                "Record a set in \(.applicationName)",
            ],
            shortTitle: "Log a Set",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: StartRestTimerIntent(),
            phrases: [
                "Start rest timer in \(.applicationName)",
                "Rest timer in \(.applicationName)",
                "Start timer in \(.applicationName)",
            ],
            shortTitle: "Start Rest Timer",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ExerciseStatusIntent(),
            phrases: [
                "Exercise status in \(.applicationName)",
                "Check my last session in \(.applicationName)",
            ],
            shortTitle: "Exercise Status",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: OneRMIntent(),
            phrases: [
                "Check my one rep max in \(.applicationName)",
                "Check 1RM in \(.applicationName)",
            ],
            shortTitle: "Check 1RM",
            systemImageName: "trophy.fill"
        )
    }
}
