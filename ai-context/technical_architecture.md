# FitNotes iOS — Technical Architecture

**Phase:** 3 — Technical Architecture  
**Date:** 2026-04-13  
**Target:** iOS 17+ · SwiftUI · SwiftData · Observation framework

---

## Table of Contents

1. [Project Foundation](#1-project-foundation)
2. [Layer Architecture](#2-layer-architecture)
3. [Enums and Value Types](#3-enums-and-value-types)
4. [SwiftData Model Classes](#4-swiftdata-model-classes)
5. [Android-ism Handling](#5-android-ism-handling)
6. [State Management Strategy](#6-state-management-strategy)
7. [Import Pipeline](#7-import-pipeline)
8. [Schema Gap Resolutions](#8-schema-gap-resolutions)

---

## 1. Project Foundation

| Concern | Decision |
|---|---|
| **Min iOS** | 17.0 (required for SwiftData + Observation) |
| **UI** | SwiftUI throughout |
| **Persistence** | SwiftData (`@Model`, `ModelContainer`, `ModelContext`) |
| **Reactive state** | Swift Observation framework (`@Observable`) — no Combine |
| **Concurrency** | Swift structured concurrency (`async/await`, `Actor`) |
| **Unit system** | Always store in **kg** internally; convert to lbs for display |
| **Date storage** | `Date` in SwiftData (bridged from `'YYYY-MM-DD'` TEXT on import) |
| **Colour storage** | `Int32` (Android signed ARGB); decoded to `Color` via computed property |

---

## 2. Layer Architecture

```
┌─────────────────────────────────────────────────┐
│  UI Layer (SwiftUI Views)                        │
│  @Query for history · @Environment for stores    │
├─────────────────────────────────────────────────┤
│  State Layer (Swift Observation)                 │
│  ActiveWorkoutStore · RestTimerStore             │
│  AppSettingsStore (single-source for settings)   │
├─────────────────────────────────────────────────┤
│  Domain Services (pure Swift, async)             │
│  PRCalculator · OneRMCalculator                  │
│  PlateCalculator · WorkoutShareFormatter         │
├─────────────────────────────────────────────────┤
│  Persistence Layer (SwiftData)                   │
│  ModelContainer · ModelContext                   │
│  All @Model classes below                        │
├─────────────────────────────────────────────────┤
│  Import Layer (one-time / on demand)             │
│  SQLiteImporter → ModelContext inserts           │
└─────────────────────────────────────────────────┘
```

### Environment injection (root of app)

```swift
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
    @State private var timerStore   = RestTimerStore()
    @State private var settingsStore = AppSettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(workoutStore)
                .environment(timerStore)
                .environment(settingsStore)
        }
    }
}
```

---

## 3. Enums and Value Types

### ExerciseType

```swift
enum ExerciseType: Int, Codable, CaseIterable {
    case weightReps = 0   // Standard barbell / dumbbell / machine
    case cardio     = 1   // Distance + duration
    case timed      = 3   // Isometric / plank — duration only
    // Note: value 2 is unobserved in backup; reserved in app
    // Premium types (not in backup) handled by .unknown on import
    case unknown    = -1

    init(rawValue: Int) {
        switch rawValue {
        case 0: self = .weightReps
        case 1: self = .cardio
        case 3: self = .timed
        default: self = .unknown
        }
    }

    var usesWeight: Bool    { self == .weightReps }
    var usesDistance: Bool  { self == .cardio }
    var usesDuration: Bool  { self == .cardio || self == .timed }
    var usesReps: Bool      { self == .weightReps }
}
```

### WeightUnit

```swift
enum WeightUnit: Int, Codable {
    case kilograms = 0
    case pounds    = 2
    // Value 1 observed in exercise.weight_unit_id but semantics unclear — treat as kg
    case unknown   = 1

    var symbol: String { self == .pounds ? "lbs" : "kg" }
    var toKgFactor: Double { self == .pounds ? 1.0 / 2.20462 : 1.0 }
    var fromKgFactor: Double { self == .pounds ? 2.20462 : 1.0 }
}
```

### GoalType

```swift
enum GoalType: Int, Codable {
    case increase = 0
    case decrease = 1
    case specific = 2
}
```

### RestTimerState (value type, not persisted)

```swift
enum RestTimerState: Equatable {
    case idle
    case running(endsAt: Date, totalSeconds: Int, exerciseName: String)
    case expired(exerciseName: String)

    var isActive: Bool {
        if case .running = self { return true }
        return false
    }
}
```

---

## 4. SwiftData Model Classes

> **Naming conventions:**
> - `legacyID: Int` — stores the original SQLite `_id` for FK resolution during import. Not used after import completes.
> - All colour properties are `Int32` (Android signed ARGB). Decoded via `Color` computed properties.
> - All weights are stored in **kg** as `Double`.

---

### 4.1 AppSettings

Maps to `settings` (always a single row, `_id = 1`).

```swift
@Model final class AppSettings {
    // Unit system
    var isImperial: Bool                  // settings.metric == 0

    // Calendar
    var firstDayOfWeek: Int              // 0 = Sunday, 1 = Monday

    // Increments (stored in kg)
    var defaultWeightIncrementKg: Double  // settings.weight_increment
    var bodyWeightIncrementKg: Double     // settings.body_weight_increment

    // Behaviour flags
    var trackPersonalRecords: Bool
    var markSetsComplete: Bool
    var autoSelectNextSet: Bool

    // Rest timer
    var restTimerSeconds: Int
    var restTimerAutoStart: Bool

    // Theme (iOS mapping: 0=system, 1=light, 2=dark)
    var appThemeID: Int

    init() {
        isImperial               = true
        firstDayOfWeek           = 1
        defaultWeightIncrementKg = 1.13398  // ≈ 2.5 lbs
        bodyWeightIncrementKg    = 0.1
        trackPersonalRecords     = true
        markSetsComplete         = true
        autoSelectNextSet        = true
        restTimerSeconds         = 120
        restTimerAutoStart       = true
        appThemeID               = 0
    }
}
```

---

### 4.2 WorkoutCategory

Maps to `Category`. Named `WorkoutCategory` to avoid Swift keyword conflict.

```swift
@Model final class WorkoutCategory {
    var name: String
    var colourARGB: Int32    // Android signed ARGB int
    var sortOrder: Int
    var isBuiltIn: Bool      // iOS addition: prevents deletion of the 8 default categories
    var legacyID: Int        // original Category._id (used during import only)

    @Relationship(deleteRule: .nullify, inverse: \Exercise.category)
    var exercises: [Exercise] = []

    // MARK: - Computed
    var color: Color {
        // Android signed 32-bit ARGB → SwiftUI Color
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(name: String, colourARGB: Int32, sortOrder: Int, isBuiltIn: Bool, legacyID: Int = 0) {
        self.name       = name
        self.colourARGB = colourARGB
        self.sortOrder  = sortOrder
        self.isBuiltIn  = isBuiltIn
        self.legacyID   = legacyID
    }
}
```

---

### 4.3 Exercise

Maps to `exercise`.

```swift
@Model final class Exercise {
    var name: String
    var exerciseTypeRaw: Int         // ExerciseType.rawValue
    var notes: String?
    var weightIncrementKg: Double?   // per-exercise override (legacy: kg × 1000 → divide on import)
    var defaultGraphID: Int?         // which graph metric is default
    var defaultRestTimeSeconds: Int? // per-exercise rest override
    var weightUnitRaw: Int           // WeightUnit.rawValue
    var isFavourite: Bool            // exercise.is_favourite
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var category: WorkoutCategory?

    @Relationship(deleteRule: .cascade, inverse: \TrainingEntry.exercise)
    var trainingEntries: [TrainingEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.exercise)
    var goals: [Goal] = []

    @Relationship(deleteRule: .cascade, inverse: \ExerciseGraphFavourite.exercise)
    var graphFavourites: [ExerciseGraphFavourite] = []

    @Relationship(deleteRule: .cascade, inverse: \RepMaxGridFavourite.primaryExercise)
    var repMaxGridFavourites: [RepMaxGridFavourite] = []

    // MARK: - Computed
    var exerciseType: ExerciseType { ExerciseType(rawValue: exerciseTypeRaw) }
    var weightUnit: WeightUnit     { WeightUnit(rawValue: weightUnitRaw) ?? .kilograms }

    init(name: String, exerciseTypeRaw: Int = 0, weightUnitRaw: Int = 0,
         isFavourite: Bool = false, legacyID: Int = 0) {
        self.name            = name
        self.exerciseTypeRaw = exerciseTypeRaw
        self.weightUnitRaw   = weightUnitRaw
        self.isFavourite     = isFavourite
        self.legacyID        = legacyID
    }
}
```

---

### 4.4 TrainingEntry

Maps to `training_log`. Each row is one logged **set**.

```swift
@Model final class TrainingEntry {
    var date: Date               // Converted from 'YYYY-MM-DD' text; time component = midnight UTC
    var weightKg: Double         // ALWAYS kg. Legacy: metric_weight REAL stored as kg
    var reps: Int
    var weightUnitRaw: Int       // Display unit for this set (0=kg, 2=lbs)
    var routineSetLegacyID: Int  // 0 = ad-hoc; non-zero links to RoutineSectionExerciseSet
    var timerAutoStart: Bool
    var isPersonalRecord: Bool
    var isPersonalRecordFirst: Bool
    var isComplete: Bool
    var isPendingUpdate: Bool
    var distanceMetres: Double   // cardio: metres. Legacy stores metres × 1000 — divide on import
    var durationSeconds: Int     // cardio / timed exercises
    var sortOrder: Int           // iOS addition: explicit display order of exercises within a day
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetComment.trainingEntry)
    var comment: SetComment?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutGroup.entries)
    var workoutGroup: WorkoutGroup?

    @Relationship(deleteRule: .nullify, inverse: \RoutineSectionExerciseSet.loggedEntries)
    var routineSet: RoutineSectionExerciseSet?

    // MARK: - Computed display helpers
    var weightLbs: Double { weightKg * 2.20462 }

    /// Returns the weight in the user's preferred unit given an AppSettings reference.
    func displayWeight(isImperial: Bool) -> Double {
        isImperial ? weightLbs : weightKg
    }

    var volume: Double { weightKg * Double(reps) }  // in kg; convert at display site

    var estimatedOneRepMaxKg: Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        if reps == 1 { return weightKg }
        // Epley formula: w × (1 + r/30)
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    init(date: Date, weightKg: Double = 0, reps: Int = 0,
         weightUnitRaw: Int = 2, legacyID: Int = 0) {
        self.date            = date
        self.weightKg        = weightKg
        self.reps            = reps
        self.weightUnitRaw   = weightUnitRaw
        self.routineSetLegacyID = 0
        self.timerAutoStart  = false
        self.isPersonalRecord      = false
        self.isPersonalRecordFirst = false
        self.isComplete      = false
        self.isPendingUpdate = false
        self.distanceMetres  = 0
        self.durationSeconds = 0
        self.sortOrder       = 0
        self.legacyID        = legacyID
    }
}
```

---

### 4.5 SetComment

Flattened from the polymorphic `Comment` table. The original uses `owner_type_id + owner_id`; iOS uses a direct SwiftData relationship instead.

```swift
@Model final class SetComment {
    var text: String
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var trainingEntry: TrainingEntry?

    init(text: String, legacyID: Int = 0) {
        self.text     = text
        self.legacyID = legacyID
    }
}
```

---

### 4.6 WorkoutComment

Maps to `WorkoutComment` — free-text note for an entire training day.

```swift
@Model final class WorkoutComment {
    var date: Date   // one comment per date
    var text: String
    var legacyID: Int

    init(date: Date, text: String, legacyID: Int = 0) {
        self.date     = date
        self.text     = text
        self.legacyID = legacyID
    }
}
```

---

### 4.7 WorkoutGroup

Maps to `WorkoutGroup`. Groups exercises into a superset / circuit for a given day.

```swift
@Model final class WorkoutGroup {
    var name: String?
    var colourARGB: Int32   // Android signed ARGB — same decoding as WorkoutCategory.color
    var date: Date
    var legacyID: Int

    @Relationship(deleteRule: .nullify, inverse: \TrainingEntry.workoutGroup)
    var entries: [TrainingEntry] = []

    var color: Color {
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

---

### 4.8 WorkoutSession

Maps to `WorkoutTime`. Renamed to avoid conflict with HealthKit's `HKWorkout`.

```swift
@Model final class WorkoutSession {
    var date: Date
    var startDateTime: Date?
    var endDateTime: Date?
    var legacyID: Int

    var duration: TimeInterval? {
        guard let start = startDateTime, let end = endDateTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var isActive: Bool { startDateTime != nil && endDateTime == nil }
}
```

---

### 4.9 Goal

Maps to `Goal`.

```swift
@Model final class Goal {
    var goalTypeRaw: Int      // GoalType.rawValue
    var targetValue: Double
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var goalType: GoalType { GoalType(rawValue: goalTypeRaw) ?? .increase }
}
```

---

### 4.10 BodyWeightEntry

Maps to `BodyWeight`. Always stored in kg; convert for display.

```swift
@Model final class BodyWeightEntry {
    var date: Date
    var weightKg: Double       // BodyWeight.body_weight_metric — always kg
    var bodyFatPercent: Double // 0.0 if not tracked
    var comment: String?
    var legacyID: Int

    var weightLbs: Double { weightKg * 2.20462 }

    func displayWeight(isImperial: Bool) -> Double {
        isImperial ? weightLbs : weightKg
    }
}
```

---

### 4.11 Measurement + MeasurementRecord

```swift
@Model final class Measurement {
    var name: String
    var unitID: Int            // FK → MeasurementUnit.legacyID
    var goalTypeRaw: Int
    var goalValue: Double
    var isCustom: Bool         // 0=built-in, 1=user-created
    var isEnabled: Bool
    var sortOrder: Int
    var legacyID: Int

    @Relationship(deleteRule: .cascade, inverse: \MeasurementRecord.measurement)
    var records: [MeasurementRecord] = []

    @Relationship(deleteRule: .nullify)
    var unit: MeasurementUnit?
}

@Model final class MeasurementRecord {
    var recordedAt: Date    // Combines legacy 'date' + 'time' fields on import
    var value: Double
    var comment: String?
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var measurement: Measurement?
}

@Model final class MeasurementUnit {
    var typeRaw: Int           // 0=none, 1=weight, 2=length, 3=percent
    var longName: String
    var shortName: String
    var isCustom: Bool         // iOS addition — gap fix: MeasurementUnit had no custom flag
    var legacyID: Int
}
```

---

### 4.12 Barbell + Plate

```swift
@Model final class Barbell {
    var name: String?
    var weightKg: Double
    var legacyID: Int
}

@Model final class Plate {
    var weightKg: Double
    var count: Int
    var colourARGB: Int32
    var widthMm: Double?
    var diameterMm: Double?
    var isAvailable: Bool    // whether the plate is in the current loadout
    var legacyID: Int

    var color: Color {
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

---

### 4.13 Routine Hierarchy

```
Routine → RoutineSection → RoutineSectionExercise → RoutineSectionExerciseSet
                                                            ↓
                                                     TrainingEntry (logged sets)
```

```swift
@Model final class Routine {
    var name: String
    var legacyID: Int

    @Relationship(deleteRule: .cascade, inverse: \RoutineSection.routine)
    var sections: [RoutineSection] = []
}

@Model final class RoutineSection {
    var name: String
    var sortOrder: Int
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineSectionExercise.section)
    var exercises: [RoutineSectionExercise] = []
}

@Model final class RoutineSectionExercise {
    var populateSetsTypeRaw: Int   // 0 = use planned sets as-is
    var sortOrder: Int
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var section: RoutineSection?

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \RoutineSectionExerciseSet.sectionExercise)
    var plannedSets: [RoutineSectionExerciseSet] = []
}

@Model final class RoutineSectionExerciseSet {
    var weightKg: Double
    var reps: Int
    var weightUnitRaw: Int
    var distanceMetres: Double
    var durationSeconds: Int
    var sortOrder: Int
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var sectionExercise: RoutineSectionExercise?

    // Back-link: which live entries originated from this planned set
    @Relationship(deleteRule: .nullify, inverse: \TrainingEntry.routineSet)
    var loggedEntries: [TrainingEntry] = []
}
```

---

### 4.14 Favourites

```swift
@Model final class ExerciseGraphFavourite {
    var graphMetricRaw: Int   // which graph metric is pinned
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?
}

// Schema partially documented; stored defensively.
@Model final class RepMaxGridFavourite {
    var primaryExerciseLegacyID: Int    // stored for post-import resolution
    var secondaryExerciseLegacyID: Int  // 0 if single-exercise grid
    var legacyID: Int

    @Relationship(deleteRule: .nullify)
    var primaryExercise: Exercise?

    @Relationship(deleteRule: .nullify)
    var secondaryExercise: Exercise?
}
```

---

## 5. Android-ism Handling

All conversions are centralised — never scattered in views.

### 5.1 Weight (kg storage → lbs display)

```swift
// Always: store kg. Display via:
extension TrainingEntry {
    func displayWeight(settings: AppSettings) -> Double {
        settings.isImperial ? weightKg * 2.20462 : weightKg
    }
}
// Same pattern on BodyWeightEntry, RoutineSectionExerciseSet, AppSettings.defaultWeightIncrementKg
```

### 5.2 Distance (metres × 1000 → metres)

```swift
// In SQLiteImporter:
entry.distanceMetres = Double(row.distanceLegacy) / 1000.0
```

### 5.3 Colour (Android ARGB int32 → SwiftUI Color)

```swift
// Centralised decoder — used by WorkoutCategory, WorkoutGroup, Plate:
extension Int32 {
    var androidARGBColor: Color {
        let u = UInt32(bitPattern: self)
        return Color(
            .sRGB,
            red:     Double((u >> 16) & 0xFF) / 255.0,
            green:   Double((u >>  8) & 0xFF) / 255.0,
            blue:    Double( u        & 0xFF) / 255.0,
            opacity: Double((u >> 24) & 0xFF) / 255.0
        )
    }
}
```

### 5.4 Date (TEXT 'YYYY-MM-DD' → Date)

```swift
extension String {
    static let fitnotesDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat    = "yyyy-MM-dd"
        f.timeZone      = TimeZone(identifier: "UTC")
        f.locale        = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var fitnotesDate: Date? { Self.fitnotesDateFormatter.date(from: self) }
}
```

### 5.5 Boolean (INTEGER 0/1 → Bool)

```swift
// In SQLiteImporter — no special extension needed; just:
entry.isComplete = row.isComplete != 0
```

### 5.6 weight_increment encoding (kg × 1000 integer)

```swift
// In SQLiteImporter for exercise.weight_increment:
exercise.weightIncrementKg = row.weightIncrementRaw != nil
    ? Double(row.weightIncrementRaw!) / 1000.0
    : nil
```

---

## 6. State Management Strategy

### The Core Problem

Two fundamentally different data access patterns coexist:

| Mode | Characteristics |
|---|---|
| **Active Workout** | Mutable, fast, in-memory, UI-driven (set saves, timer, PR alerts) |
| **Historical Log** | Read-mostly, SwiftData `@Query`, potentially large |

Mixing these in one layer creates coupling between live UX responsiveness and slow DB queries.

---

### 6.1 Active Workout State — `ActiveWorkoutStore`

An `@Observable` class. Lives for the duration of the app session. Injected into the environment at the root.

```swift
@Observable final class ActiveWorkoutStore {

    // Current date being worked on (defaults to today, navigable to past for edits)
    var date: Date = Calendar.current.startOfDay(for: .now)

    // Ordered list of exercises in today's workout
    // Each wraps the exercise model + its live set list for the day
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

    // MARK: - Actions (all write to ModelContext then sync local state)
    func load(for date: Date, context: ModelContext) async { ... }
    func addExercise(_ exercise: Exercise, context: ModelContext) { ... }
    func saveSet(_ entry: TrainingEntry, context: ModelContext) throws { ... }
    func deleteSet(_ entry: TrainingEntry, context: ModelContext) throws { ... }
    func startWorkout(context: ModelContext) { ... }
    func endWorkout(context: ModelContext) { ... }
    func advanceToNextSet() { ... }         // auto_select_next_set behaviour
}

// Value type — safe to pass into SwiftUI views without triggering observation
struct ExerciseSession: Identifiable {
    var id: PersistentIdentifier   // Exercise's SwiftData identity
    var exercise: Exercise
    var sets: [TrainingEntry]      // Today's sets for this exercise, in sortOrder
    var workoutGroup: WorkoutGroup?
    var sortOrder: Int
}
```

**Why `@Observable` and NOT SwiftData `@Query` for live sets?**

`@Query` re-fetches and re-renders on every DB write, causing the entire list to rebuild during active logging. An `@Observable` store holds the live set list in memory, updates it in-place on save, and writes to SwiftData in the background — giving instant UI feedback and a persistent record.

---

### 6.2 Rest Timer State — `RestTimerStore`

Separated from `ActiveWorkoutStore` because timer state is purely ephemeral and cross-cutting (needed by the training screen, Live Activities, and lock screen widget).

```swift
@Observable final class RestTimerStore {
    var state: RestTimerState = .idle

    private var task: Task<Void, Never>? = nil

    func start(seconds: Int, exerciseName: String) {
        task?.cancel()
        let endsAt = Date.now.addingTimeInterval(Double(seconds))
        state = .running(endsAt: endsAt, totalSeconds: seconds, exerciseName: exerciseName)
        // Schedule UNTimeIntervalNotificationRequest for background alert
        scheduleNotification(seconds: seconds, exerciseName: exerciseName)
        // Start Live Activity (iOS 16.1+)
        startLiveActivity(endsAt: endsAt, exerciseName: exerciseName)
        // Drive the countdown on a background task
        task = Task { await runCountdown(until: endsAt, exerciseName: exerciseName) }
    }

    func stop() {
        task?.cancel()
        cancelNotification()
        endLiveActivity()
        state = .idle
    }

    private func runCountdown(until end: Date, exerciseName: String) async {
        while Date.now < end {
            try? await Task.sleep(for: .seconds(1))
        }
        await MainActor.run {
            state = .expired(exerciseName: exerciseName)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
```

---

### 6.3 Historical Data State — SwiftData `@Query`

Views that display historical data query SwiftData directly. No intermediate store needed.

```swift
// Calendar view — all dates with workout data
struct CalendarViewModel {
    @Query(sort: \TrainingEntry.date, order: .reverse)
    var allEntries: [TrainingEntry]
}

// History tab for a specific exercise
struct ExerciseHistoryView: View {
    let exercise: Exercise

    var body: some View {
        // Dynamic predicate built at init time
        TrainingEntryList(exercise: exercise)
    }
}

private struct TrainingEntryList: View {
    @Query private var entries: [TrainingEntry]

    init(exercise: Exercise) {
        let id = exercise.persistentModelID
        _entries = Query(
            filter: #Predicate<TrainingEntry> { $0.exercise?.persistentModelID == id },
            sort: \TrainingEntry.date,
            order: .reverse
        )
    }

    var body: some View { /* list */ }
}
```

---

### 6.4 Settings State — `AppSettingsStore`

Wraps the single `AppSettings` row. Injected into the environment so all views read the same unit preference without `@Query` boilerplate.

```swift
@Observable final class AppSettingsStore {
    private(set) var settings: AppSettings

    var isImperial: Bool {
        get { settings.isImperial }
        set { settings.isImperial = newValue }
    }

    var weightSymbol: String { isImperial ? "lbs" : "kg" }

    func kg(from display: Double) -> Double {
        isImperial ? display / 2.20462 : display
    }

    func display(kg: Double) -> Double {
        isImperial ? kg * 2.20462 : kg
    }

    init(settings: AppSettings) {
        self.settings = settings
    }
}
```

---

### 6.5 State Flow: Saving a Set

```
User taps "Save"
    │
    ▼
ActiveWorkoutStore.saveSet(entry, context)
    ├─ 1. Compute PR flags  ← PRCalculator.check(entry, allEntries: exercise.trainingEntries)
    ├─ 2. context.insert(entry)  ← persists to SwiftData
    ├─ 3. try context.save()
    ├─ 4. sessions[activeSessionIndex].sets.append(entry)  ← instant UI update
    ├─ 5. if settings.restTimerAutoStart → timerStore.start(...)
    └─ 6. if settings.autoSelectNextSet → advanceToNextSet()
```

Views observing `ActiveWorkoutStore.sessions` re-render immediately (step 4) without waiting for a round-trip `@Query` refresh.

---

### 6.6 Personal Record Calculation

A pure domain service — no stored state.

```swift
struct PRCalculator {
    /// Returns updated PR flags for a new entry given all existing entries for the same exercise.
    static func evaluate(
        newEntry: TrainingEntry,
        existingEntries: [TrainingEntry]
    ) -> (isRecord: Bool, isFirstAtThisWeight: Bool) {
        guard newEntry.reps > 0, newEntry.weightKg > 0 else { return (false, false) }
        let best1RM = existingEntries.map(\.estimatedOneRepMaxKg).max() ?? 0
        let isRecord = newEntry.estimatedOneRepMaxKg > best1RM
        if !isRecord { return (false, false) }
        let firstAtWeight = existingEntries
            .filter { $0.reps == newEntry.reps }
            .allSatisfy { $0.weightKg < newEntry.weightKg }
        return (true, firstAtWeight)
    }
}
```

---

## 7. Import Pipeline

A one-time operation that reads `FitNotes_Backup.fitnotes` and populates the SwiftData store. Runs on a background `ModelContext` to avoid blocking the UI.

```swift
actor SQLiteImporter {

    func importBackup(at url: URL, container: ModelContainer) async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let db = try Connection(url.path)

        // Phase 1: seed lookup maps (legacyID → SwiftData object)
        let categoryMap = try importCategories(db, context)
        let exerciseMap = try importExercises(db, context, categoryMap)
        let routineSetMap = try importRoutineHierarchy(db, context, exerciseMap)

        // Phase 2: bulk import training log (largest table)
        try importTrainingLog(db, context, exerciseMap, routineSetMap)

        // Phase 3: ancillary data
        try importBodyWeights(db, context)
        try importMeasurements(db, context)
        try importWorkoutGroups(db, context)  // resolves back-links after trainingLog import
        try importWorkoutSessions(db, context)
        try importWorkoutComments(db, context)
        try importSettings(db, context)
        try importPlatesAndBarbells(db, context)

        try context.save()
    }

    private func importTrainingLog(
        _ db: Connection,
        _ context: ModelContext,
        _ exerciseMap: [Int: Exercise],
        _ routineSetMap: [Int: RoutineSectionExerciseSet]
    ) throws {
        let rows = try db.prepare("SELECT * FROM training_log ORDER BY _id")
        for row in rows {
            let entry = TrainingEntry(
                date:       String(row[col_date]).fitnotesDate ?? .now,
                weightKg:   row[col_metricWeight],          // already kg REAL
                reps:       Int(row[col_reps]),
                weightUnitRaw: Int(row[col_unit]),
                legacyID:   Int(row[col_id])
            )
            entry.distanceMetres      = Double(row[col_distance]) / 1000.0
            entry.durationSeconds     = Int(row[col_durationSeconds])
            entry.isPersonalRecord    = row[col_isPR] != 0
            entry.isPersonalRecordFirst = row[col_isPRFirst] != 0
            entry.isComplete          = row[col_isComplete] != 0
            entry.routineSetLegacyID  = Int(row[col_routineSetID])

            entry.exercise    = exerciseMap[Int(row[col_exerciseID])]
            entry.routineSet  = routineSetMap[Int(row[col_routineSetID])]
            context.insert(entry)
        }
    }
}
```

---

## 8. Schema Gap Resolutions

All gaps identified in Phase 2 (`product_roadmap.md §2`) and how they are addressed in this architecture.

| Gap | Resolution |
|---|---|
| **`isFavourite` on Exercise** | `Exercise.isFavourite: Bool` — direct map from `exercise.is_favourite` |
| **Custom measurement units** | `MeasurementUnit.isCustom: Bool` — iOS addition, default `false` for seeded units |
| **Exercise display order within a day** | `TrainingEntry.sortOrder: Int` — iOS-only column, populated on save |
| **Rep Max Grid Favourite schema unknown** | `RepMaxGridFavourite` stores two exercise IDs defensively; fully resolved after reverse-engineering |
| **Set Calculator (Wendler %)** | Stateless `SetCalculatorViewModel` — no model; reads `TrainingEntry` for "Select Max" |
| **Workout Share (text)** | `WorkoutShareFormatter: (date, context) → String` — pure function, no model |
| **Workout Copy** | `ActiveWorkoutStore.copyWorkout(from:to:context:)` — INSERT SELECT pattern, no new model |
| **Auto-backup (Google Drive → iCloud)** | `BackupService` writes `.fitnotes` SQLite to iCloud Drive container; `AppSettings` tracks last backup date (in-memory only) |
| **CSV Export** | `CSVExporter.exportWorkoutLog(context:)` — pure query → file; no model |
| **Keep Screen On** | `ActiveWorkoutStore.isWorkoutActive` observed by root view → `UIApplication.shared.isIdleTimerDisabled` |
| **Light/Dark theme** | `AppSettings.appThemeID` mapped: `0→.unspecified`, `1→.light`, `2→.dark` via `preferredColorScheme` |
| **Exercise workout count / last-used date** | Computed from `exercise.trainingEntries` — no stored field |
| **Workout Panel split view** | `ActiveWorkoutStore.activePanelIsOpen: Bool` — pure UI state in store |
| **`WeightUnit` value `1` (ambiguous)** | `WeightUnit.unknown = 1` — treated as kg on display; logged on import for audit |
| **`WorkoutGroup.colour` is ARGB int** | `WorkoutGroup.colourARGB: Int32` decoded via same `androidARGBColor` extension as `WorkoutCategory` |
| **`android_metadata` table** | Skipped entirely in `SQLiteImporter` — not inserted, not modelled |
| **Built-in categories cannot be deleted** | `WorkoutCategory.isBuiltIn: Bool` — UI blocks delete action; set to `true` for the 8 seeded rows |

---

---

## Implementation Status

All sections above (1–8) are fully implemented in code. See:
- `phase1_summary.md` — Models, enums, importer (Phase 1)
- `phase4_summary.md` — Views, navigation, feature integration (Phase 4)

Stores (`ActiveWorkoutStore`, `RestTimerStore`, `AppSettingsStore`) and services (`PRCalculator`, `OneRMCalculator`, `PlateCalculator`, `WorkoutShareFormatter`) are implemented in `Stores/` and `Services/` respectively.

The UI layer in `Views/` covers all 26 product features (1.1–1.26) and follows the state management strategy defined in §6 — `@Observable` stores for live workout state, `@Query` for historical data, environment injection at the app root.
