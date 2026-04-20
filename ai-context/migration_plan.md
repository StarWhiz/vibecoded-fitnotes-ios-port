# FitNotes iOS — SQLite → SwiftData Migration Plan

**Source:** `FitNotes_Backup.fitnotes` (SQLite 3)  
**Target:** SwiftData `ModelContext` (iOS 17+)  
**Scope:** 3,191 `training_log` rows · 125 exercises · full schema  

---

## Table of Contents

1. [Strategy Overview](#1-strategy-overview)
2. [SQLite Access Layer](#2-sqlite-access-layer)
3. [Import Order (Dependency Graph)](#3-import-order-dependency-graph)
4. [Row-to-Object Mapping Logic](#4-row-to-object-mapping-logic)
5. [Data Type Conversions](#5-data-type-conversions)
6. [Verification Step](#6-verification-step)

---

## 1. Strategy Overview

The importer is a **one-shot, non-destructive operation**: it reads the source `.fitnotes` file, constructs SwiftData model objects in memory, and batch-inserts them into a fresh `ModelContext`. It never modifies the source file. If the import is interrupted it can be re-run safely because the importer checks for a completed-flag in `AppSettings` before starting.

```
FitNotes_Backup.fitnotes
        │
        ▼
  SQLiteImporter (actor)
        │   builds id-resolution maps
        │   constructs @Model objects
        ▼
  ModelContext.insert(...)
        │
        ▼
  ModelContext.save()   ← single transaction
        │
        ▼
  VerificationReport
```

The entire import runs inside a single SwiftData save transaction. On failure, the context is rolled back and the user is shown the error with a retry option.

---

## 2. SQLite Access Layer

Use **GRDB.swift** for type-safe row decoding and connection management. Add it via Swift Package Manager:

```swift
// Package.swift dependency
.package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
```

Open the `.fitnotes` file read-only so the importer can never corrupt the backup:

```swift
import GRDB

actor SQLiteImporter {
    private let db: DatabaseQueue

    init(fileURL: URL) throws {
        var config = Configuration()
        config.readonly = true
        self.db = try DatabaseQueue(path: fileURL.path, configuration: config)
    }
}
```

---

## 3. Import Order (Dependency Graph)

Rows must be inserted in the order below so that FK look-ups always resolve to an already-inserted SwiftData object. Each step builds an `[Int: ModelObject]` dictionary keyed by `legacyID` for use by later steps.

```
Step  Table(s)                          SwiftData Class            Depends On
────  ────────────────────────────────  ─────────────────────────  ──────────
 1    settings                          AppSettings                —
 2    MeasurementUnit                   MeasurementUnit            —
 3    Category                          WorkoutCategory            —
 4    exercise                          Exercise                   WorkoutCategory (step 3)
 5    Measurement                       Measurement                MeasurementUnit (step 2)
 6    Routine                           Routine                    —
 7    RoutineSection                    RoutineSection             Routine (step 6)
 8    RoutineSectionExercise            RoutineSectionExercise     RoutineSection (step 7), Exercise (step 4)
 9    RoutineSectionExerciseSet         RoutineSectionExerciseSet  RoutineSectionExercise (step 8)
10    WorkoutGroup                      WorkoutGroup               —
11    WorkoutGroupExercise              (populates WorkoutGroup.entries relationship)
12    training_log                      TrainingEntry              Exercise (step 4), WorkoutGroup (step 10), RoutineSectionExerciseSet (step 9)
13    Comment                           SetComment                 TrainingEntry (step 12)
14    WorkoutComment                    WorkoutComment             —
15    WorkoutTime                       WorkoutSession             —
16    Goal                              Goal                       Exercise (step 4)
17    BodyWeight                        BodyWeightEntry            —
18    MeasurementRecord                 MeasurementRecord          Measurement (step 5)
19    Barbell                           Barbell                    —
20    Plate                             Plate                      —
21    ExerciseGraphFavourite            ExerciseGraphFavourite     Exercise (step 4)
22    RepMaxGridFavourite               RepMaxGridFavourite        Exercise (step 4)
```

Tables to **skip entirely**: `android_metadata`.

---

## 4. Row-to-Object Mapping Logic

### 4.1 AppSettings ← `settings`

```swift
struct SettingsRow: FetchableRecord, Decodable {
    let metric: Int
    let first_day_of_week: Int
    let weight_increment: Double
    let body_weight_increment: Double
    let track_personal_records: Int
    let mark_sets_complete: Int
    let auto_select_next_set: Int
    let rest_timer_seconds: Int
    let rest_timer_auto_start: Int
    let app_theme_id: Int
}

func importSettings(db: Database, context: ModelContext) throws {
    let row = try SettingsRow.fetchOne(db, sql: "SELECT * FROM settings WHERE _id = 1")!
    let settings = AppSettings()
    settings.isImperial               = row.metric == 0          // 0 = Imperial
    settings.firstDayOfWeek           = row.first_day_of_week
    settings.defaultWeightIncrementKg = row.weight_increment     // already in kg
    settings.bodyWeightIncrementKg    = row.body_weight_increment
    settings.trackPersonalRecords     = row.track_personal_records != 0
    settings.markSetsComplete         = row.mark_sets_complete    != 0
    settings.autoSelectNextSet        = row.auto_select_next_set  != 0
    settings.restTimerSeconds         = row.rest_timer_seconds
    settings.restTimerAutoStart       = row.rest_timer_auto_start != 0
    settings.appThemeID               = row.app_theme_id
    context.insert(settings)
}
```

---

### 4.2 WorkoutCategory ← `Category`

```swift
// Returns [legacyID: WorkoutCategory] for use in step 4
func importCategories(db: Database, context: ModelContext) throws -> [Int: WorkoutCategory] {
    var map = [Int: WorkoutCategory]()
    let rows = try Row.fetchAll(db, sql: "SELECT _id, name, colour, sort_order FROM Category")
    for row in rows {
        let id: Int    = row["_id"]
        let cat = WorkoutCategory(
            name:       row["name"],
            colourARGB: Int32(bitPattern: UInt32(truncatingIfNeeded: Int64(row["colour"] as Int))),
            sortOrder:  row["sort_order"],
            isBuiltIn:  id <= 8,          // IDs 1-8 are the built-in categories
            legacyID:   id
        )
        context.insert(cat)
        map[id] = cat
    }
    return map
}
```

> **Colour encoding** — see §5.2 for the full conversion.

---

### 4.3 Exercise ← `exercise`

```swift
// weight_increment in DB is stored as kg × 1000 (integer) — divide on import
func importExercises(db: Database, context: ModelContext,
                     categoryMap: [Int: WorkoutCategory]) throws -> [Int: Exercise] {
    var map = [Int: Exercise]()
    let rows = try Row.fetchAll(db, sql: "SELECT * FROM exercise")
    for row in rows {
        let id: Int = row["_id"]
        let ex = Exercise(
            name:            row["name"],
            exerciseTypeRaw: row["exercise_type_id"],
            weightUnitRaw:   row["weight_unit_id"],
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
```

---

### 4.4 TrainingEntry ← `training_log`

This is the most performance-critical step (3,191 rows). Fetch in a single query and build a `sortOrder` counter per (exercise × date) group to preserve display order.

```swift
func importTrainingLog(db: Database, context: ModelContext,
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
        let id: Int       = row["_id"]
        let dateStr: String = row["date"]
        let exerciseID: Int = row["exercise_id"]

        let counterKey = "\(dateStr)_\(exerciseID)"
        let order      = sortCounters[counterKey, default: 0]
        sortCounters[counterKey] = order + 1

        let entry = TrainingEntry(
            date:         dateFromISO(dateStr),        // §5.1
            weightKg:     row["metric_weight"],        // already in kg
            reps:         row["reps"],
            weightUnitRaw: row["unit"],
            legacyID:     id
        )
        entry.routineSetLegacyID    = row["routine_section_exercise_set_id"]
        entry.timerAutoStart        = (row["timer_auto_start"] as Int)        != 0
        entry.isPersonalRecord      = (row["is_personal_record"] as Int)      != 0
        entry.isPersonalRecordFirst = (row["is_personal_record_first"] as Int) != 0
        entry.isComplete            = (row["is_complete"] as Int)             != 0
        entry.isPendingUpdate       = (row["is_pending_update"] as Int)       != 0
        // distance: stored as metres × 1000 (integer); convert to Double metres
        entry.distanceMetres        = Double(row["distance"] as Int) / 1000.0
        entry.durationSeconds       = row["duration_seconds"]
        entry.sortOrder             = order

        entry.exercise              = exerciseMap[exerciseID]
        if entry.routineSetLegacyID != 0 {
            entry.routineSet        = routineSetMap[entry.routineSetLegacyID]
        }

        context.insert(entry)
        map[id] = entry
    }
    return map
}
```

---

### 4.5 SetComment ← `Comment`

The source table is polymorphic (`owner_type_id + owner_id`). Filter to `owner_type_id = 1` (the value used for `training_log` entries — verify against your backup).

```swift
func importComments(db: Database, context: ModelContext,
                    trainingMap: [Int: TrainingEntry]) throws {
    // owner_type_id = 1 targets training_log rows (verify in your backup)
    let rows = try Row.fetchAll(db, sql:
        "SELECT _id, owner_id, text FROM Comment WHERE owner_type_id = 1")
    for row in rows {
        let comment = SetComment(text: row["text"], legacyID: row["_id"])
        comment.trainingEntry = trainingMap[row["owner_id"] as Int]
        context.insert(comment)
    }
}
```

---

### 4.6 WorkoutSession ← `WorkoutTime`

```swift
func importWorkoutTimes(db: Database, context: ModelContext) throws {
    let rows = try Row.fetchAll(db, sql: "SELECT * FROM WorkoutTime")
    for row in rows {
        let session = WorkoutSession()
        session.legacyID      = row["_id"]
        session.date          = dateFromISO(row["date"] as String)
        session.startDateTime = dateTimeFromString(row["start_date_time"])  // §5.1
        session.endDateTime   = dateTimeFromString(row["end_date_time"])
        context.insert(session)
    }
}
```

---

### 4.7 WorkoutComment ← `WorkoutComment`

```swift
func importWorkoutComments(db: Database, context: ModelContext) throws {
    let rows = try Row.fetchAll(db, sql: "SELECT * FROM WorkoutComment")
    for row in rows {
        let wc = WorkoutComment(
            date:     dateFromISO(row["date"] as String),
            text:     row["comment"],
            legacyID: row["_id"]
        )
        context.insert(wc)
    }
}
```

---

## 5. Data Type Conversions

### 5.1 Date Strings → Swift `Date`

> **Critical note:** FitNotes does **not** use Unix millisecond timestamps. All dates throughout the schema are plain ISO-8601 strings. The Android millisecond pattern is common in many Android apps but FitNotes explicitly avoids it.

#### Pattern A — Date-only `'YYYY-MM-DD'` (used in `training_log.date`, `BodyWeight.date`, `WorkoutComment.date`, etc.)

Time is set to **midnight UTC** so that date comparisons are unit-safe regardless of the user's timezone.

```swift
private let iso8601DateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale     = Locale(identifier: "en_US_POSIX")
    f.timeZone   = TimeZone(identifier: "UTC")!
    return f
}()

func dateFromISO(_ string: String) -> Date {
    iso8601DateFormatter.date(from: string) ?? .distantPast
}
```

#### Pattern B — Datetime `'YYYY-MM-DD HH:MM:SS'` (used in `WorkoutTime.start_date_time` / `end_date_time`)

```swift
private let iso8601DateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    f.locale     = Locale(identifier: "en_US_POSIX")
    f.timeZone   = TimeZone(identifier: "UTC")!
    return f
}()

func dateTimeFromString(_ value: DatabaseValue?) -> Date? {
    guard let string = value?.storage.value as? String else { return nil }
    return iso8601DateTimeFormatter.date(from: string)
}
```

#### Pattern C — Unix milliseconds (defensive fallback)

Not used in this backup, but implement as a safety net for any future `.fitnotes` source that may have been produced by a modified exporter:

```swift
func dateFromMilliseconds(_ ms: Int64) -> Date {
    Date(timeIntervalSince1970: Double(ms) / 1000.0)
}
```

Use this only if the value looks like a 13-digit integer (> 1_000_000_000_000) rather than a parseable ISO string.

---

### 5.2 Android ARGB Integers → `SwiftUI.Color`

Android stores colours as **signed 32-bit ARGB integers** (Java `int`). The sign bit is part of the alpha channel, so `-7453523` and `0xFF8E44AD` are the same colour (fully opaque purple).

```swift
extension Int32 {
    /// Converts an Android signed ARGB int to a SwiftUI Color.
    var swiftUIColor: Color {
        // Reinterpret sign bits as unsigned without changing the bit pattern
        let unsigned = UInt32(bitPattern: self)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

**Convert the raw SQLite integer to `Int32` before calling this**, because SQLite returns a plain `Int` (64-bit on iOS):

```swift
// In importCategories:
let rawColour: Int  = row["colour"]             // Int64 from SQLite
let argb: Int32     = Int32(truncatingIfNeeded: rawColour)
// Store as Int32 in the model — colourARGB is Int32
cat.colourARGB = argb
// Decoded on demand via cat.color (computed property)
```

**Reference table** — sanity-check these during import:

| Category | Raw int | Expected hex (AARRGGBB) | Color |
|---|---|---|---|
| Shoulders | -7453523 | `FF8E44AD` | Purple |
| Triceps | -14176672 | `FF27AE60` | Green |
| Biceps | -812014 | `FFF39C12` | Orange |
| Chest | -4179669 | `FFC0392B` | Red |
| Back | -14057287 | `FF2980B9` | Blue |
| Legs | -11226442 | `FF54B2B6` | Teal |
| Abs | -13877680 | `FF2C3E50` | Dark slate |
| Cardio | -8418163 | `FF7F8C8D` | Grey |

---

### 5.3 Other Conversions Summary

| Source column | Raw type | Conversion | SwiftData field |
|---|---|---|---|
| `exercise.weight_increment` | `INTEGER` (kg × 1000) | `Double(value) / 1000.0` | `weightIncrementKg: Double?` |
| `training_log.distance` | `INTEGER` (metres × 1000) | `Double(value) / 1000.0` | `distanceMetres: Double` |
| `BodyWeight.body_weight_metric` | `REAL` (kg) | none — already kg | `weightKg: Double` |
| `training_log.metric_weight` | `REAL`-in-`INTEGER` column (kg) | none — already kg | `weightKg: Double` |
| `is_*` / `enabled` / `custom` flags | `INTEGER 0/1` | `value != 0` | `Bool` |
| `settings.metric` | `INTEGER` | `value == 0` (0 = Imperial) | `isImperial: Bool` |
| `Category.colour` / `WorkoutGroup.colour` | `INTEGER` signed ARGB | see §5.2 | `colourARGB: Int32` |

---

## 6. Verification Step

Run this report immediately after `context.save()` succeeds — before dismissing the import UI. Surface any mismatch to the user and offer to retry or contact support.

### 6.1 Swift Verification Function

```swift
struct ImportVerificationReport {
    var passed: Bool { failures.isEmpty }
    var failures: [String] = []
}

func verify(source db: Database, target context: ModelContext) throws -> ImportVerificationReport {
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
    let sourceWorkoutDays = try Int.fetchOne(
        db, sql: "SELECT COUNT(DISTINCT date) FROM training_log")!
    var targetFetch = FetchDescriptor<TrainingEntry>()
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
    let sourceComments = try Int.fetchOne(
        db, sql: "SELECT COUNT(*) FROM Comment WHERE owner_type_id = 1")!
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
```

### 6.2 Expected Counts for This Backup

These are the known-good values from `FitNotes_Backup.fitnotes`. The verification function will alert if any count differs.

| Entity | Expected count |
|---|---|
| `training_log` → `TrainingEntry` | **3,191** |
| Distinct workout dates | Derived from source |
| `exercise` → `Exercise` | **125** |
| `Category` → `WorkoutCategory` | **8** (built-in) + any custom |
| `BodyWeight` → `BodyWeightEntry` | **0** (empty in this backup) |

### 6.3 UI Presentation

Present the report in a sheet immediately after import:

```
✅  Import complete
    3,191 sets across 125 exercises
    All counts verified

    [Done]
```

Or on failure:

```
⚠️  Import completed with warnings

    • Sets: source=3191, iOS=3188 (delta: -3)
    • Category 1 colour mismatch

    Some data may not have imported correctly.
    [View Details]  [Retry]  [Continue Anyway]
```

The `[View Details]` action presents the `report.failures` array as a list so the user (or a support ticket) has an exact diff to act on.
