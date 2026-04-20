//
//  PRCalculator.swift
//  FitNotes iOS
//
//  Personal Record calculator as defined in technical_architecture.md section 6.6
//  Pure domain service — no stored state. Evaluates whether a new training entry
//  constitutes a personal record based on estimated 1RM comparison.
//

import Foundation

struct PRCalculator {

    /// Evaluates whether a new entry is a personal record for its exercise.
    ///
    /// - Parameters:
    ///   - newEntry: The entry being saved (not yet in `existingEntries`).
    ///   - existingEntries: All prior `TrainingEntry` rows for the same exercise.
    /// - Returns: Tuple of PR flags to set on the entry before persisting.
    static func evaluate(
        newEntry: TrainingEntry,
        existingEntries: [TrainingEntry]
    ) -> (isRecord: Bool, isFirstAtThisWeight: Bool) {
        guard newEntry.reps > 0, newEntry.weightKg > 0 else { return (false, false) }

        let best1RM = existingEntries.map(\.estimatedOneRepMaxKg).max() ?? 0
        let isRecord = newEntry.estimatedOneRepMaxKg > best1RM

        if !isRecord { return (false, false) }

        // Check if this is the first time achieving this weight at this rep count
        let firstAtWeight = existingEntries
            .filter { $0.reps == newEntry.reps }
            .allSatisfy { $0.weightKg < newEntry.weightKg }

        return (true, firstAtWeight)
    }

    /// Recalculates PR flags for all entries of a given exercise, ordered chronologically.
    /// Used by the "Recalculate PRs" settings action after editing or deleting old sets.
    ///
    /// - Parameter entries: All `TrainingEntry` rows for one exercise, sorted by date ascending.
    /// - Returns: Array of `(entry, isRecord, isFirstAtThisWeight)` for batch update.
    static func recalculateAll(
        entries: [TrainingEntry]
    ) -> [(entry: TrainingEntry, isRecord: Bool, isFirstAtThisWeight: Bool)] {
        var results: [(entry: TrainingEntry, isRecord: Bool, isFirstAtThisWeight: Bool)] = []
        var runningBest1RM: Double = 0
        var bestWeightAtReps: [Int: Double] = [:]  // reps → highest weight seen

        for entry in entries {
            guard entry.reps > 0, entry.weightKg > 0 else {
                results.append((entry, false, false))
                continue
            }

            let estimated1RM = entry.estimatedOneRepMaxKg
            let isRecord = estimated1RM > runningBest1RM

            var isFirst = false
            if isRecord {
                runningBest1RM = estimated1RM
                let previousBest = bestWeightAtReps[entry.reps] ?? 0
                isFirst = entry.weightKg > previousBest
            }

            if entry.weightKg > (bestWeightAtReps[entry.reps] ?? 0) {
                bestWeightAtReps[entry.reps] = entry.weightKg
            }

            results.append((entry, isRecord, isFirst))
        }

        return results
    }
}
