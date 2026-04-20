//
//  AppGroup.swift
//  FitNotes iOS
//
//  Provides the shared container URL used by the main app and extensions.
//  When an App Group entitlement is configured, containerURL points to the
//  shared group container. Until then, falls back to the app's own Documents
//  directory so CloudSyncManager can locate the SwiftData store.
//

import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.fitnotes.ios"

    /// The container directory shared between the app and its extensions.
    /// Falls back to the app's Documents directory if the group container is unavailable.
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Creates a ModelContainer pointing at the shared store.
    /// Used by App Intents and Widget extensions that run outside the main app process.
    static func makeModelContainer() throws -> ModelContainer {
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
        let storeURL = containerURL.appendingPathComponent("FitNotes.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
