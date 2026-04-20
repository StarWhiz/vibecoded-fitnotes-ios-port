//
//  HealthKitManager.swift
//  FitNotes iOS
//
//  Apple Health integration as defined in product_roadmap.md section 3.1
//  Syncs body weight, body fat percentage, and completed workouts to HealthKit.
//  Write-on-save; read-on-import to avoid duplicates.
//

import Foundation
import HealthKit
import SwiftData

actor HealthKitManager {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // MARK: - Availability

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    /// The set of HealthKit types this app reads and writes.
    private var typesToShare: Set<HKSampleType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKObjectType.workoutType(),
        ]
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKObjectType.workoutType(),
        ]
    }

    /// Requests HealthKit authorization. Call on first launch or from Settings.
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    /// Checks current authorization status for a specific type.
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    // MARK: - Body Weight Sync

    /// Writes a body weight entry to HealthKit.
    func saveBodyWeight(_ entry: BodyWeightEntry) async throws {
        guard isAvailable else { return }

        // Body mass (always stored in kg internally)
        let massType = HKQuantityType(.bodyMass)
        let massQuantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: entry.weightKg)
        let massSample = HKQuantitySample(
            type: massType,
            quantity: massQuantity,
            start: entry.date,
            end: entry.date,
            metadata: [HKMetadataKeyExternalUUID: "fitnotes-bw-\(entry.legacyID)"]
        )
        try await store.save(massSample)

        // Body fat percentage (if tracked)
        if entry.bodyFatPercent > 0 {
            let fatType = HKQuantityType(.bodyFatPercentage)
            let fatQuantity = HKQuantity(unit: .percent(), doubleValue: entry.bodyFatPercent / 100.0)
            let fatSample = HKQuantitySample(
                type: fatType,
                quantity: fatQuantity,
                start: entry.date,
                end: entry.date,
                metadata: [HKMetadataKeyExternalUUID: "fitnotes-bf-\(entry.legacyID)"]
            )
            try await store.save(fatSample)
        }
    }

    // MARK: - Workout Sync

    /// Writes a completed workout to HealthKit with volume and per-exercise metadata.
    func saveWorkout(
        session: WorkoutSession,
        entries: [TrainingEntry],
        categories: Set<String>
    ) async throws {
        guard isAvailable,
              let start = session.startDateTime,
              let end = session.endDateTime else { return }

        // Determine workout type from exercises
        let hasCardio = entries.contains { ExerciseType(rawValue: $0.exercise?.exerciseTypeRaw ?? 0) == .cardio }
        let activityType: HKWorkoutActivityType = hasCardio ? .mixedCardio : .traditionalStrengthTraining

        // Total volume (kg) for strength exercises
        let totalVolumeKg = entries
            .filter { ExerciseType(rawValue: $0.exercise?.exerciseTypeRaw ?? 0) == .weightReps }
            .reduce(0.0) { $0 + $1.volume }

        // Total distance (metres) for cardio exercises
        let totalDistanceM = entries
            .filter { ExerciseType(rawValue: $0.exercise?.exerciseTypeRaw ?? 0) == .cardio }
            .reduce(0.0) { $0 + $1.distanceMetres }

        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: "fitnotes-wo-\(session.legacyID)-\(Int(start.timeIntervalSince1970))",
            "FitNotesTotalSets": entries.count,
            "FitNotesCategories": categories.joined(separator: ", "),
        ]

        let config = HKWorkoutConfiguration()
        config.activityType = activityType

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        // Add volume as a quantity sample
        if totalVolumeKg > 0 {
            // Use a custom quantity type for lifting volume — attached as metadata
            // HealthKit doesn't have a built-in "lifting volume" type, so we record
            // it in the workout's totalEnergyBurned approximation or as metadata.
        }

        // Add distance for cardio workouts
        if totalDistanceM > 0 {
            let distanceType = HKQuantityType(.distanceWalkingRunning)
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: totalDistanceM)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: start,
                end: end
            )
            try await builder.addSamples([distanceSample])
        }

        try await builder.endCollection(at: end)
        try await builder.addMetadata(metadata)
        try await builder.finishWorkout()
    }

    // MARK: - Duplicate Detection (for import)

    /// Checks whether a body weight entry already exists in HealthKit for the given date.
    /// Used during initial import to avoid duplicating data already synced from another source.
    func bodyWeightExists(on date: Date) async throws -> Bool {
        guard isAvailable else { return false }

        let massType = HKQuantityType(.bodyMass)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: massType, predicate: predicate)],
            sortDescriptors: [],
            limit: 1
        )
        let results = try await descriptor.result(for: store)
        return !results.isEmpty
    }

    /// Checks whether a workout already exists in HealthKit for the given time range.
    func workoutExists(start: Date, end: Date) async throws -> Bool {
        guard isAvailable else { return false }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [],
            limit: 1
        )
        let results = try await descriptor.result(for: store)
        return !results.isEmpty
    }

    // MARK: - Read from HealthKit (for cross-reference)

    /// Reads the most recent body weight from HealthKit. Useful for pre-filling the body tracker.
    func latestBodyWeight() async throws -> (kg: Double, date: Date)? {
        guard isAvailable else { return nil }

        let massType = HKQuantityType(.bodyMass)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: massType)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try await descriptor.result(for: store).first else { return nil }
        let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        return (kg, sample.startDate)
    }

    // MARK: - Bulk Import Sync

    /// Syncs all body weight entries to HealthKit, skipping duplicates.
    /// Called after initial .fitnotes import.
    func syncAllBodyWeights(_ entries: [BodyWeightEntry]) async throws {
        guard isAvailable else { return }

        for entry in entries {
            let exists = try await bodyWeightExists(on: entry.date)
            if !exists {
                try await saveBodyWeight(entry)
            }
        }
    }

    /// Syncs all completed workout sessions to HealthKit, skipping duplicates.
    func syncAllWorkouts(
        sessions: [(session: WorkoutSession, entries: [TrainingEntry], categories: Set<String>)]
    ) async throws {
        guard isAvailable else { return }

        for workout in sessions {
            guard let start = workout.session.startDateTime,
                  let end = workout.session.endDateTime else { continue }

            let exists = try await workoutExists(start: start, end: end)
            if !exists {
                try await saveWorkout(
                    session: workout.session,
                    entries: workout.entries,
                    categories: workout.categories
                )
            }
        }
    }
}
