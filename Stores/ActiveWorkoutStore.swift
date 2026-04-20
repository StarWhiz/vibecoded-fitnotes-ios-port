//
//  ActiveWorkoutStore.swift
//  FitNotes iOS
//
//  @Observable active workout store as defined in technical_architecture.md section 6.1
//  Holds live workout state in-memory for instant UI feedback while persisting to SwiftData.
//  Injected into the environment at the app root.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - ExerciseSession (value type)

/// Represents one exercise's live state within today's workout.
/// Safe to pass into SwiftUI views without triggering unnecessary observation.
struct ExerciseSession: Identifiable {
    var id: PersistentIdentifier   // Exercise's SwiftData identity
    var exercise: Exercise
    var sets: [TrainingEntry]      // Today's sets for this exercise, in sortOrder
    var workoutGroup: WorkoutGroup?
    var sortOrder: Int
}

// MARK: - ActiveWorkoutStore

@Observable final class ActiveWorkoutStore {

    // Current date being worked on (defaults to today, navigable to past for edits)
    var date: Date = Calendar.current.startOfDay(for: .now)

    // Ordered list of exercises in today's workout
    var sessions: [ExerciseSession] = []

    // Index into sessions[] for the currently focused exercise
    var activeSessionIndex: Int = 0

    // The set currently being edited (nil = new set mode)
    var selectedEntryID: PersistentIdentifier? = nil

    // Workout timing
    var workoutSession: WorkoutSession? = nil

    // Day-level comment
    var workoutComment: String = ""

    // MARK: - Computed

    var activeSession: ExerciseSession? {
        sessions.indices.contains(activeSessionIndex)
            ? sessions[activeSessionIndex]
            : nil
    }

    var isWorkoutActive: Bool { workoutSession?.isActive == true }

    var totalVolume: Double {
        sessions.flatMap(\.sets).reduce(0) { $0 + $1.volume }
    }

    var totalSets: Int {
        sessions.reduce(0) { $0 + $1.sets.count }
    }

    // MARK: - Load day

    /// Loads all exercises and sets for the given date from SwiftData.
    func load(for date: Date, context: ModelContext) throws {
        self.date = date
        selectedEntryID = nil

        let targetDate = Calendar.current.startOfDay(for: date)
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: targetDate)!

        // Fetch all training entries for this date
        let descriptor = FetchDescriptor<TrainingEntry>(
            predicate: #Predicate<TrainingEntry> {
                $0.date >= targetDate && $0.date < nextDate
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let entries = try context.fetch(descriptor)

        // Group entries by exercise, preserving sort order
        var sessionMap: [PersistentIdentifier: ExerciseSession] = [:]
        var sessionOrder: [PersistentIdentifier] = []

        for entry in entries {
            guard let exercise = entry.exercise else { continue }
            let exerciseID = exercise.persistentModelID

            if sessionMap[exerciseID] != nil {
                sessionMap[exerciseID]!.sets.append(entry)
            } else {
                sessionOrder.append(exerciseID)
                sessionMap[exerciseID] = ExerciseSession(
                    id: exerciseID,
                    exercise: exercise,
                    sets: [entry],
                    workoutGroup: entry.workoutGroup,
                    sortOrder: entry.sortOrder
                )
            }
        }

        sessions = sessionOrder.compactMap { sessionMap[$0] }
        activeSessionIndex = 0

        // Load workout session (timing)
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.date >= targetDate && $0.date < nextDate
            }
        )
        workoutSession = try context.fetch(sessionDescriptor).first

        // Load workout comment
        let commentDescriptor = FetchDescriptor<WorkoutComment>(
            predicate: #Predicate<WorkoutComment> {
                $0.date >= targetDate && $0.date < nextDate
            }
        )
        workoutComment = try context.fetch(commentDescriptor).first?.text ?? ""
    }

    // MARK: - Add exercise to today's workout

    func addExercise(_ exercise: Exercise, context: ModelContext) {
        let exerciseID = exercise.persistentModelID

        // Don't add if already in today's workout
        guard !sessions.contains(where: { $0.id == exerciseID }) else {
            // Navigate to existing session instead
            if let idx = sessions.firstIndex(where: { $0.id == exerciseID }) {
                activeSessionIndex = idx
            }
            return
        }

        let nextSortOrder = (sessions.map(\.sortOrder).max() ?? -1) + 1
        let session = ExerciseSession(
            id: exerciseID,
            exercise: exercise,
            sets: [],
            workoutGroup: nil,
            sortOrder: nextSortOrder
        )
        sessions.append(session)
        activeSessionIndex = sessions.count - 1
    }

    // MARK: - Save set

    /// Saves a new or updated training entry. Returns PR evaluation result.
    @discardableResult
    func saveSet(_ entry: TrainingEntry, context: ModelContext) throws -> (isRecord: Bool, isFirstAtThisWeight: Bool) {
        guard let exercise = entry.exercise else { return (false, false) }
        let exerciseID = exercise.persistentModelID

        // Compute PR flags
        let prResult = PRCalculator.evaluate(
            newEntry: entry,
            existingEntries: exercise.trainingEntries
        )
        entry.isPersonalRecord = prResult.isRecord
        entry.isPersonalRecordFirst = prResult.isFirstAtThisWeight

        // Persist
        if entry.modelContext == nil {
            // New entry
            entry.sortOrder = sessions.first(where: { $0.id == exerciseID })?.sortOrder ?? 0
            context.insert(entry)
        }
        try context.save()

        // Update in-memory state for instant UI feedback
        if let sessionIdx = sessions.firstIndex(where: { $0.id == exerciseID }) {
            let entryID = entry.persistentModelID
            if let setIdx = sessions[sessionIdx].sets.firstIndex(where: { $0.persistentModelID == entryID }) {
                sessions[sessionIdx].sets[setIdx] = entry
            } else {
                sessions[sessionIdx].sets.append(entry)
            }
        }

        selectedEntryID = nil
        return prResult
    }

    // MARK: - Delete set

    func deleteSet(_ entry: TrainingEntry, context: ModelContext) throws {
        guard let exercise = entry.exercise else { return }
        let exerciseID = exercise.persistentModelID
        let entryID = entry.persistentModelID

        context.delete(entry)
        try context.save()

        // Remove from in-memory state
        if let sessionIdx = sessions.firstIndex(where: { $0.id == exerciseID }) {
            sessions[sessionIdx].sets.removeAll { $0.persistentModelID == entryID }

            // Remove the exercise session entirely if no sets remain
            if sessions[sessionIdx].sets.isEmpty {
                sessions.remove(at: sessionIdx)
                activeSessionIndex = min(activeSessionIndex, max(0, sessions.count - 1))
            }
        }

        selectedEntryID = nil
    }

    // MARK: - Remove exercise from today

    func removeExercise(at sessionIndex: Int, context: ModelContext) throws {
        guard sessions.indices.contains(sessionIndex) else { return }
        let session = sessions[sessionIndex]

        // Delete all sets for this exercise today
        for entry in session.sets {
            context.delete(entry)
        }
        try context.save()

        sessions.remove(at: sessionIndex)
        activeSessionIndex = min(activeSessionIndex, max(0, sessions.count - 1))
    }

    // MARK: - Reorder exercises

    func moveExercise(from source: IndexSet, to destination: Int) {
        sessions.move(fromOffsets: source, toOffset: destination)
        // Update sort orders to reflect new positions
        for (index, _) in sessions.enumerated() {
            sessions[index].sortOrder = index
        }
    }

    // MARK: - Workout timing

    func startWorkout(context: ModelContext) {
        if workoutSession == nil {
            let session = WorkoutSession(date: date)
            session.startDateTime = .now
            context.insert(session)
            workoutSession = session
        } else {
            workoutSession?.startDateTime = .now
            workoutSession?.endDateTime = nil
        }
        try? context.save()
        FocusFilterPublisher.workoutStarted()
    }

    func endWorkout(context: ModelContext) {
        workoutSession?.endDateTime = .now
        try? context.save()
        FocusFilterPublisher.workoutEnded()
    }

    // MARK: - Set navigation

    /// Advances to the next incomplete set (auto_select_next_set behaviour).
    func advanceToNextSet() {
        guard let session = activeSession else { return }

        // Find the next incomplete set in the current exercise
        if let nextIncomplete = session.sets.first(where: { !$0.isComplete }) {
            selectedEntryID = nextIncomplete.persistentModelID
            return
        }

        // If all sets complete in current exercise, check workout groups for superset cycling
        if let group = session.workoutGroup {
            let groupSessions = sessions.filter { $0.workoutGroup?.persistentModelID == group.persistentModelID }
            let currentIdx = groupSessions.firstIndex(where: { $0.id == session.id }) ?? 0
            let nextIdx = (currentIdx + 1) % groupSessions.count

            if let globalIdx = sessions.firstIndex(where: { $0.id == groupSessions[nextIdx].id }) {
                activeSessionIndex = globalIdx
                selectedEntryID = nil
                return
            }
        }

        // Move to next exercise in the list
        if activeSessionIndex + 1 < sessions.count {
            activeSessionIndex += 1
            selectedEntryID = nil
        }
    }
}
