//
//  FitNotesApp.swift
//  FitNotes iOS
//
//  App entry point as defined in technical_architecture.md section 2.
//  Registers all SwiftData models, creates environment stores,
//  and injects them into the view hierarchy.
//

import SwiftUI
import SwiftData

private func seedBuiltInDataIfNeeded(context: ModelContext) {
    let existing = (try? context.fetchCount(FetchDescriptor<WorkoutCategory>())) ?? 0
    guard existing == 0 else { return }

    let builtIn: [(name: String, argb: Int32, order: Int)] = [
        ("Shoulders", Int32(bitPattern: 0xFF8E44AD), 0),
        ("Triceps",   Int32(bitPattern: 0xFF27AE60), 1),
        ("Biceps",    Int32(bitPattern: 0xFFF39C12), 2),
        ("Chest",     Int32(bitPattern: 0xFFC0392B), 3),
        ("Back",      Int32(bitPattern: 0xFF2980B9), 4),
        ("Legs",      Int32(bitPattern: 0xFF54B2B6), 5),
        ("Abs",       Int32(bitPattern: 0xFF2C3E50), 6),
        ("Cardio",    Int32(bitPattern: 0xFF7F8C8D), 7),
    ]
    for (i, cat) in builtIn.enumerated() {
        let category = WorkoutCategory(
            name: cat.name,
            colourARGB: cat.argb,
            sortOrder: cat.order,
            isBuiltIn: true,
            legacyID: i + 1
        )
        context.insert(category)
    }

    let settings = AppSettings()
    context.insert(settings)

    try? context.save()
}

@main struct FitNotesApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            AppSettings.self, WorkoutCategory.self, Exercise.self,
            TrainingEntry.self, SetComment.self, WorkoutComment.self,
            WorkoutGroup.self, WorkoutSession.self, Goal.self,
            BodyWeightEntry.self, Measurement.self, MeasurementRecord.self,
            MeasurementUnit.self, Barbell.self, Plate.self,
            Routine.self, RoutineSection.self, RoutineSectionExercise.self,
            RoutineSectionExerciseSet.self,
            ExerciseGraphFavourite.self, RepMaxGridFavourite.self,
        ])
        return try! ModelContainer(for: schema)
    }()

    @State private var workoutStore = ActiveWorkoutStore()
    @State private var timerStore = RestTimerStore()
    @State private var settingsStore = AppSettingsStore()
    @State private var needsSettingsLoad = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(workoutStore)
                .environment(timerStore)
                .environment(settingsStore)
                .task {
                    guard needsSettingsLoad else { return }
                    needsSettingsLoad = false
                    let context = container.mainContext
                    seedBuiltInDataIfNeeded(context: context)
                    if let loaded = try? AppSettingsStore.load(from: context) {
                        settingsStore = loaded
                    }
                }
        }
    }
}
