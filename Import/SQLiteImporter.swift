//
//  SQLiteImporter.swift
//  FitNotes iOS
//
//  SQLite to SwiftData migration pipeline as defined in migration_plan.md
//  Uses GRDB.swift for type-safe read-only access to .fitnotes backup files
//

import Foundation
import SwiftData
import GRDB

// MARK: - Import Verification Report
struct ImportVerificationReport {
    var passed: Bool { failures.isEmpty }
    var failures: [String] = []
    var warnings: [String] = []

    var sourceSets: Int = 0
    var targetSets: Int = 0
    var sourceExercises: Int = 0
    var targetExercises: Int = 0
    var sourceCategories: Int = 0
    var targetCategories: Int = 0
    var sourceRoutines: Int = 0
    var targetRoutines: Int = 0
    var sourceComments: Int = 0
    var targetComments: Int = 0
    var sourceWorkoutDays: Int = 0
    var targetWorkoutDays: Int = 0
}

// MARK: - SQLite Importer
final class SQLiteImporter {

    private let db: DatabaseQueue
    private let context: ModelContext

    init(fileURL: URL, container: ModelContainer) throws {
        var config = Configuration()
        config.readonly = true
        self.db = try DatabaseQueue(path: fileURL.path, configuration: config)
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
    }

    // MARK: - Main Import Function
    func importBackup() throws -> ImportVerificationReport {
        try db.read { db in
            // Phase 1: seed lookup maps (legacyID → SwiftData object)
            let categoryMap = try importCategories(db)
            let exerciseMap = try importExercises(db, categoryMap: categoryMap)
            let routineSetMap = try importRoutineHierarchy(db, exerciseMap: exerciseMap)
            let workoutGroupMap = try importWorkoutGroups(db)
            let measurementUnitMap = try importMeasurementUnits(db)
            let measurementMap = try importMeasurements(db, unitMap: measurementUnitMap)

            // Phase 2: bulk import training log (largest table)
            let trainingMap = try importTrainingLog(db,
                                                  exerciseMap: exerciseMap,
                                                  workoutGroupMap: workoutGroupMap,
                                                  routineSetMap: routineSetMap)

            // Phase 3: import remaining tables
            try importComments(db, trainingMap: trainingMap)
            try importWorkoutComments(db)
            try importWorkoutTimes(db)
            try importGoals(db, exerciseMap: exerciseMap)
            try importBodyWeight(db)
            try importMeasurementRecords(db, measurementMap: measurementMap)
            try importBarbells(db)
            try importPlates(db)
            try importExerciseGraphFavourites(db, exerciseMap: exerciseMap)
            try importRepMaxGridFavourites(db)
            try importSettings(db)
        }

        try context.save()

        // Verify import
        return try db.read { db in
            try verifyImport(source: db, target: context)
        }
    }

    // MARK: - Table Import Functions (in dependency order)

    private func importSettings(_ db: Database) throws {
        let row = try Row.fetchOne(db, sql: "SELECT * FROM settings WHERE _id = 1")
        guard let row = row else { return }

        let settings = AppSettings()
        settings.isImperial               = row["metric"] as Int == 0          // 0 = Imperial
        settings.firstDayOfWeek           = row["first_day_of_week"] as Int
        settings.defaultWeightIncrementKg = row["weight_increment"] as Double
        settings.bodyWeightIncrementKg    = row["body_weight_increment"] as Double
        settings.trackPersonalRecords     = (row["track_personal_records"] as Int) != 0
        settings.markSetsComplete         = (row["mark_sets_complete"] as Int) != 0
        settings.autoSelectNextSet        = (row["auto_select_next_set"] as Int) != 0
        settings.restTimerSeconds         = row["rest_timer_seconds"] as Int
        settings.restTimerAutoStart       = (row["rest_timer_auto_start"] as Int) != 0
        settings.appThemeID               = row["app_theme_id"] as Int
        context.insert(settings)
    }

    private func importMeasurementUnits(_ db: Database) throws -> [Int: MeasurementUnit] {
        var map = [Int: MeasurementUnit]()
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM MeasurementUnit")
        for row in rows {
            let id: Int = row["_id"]
            let unit = MeasurementUnit(
                typeRaw:   row["type"],
                longName:  row["long_name"],
                shortName: row["short_name"],
                isCustom:  false,  // No custom flag in source DB
                legacyID:  id
            )
            context.insert(unit)
            map[id] = unit
        }
        return map
    }

    private func importCategories(_ db: Database) throws -> [Int: WorkoutCategory] {
        var map = [Int: WorkoutCategory]()
        let rows = try Row.fetchAll(db, sql: "SELECT _id, name, colour, sort_order FROM Category")
        for row in rows {
            let id: Int = row["_id"]
            let rawColour: Int = row["colour"]
            let colourARGB: Int32 = Int32(truncatingIfNeeded: rawColour)

            let cat = WorkoutCategory(
                name:       row["name"],
                colourARGB: colourARGB,
                sortOrder:  row["sort_order"],
                isBuiltIn:  id <= 8,          // IDs 1-8 are the built-in categories
                legacyID:   id
            )
            context.insert(cat)
            map[id] = cat
        }
        return map
    }

    private func importExercises(_ db: Database, categoryMap: [Int: WorkoutCategory]) throws -> [Int: Exercise] {
        var map = [Int: Exercise]()
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM exercise")
        for row in rows {
            let id: Int = row["_id"]
            let ex = Exercise(
                name:            row["name"],
                exerciseTypeRaw: row["exercise_type_id"] as Int,
                weightUnitRaw:   row["weight_unit_id"] as Int,
                isFavourite:     (row["is_favourite"] as Int) != 0,
                legacyID:        id
            )
            ex.notes                   = row["notes"]
            ex.defaultGraphID          = row["default_graph_id"]
            ex.defaultRestTimeSeconds  = row["default_rest_time"]
            
            // weight_increment: stored as kg × 1000; nil (NULL) means use global default
            if let rawIncrement = row["weight_increment"] as? Int {
                ex.weightIncrementKg = Double(rawIncrement) / 1000.0
            }
            
            ex.category = categoryMap[row["category_id"] as Int]
            context.insert(ex)
            map[id] = ex
        }
        return map
    }

    private func importMeasurements(_ db: Database, unitMap: [Int: MeasurementUnit]) throws -> [Int: Measurement] {
        var map = [Int: Measurement]()
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM Measurement")
        for row in rows {
            let id: Int = row["_id"]
            let measurement = Measurement(
                name:        row["name"],
                unitID:      row["unit_id"] as Int,
                goalTypeRaw: row["goal_type"] as Int,
                goalValue:   row["goal_value"] as Double,
                isCustom:    (row["custom"] as Int) != 0,
                isEnabled:   (row["enabled"] as Int) != 0,
                sortOrder:   row["sort_order"] as Int,
                legacyID:    id
            )
            measurement.unit = unitMap[row["unit_id"] as Int]
            context.insert(measurement)
            map[id] = measurement
        }
        return map
    }

    private func importRoutineHierarchy(_ db: Database, exerciseMap: [Int: Exercise]) throws -> [Int: RoutineSectionExerciseSet] {
        var routineMap = [Int: Routine]()
        var routineSetMap = [Int: RoutineSectionExerciseSet]()

        // Import Routines
        let routineRows = try Row.fetchAll(db, sql: "SELECT * FROM Routine")
        for row in routineRows {
            let id: Int = row["_id"]
            let routine = Routine(
                name:      row["name"],
                legacyID:  id
            )
            context.insert(routine)
            routineMap[id] = routine
        }

        // Import RoutineSections
        var sectionMap = [Int: RoutineSection]()
        let sectionRows = try Row.fetchAll(db, sql: "SELECT * FROM RoutineSection")
        for row in sectionRows {
            let id: Int = row["_id"]
            let section = RoutineSection(
                name:      row["name"],
                sortOrder: row["sort_order"] as Int,
                legacyID:  id
            )
            section.routine = routineMap[row["routine_id"] as Int]
            context.insert(section)
            sectionMap[id] = section
        }

        // Import RoutineSectionExercises
        var rseMap = [Int: RoutineSectionExercise]()
        let rseRows = try Row.fetchAll(db, sql: "SELECT * FROM RoutineSectionExercise")
        for row in rseRows {
            let id: Int = row["_id"]
            let rse = RoutineSectionExercise(
                populateSetsTypeRaw: row["populate_sets_type"] as Int,
                sortOrder:           row["sort_order"] as Int,
                legacyID:            id
            )
            rse.section  = sectionMap[row["routine_section_id"] as Int]
            rse.exercise = exerciseMap[row["exercise_id"] as Int]
            context.insert(rse)
            rseMap[id] = rse
        }

        // Import RoutineSectionExerciseSets
        let rsesRows = try Row.fetchAll(db, sql: "SELECT * FROM RoutineSectionExerciseSet")
        for row in rsesRows {
            let id: Int = row["_id"]
            let rses = RoutineSectionExerciseSet(
                weightKg:         row["weight"] as Double,
                reps:             row["reps"] as Int,
                weightUnitRaw:    row["unit"] as Int,
                distanceMetres:   Double(row["distance"] as Int) / 1000.0,
                durationSeconds:  row["duration_seconds"] as Int,
                sortOrder:        row["sort_order"] as Int,
                legacyID:         id
            )
            rses.sectionExercise = rseMap[row["routine_section_exercise_id"] as Int]
            context.insert(rses)
            routineSetMap[id] = rses
        }

        return routineSetMap
    }

    private func importWorkoutGroups(_ db: Database) throws -> [Int: WorkoutGroup] {
        var map = [Int: WorkoutGroup]()
        let groupRows = try Row.fetchAll(db, sql: "SELECT * FROM WorkoutGroup")
        for row in groupRows {
            let id: Int = row["_id"]
            let rawColour: Int = row["colour"]
            let colourARGB: Int32 = Int32(truncatingIfNeeded: rawColour)
            let dateStr: String = row["date"]
            
            guard let date = dateStr.fitnotesDate else { continue }
            
            let group = WorkoutGroup(
                name:       row["name"],
                colourARGB: colourARGB,
                date:       date,
                legacyID:   id
            )
            context.insert(group)
            map[id] = group
        }
        
        return map
    }

    private func importTrainingLog(_ db: Database,
                                   exerciseMap: [Int: Exercise],
                                   workoutGroupMap: [Int: WorkoutGroup],
                                   routineSetMap: [Int: RoutineSectionExerciseSet]) throws -> [Int: TrainingEntry] {
        var map = [Int: TrainingEntry]()

        // Sort by date + exercise to assign stable sortOrder values
        let sql = """
            SELECT * FROM training_log
            ORDER BY date ASC, exercise_id ASC, _id ASC
        """
        var sortCounters = [String: Int]()   // key: "YYYY-MM-DD_exerciseID"

        let rows = try Row.fetchAll(db, sql: sql)
        for row in rows {
            let id: Int = row["_id"]
            let dateStr: String = row["date"]
            let exerciseID: Int = row["exercise_id"]

            guard let date = dateStr.fitnotesDate else { continue }

            let counterKey = "\(dateStr)_\(exerciseID)"
            let order = sortCounters[counterKey, default: 0]
            sortCounters[counterKey] = order + 1

            let entry = TrainingEntry(
                date:          date,
                weightKg:      row["metric_weight"] as Double,
                reps:          row["reps"] as Int,
                weightUnitRaw: row["unit"] as Int,
                legacyID:      id
            )
            entry.routineSetLegacyID    = row["routine_section_exercise_set_id"] as Int
            entry.timerAutoStart        = (row["timer_auto_start"] as Int) != 0
            entry.isPersonalRecord      = (row["is_personal_record"] as Int) != 0
            entry.isPersonalRecordFirst = (row["is_personal_record_first"] as Int) != 0
            entry.isComplete            = (row["is_complete"] as Int) != 0
            entry.isPendingUpdate       = (row["is_pending_update"] as Int) != 0
            entry.distanceMetres        = Double(row["distance"] as Int) / 1000.0
            entry.durationSeconds       = row["duration_seconds"] as Int
            entry.sortOrder             = order

            entry.exercise = exerciseMap[exerciseID]
            if entry.routineSetLegacyID != 0 {
                entry.routineSet = routineSetMap[entry.routineSetLegacyID]
            }
            
            // Link to workout group if present
            if let groupID = row["workout_group_id"] as? Int, groupID != 0 {
                entry.workoutGroup = workoutGroupMap[groupID]
            }

            context.insert(entry)
            map[id] = entry
        }
        return map
    }

    private func importComments(_ db: Database, trainingMap: [Int: TrainingEntry]) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM Comment WHERE owner_type_id = 1")
        for row in rows {
            let ownerID: Int = row["owner_id"]
            guard let entry = trainingMap[ownerID] else { continue }
            
            let comment = SetComment(text: row["text"], legacyID: row["_id"])
            comment.trainingEntry = entry
            context.insert(comment)
        }
    }

    private func importWorkoutComments(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM WorkoutComment")
        for row in rows {
            let dateStr: String = row["date"]
            guard let date = dateStr.fitnotesDate else { continue }
            
            let wc = WorkoutComment(
                date:     date,
                text:     row["comment"],
                legacyID: row["_id"]
            )
            context.insert(wc)
        }
    }

    private func importWorkoutTimes(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM WorkoutTime")
        for row in rows {
            let dateStr: String = row["date"]
            guard let date = dateStr.fitnotesDate else { continue }
            
            let session = WorkoutSession(date: date, legacyID: row["_id"])
            session.startDateTime = (row["start_date_time"] as? String)?.fitnotesDateTime
            session.endDateTime   = (row["end_date_time"] as? String)?.fitnotesDateTime
            context.insert(session)
        }
    }

    private func importGoals(_ db: Database, exerciseMap: [Int: Exercise]) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM Goal")
        for row in rows {
            let exerciseID: Int = row["exercise_id"]
            guard let exercise = exerciseMap[exerciseID] else { continue }
            
            let goal = Goal(
                goalTypeRaw: row["goal_type"] as Int,
                targetValue: row["target_value"] as Double,
                legacyID:    row["_id"]
            )
            goal.exercise = exercise
            context.insert(goal)
        }
    }

    private func importBodyWeight(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM BodyWeight")
        for row in rows {
            let dateStr: String = row["date"]
            guard let date = dateStr.fitnotesDate else { continue }
            
            let bwe = BodyWeightEntry(
                date:           date,
                weightKg:       row["body_weight_metric"] as Double,
                bodyFatPercent: row["body_fat"] as Double,
                comment:        row["comments"],
                legacyID:       row["_id"]
            )
            context.insert(bwe)
        }
    }

    private func importMeasurementRecords(_ db: Database, measurementMap: [Int: Measurement]) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM MeasurementRecord")
        for row in rows {
            let measurementID: Int = row["measurement_id"]
            guard let measurement = measurementMap[measurementID] else { continue }
            
            let dateStr: String = row["date"]
            guard let date = dateStr.fitnotesDate else { continue }
            
            let record = MeasurementRecord(
                recordedAt: date,
                value:      row["value"] as Double,
                comment:    row["comment"],
                legacyID:   row["_id"]
            )
            record.measurement = measurement
            context.insert(record)
        }
    }

    private func importBarbells(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM Barbell")
        for row in rows {
            let barbell = Barbell(
                name:     row["name"],
                weightKg: row["weight"] as Double,
                legacyID: row["_id"]
            )
            context.insert(barbell)
        }
    }

    private func importPlates(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM Plate")
        for row in rows {
            let rawColour: Int = row["colour"]
            let colourARGB: Int32 = Int32(truncatingIfNeeded: rawColour)
            
            let plate = Plate(
                weightKg:     row["weight"] as Double,
                count:        row["count"] as Int,
                colourARGB:   colourARGB,
                widthMm:      row["width_mm"],
                diameterMm:   row["diameter_mm"],
                isAvailable:  (row["is_available"] as Int) != 0,
                legacyID:     row["_id"]
            )
            context.insert(plate)
        }
    }

    private func importExerciseGraphFavourites(_ db: Database, exerciseMap: [Int: Exercise]) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM ExerciseGraphFavourite")
        for row in rows {
            let exerciseID: Int = row["exercise_id"]
            guard let exercise = exerciseMap[exerciseID] else { continue }
            
            let fav = ExerciseGraphFavourite(
                graphMetricRaw: row["graph_metric_id"] as Int,
                legacyID:       row["_id"]
            )
            fav.exercise = exercise
            context.insert(fav)
        }
    }

    private func importRepMaxGridFavourites(_ db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM RepMaxGridFavourite")
        for row in rows {
            let fav = RepMaxGridFavourite(
                primaryExerciseLegacyID:   row["primary_exercise_id"] as Int,
                secondaryExerciseLegacyID: row["secondary_exercise_id"] as Int,
                legacyID:                  row["_id"]
            )
            context.insert(fav)
        }
    }

    // MARK: - Verification

    private func verifyImport(source db: Database, target context: ModelContext) throws -> ImportVerificationReport {
        var report = ImportVerificationReport()

        // 1. Total sets (training_log rows)
        let sourceSets = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM training_log")!
        let targetSets = (try? context.fetch(FetchDescriptor<TrainingEntry>()))?.count ?? 0
        if sourceSets != targetSets {
            report.failures.append(
                "Sets: source=\(sourceSets), iOS=\(targetSets) (delta: \(targetSets - sourceSets))"
            )
        }

        // 2. Unique workout days (distinct dates in training_log)
        let sourceWorkoutDays = try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT date) FROM training_log")!
        let targetFetch = FetchDescriptor<TrainingEntry>()
        let allEntries = (try? context.fetch(targetFetch)) ?? []
        let targetWorkoutDays = Set(allEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
        if sourceWorkoutDays != targetWorkoutDays {
            report.failures.append(
                "Workout days: source=\(sourceWorkoutDays), iOS=\(targetWorkoutDays)"
            )
        }

        // 3. Exercises
        let sourceExercises = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM exercise")!
        let targetExercises = (try? context.fetch(FetchDescriptor<Exercise>()))?.count ?? 0
        if sourceExercises != targetExercises {
            report.failures.append(
                "Exercises: source=\(sourceExercises), iOS=\(targetExercises)"
            )
        }

        // 4. Categories
        let sourceCategories = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Category")!
        let targetCategories = (try? context.fetch(FetchDescriptor<WorkoutCategory>()))?.count ?? 0
        if sourceCategories != targetCategories {
            report.failures.append(
                "Categories: source=\(sourceCategories), iOS=\(targetCategories)"
            )
        }

        // 5. Routines
        let sourceRoutines = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Routine")!
        let targetRoutines = (try? context.fetch(FetchDescriptor<Routine>()))?.count ?? 0
        if sourceRoutines != targetRoutines {
            report.failures.append(
                "Routines: source=\(sourceRoutines), iOS=\(targetRoutines)"
            )
        }

        // 6. Set-level comments
        let sourceComments = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Comment WHERE owner_type_id = 1")!
        let targetComments = (try? context.fetch(FetchDescriptor<SetComment>()))?.count ?? 0
        if sourceComments != targetComments {
            report.failures.append(
                "Set comments: source=\(sourceComments), iOS=\(targetComments)"
            )
        }

        // 7. Colour spot-check — verify the 8 built-in category colours
        let builtInColors: [(id: Int, expectedARGB: Int32)] = [
            (1, Int32(bitPattern: 0xFF8E44AD)),
            (4, Int32(bitPattern: 0xFFC0392B)),
            (5, Int32(bitPattern: 0xFF2980B9)),
        ]
        let fetchedCategories = (try? context.fetch(FetchDescriptor<WorkoutCategory>())) ?? []
        let categoryByLegacy = Dictionary(uniqueKeysWithValues: fetchedCategories.map { ($0.legacyID, $0) })
        for check in builtInColors {
            if let cat = categoryByLegacy[check.id], cat.colourARGB != check.expectedARGB {
                report.failures.append(
                    "Category \(check.id) colour mismatch: got \(cat.colourARGB), expected \(check.expectedARGB)"
                )
            }
        }

        // 8. Date sanity — no TrainingEntry should have a date before 2000 or after today
        let tooOld = allEntries.filter { $0.date < Date(timeIntervalSince1970: 946684800) }   // Jan 1 2000
        let future  = allEntries.filter { $0.date > Date() }
        if !tooOld.isEmpty  { report.failures.append("Found \(tooOld.count) entries with dates before 2000") }
        if !future.isEmpty  { report.failures.append("Found \(future.count) entries with future dates") }

        return report
    }
}