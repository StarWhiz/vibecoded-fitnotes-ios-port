//
//  WidgetDataProvider.swift
//  FitNotes iOS Widget Extension
//
//  Shared data provider for all home screen widgets as defined in
//  product_roadmap.md section 3.3. Uses the shared App Group ModelContainer
//  so the widget extension can read SwiftData models.
//

import Foundation
import SwiftData

/// App Group identifier shared between the main app and widget extension.
/// Must be configured in both targets' entitlements.
enum AppGroup {
    static let identifier = "group.com.fitnotes.ios"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }

    /// Creates a SwiftData ModelContainer using the shared App Group container.
    /// Widget extension and main app both use this so they share the same data store.
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
        let config = ModelConfiguration(
            "FitNotes",
            schema: schema,
            url: containerURL.appendingPathComponent("FitNotes.store"),
            allowsSave: false   // widgets are read-only
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}

/// Lightweight data snapshots for widget timelines — plain value types, not SwiftData models.
enum WidgetData {

    // MARK: - Today's Workout

    struct TodayWorkout {
        let date: Date
        let exercises: [ExerciseSummary]
        let totalSets: Int
        let isActive: Bool
    }

    struct ExerciseSummary: Identifiable {
        let id: String          // exercise name as ID for widgets
        let name: String
        let setCount: Int
        let categoryColor: Int32
    }

    // MARK: - Streak

    struct Streak {
        let currentStreak: Int
        let longestStreak: Int
        let lastWorkoutDate: Date?
    }

    // MARK: - Next Routine

    struct NextRoutine {
        let routineName: String
        let sectionName: String
        let exercises: [String]   // exercise names
    }

    // MARK: - Last Workout

    struct LastWorkout {
        let date: Date
        let totalVolumeLbs: Double
        let totalSets: Int
        let exercises: [ExerciseSummary]
        let durationMinutes: Int?
    }

    // MARK: - Queries

    static func fetchTodayWorkout(context: ModelContext) throws -> TodayWorkout {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let descriptor = FetchDescriptor<TrainingEntry>(
            predicate: #Predicate<TrainingEntry> {
                $0.date >= today && $0.date < tomorrow
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let entries = try context.fetch(descriptor)

        var exerciseMap: [String: (count: Int, color: Int32)] = [:]
        var exerciseOrder: [String] = []

        for entry in entries {
            let name = entry.exercise?.name ?? "Unknown"
            if exerciseMap[name] != nil {
                exerciseMap[name]!.count += 1
            } else {
                exerciseOrder.append(name)
                exerciseMap[name] = (1, entry.exercise?.category?.colourARGB ?? 0)
            }
        }

        let summaries = exerciseOrder.map { name in
            ExerciseSummary(
                id: name,
                name: name,
                setCount: exerciseMap[name]!.count,
                categoryColor: exerciseMap[name]!.color
            )
        }

        // Check if workout is active
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.date >= today && $0.date < tomorrow
            }
        )
        let session = try context.fetch(sessionDescriptor).first
        let isActive = session?.startDateTime != nil && session?.endDateTime == nil

        return TodayWorkout(
            date: today,
            exercises: summaries,
            totalSets: entries.count,
            isActive: isActive
        )
    }

    static func fetchStreak(context: ModelContext) throws -> Streak {
        let descriptor = FetchDescriptor<TrainingEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let entries = try context.fetch(descriptor)

        // Collect unique workout dates
        var workoutDates: Set<Date> = []
        for entry in entries {
            workoutDates.insert(Calendar.current.startOfDay(for: entry.date))
        }

        let sortedDates = workoutDates.sorted(by: >)
        guard let lastDate = sortedDates.first else {
            return Streak(currentStreak: 0, longestStreak: 0, lastWorkoutDate: nil)
        }

        // Calculate current streak (consecutive days ending today or yesterday)
        let today = Calendar.current.startOfDay(for: .now)
        var currentStreak = 0
        var checkDate = today

        // Allow the streak to start from today or yesterday
        if !workoutDates.contains(today) {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            if workoutDates.contains(yesterday) {
                checkDate = yesterday
            } else {
                // Streak is broken
                return Streak(
                    currentStreak: 0,
                    longestStreak: calculateLongestStreak(dates: sortedDates),
                    lastWorkoutDate: lastDate
                )
            }
        }

        while workoutDates.contains(checkDate) {
            currentStreak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
        }

        let longestStreak = calculateLongestStreak(dates: sortedDates)

        return Streak(
            currentStreak: currentStreak,
            longestStreak: max(longestStreak, currentStreak),
            lastWorkoutDate: lastDate
        )
    }

    private static func calculateLongestStreak(dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i - 1]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    static func fetchNextRoutine(context: ModelContext) throws -> NextRoutine? {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.name)]
        )
        let routines = try context.fetch(descriptor)
        guard let routine = routines.first,
              let section = routine.sections
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .first else { return nil }

        let exerciseNames = section.exercises
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .compactMap(\.exercise?.name)

        return NextRoutine(
            routineName: routine.name,
            sectionName: section.name,
            exercises: exerciseNames
        )
    }

    static func fetchLastWorkout(context: ModelContext) throws -> LastWorkout? {
        // Find the most recent date with training entries
        let descriptor = FetchDescriptor<TrainingEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allEntries = try context.fetch(descriptor)
        guard let lastDate = allEntries.first?.date else { return nil }

        let dayStart = Calendar.current.startOfDay(for: lastDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let dayEntries = allEntries.filter { $0.date >= dayStart && $0.date < dayEnd }

        var exerciseMap: [String: (count: Int, color: Int32)] = [:]
        var exerciseOrder: [String] = []

        for entry in dayEntries {
            let name = entry.exercise?.name ?? "Unknown"
            if exerciseMap[name] != nil {
                exerciseMap[name]!.count += 1
            } else {
                exerciseOrder.append(name)
                exerciseMap[name] = (1, entry.exercise?.category?.colourARGB ?? 0)
            }
        }

        let summaries = exerciseOrder.map { name in
            ExerciseSummary(
                id: name,
                name: name,
                setCount: exerciseMap[name]!.count,
                categoryColor: exerciseMap[name]!.color
            )
        }

        let totalVolumeLbs = dayEntries.reduce(0.0) { $0 + $1.volume } * 2.20462

        // Check workout duration
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.date >= dayStart && $0.date < dayEnd
            }
        )
        let session = try context.fetch(sessionDescriptor).first
        let durationMinutes: Int? = session?.duration.map { Int($0 / 60.0) }

        return LastWorkout(
            date: dayStart,
            totalVolumeLbs: totalVolumeLbs,
            totalSets: dayEntries.count,
            exercises: summaries,
            durationMinutes: durationMinutes
        )
    }
}
