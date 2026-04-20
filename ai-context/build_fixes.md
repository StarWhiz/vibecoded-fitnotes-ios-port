# FitNotes iOS — Build & Compilation Fixes

**Date:** 2026-04-19  
**Status:** Complete — BUILD SUCCEEDED, app running on device  
**Focus:** Getting the Phase 1–5 source files to compile and run

---

## Overview

All Swift source files were written during Phases 1–5 but the Xcode project hadn't been fully configured. This session fixed every compilation error and several runtime issues discovered during first launch.

---

## 1. Xcode Project Setup

### Problem
The `.xcodeproj` was missing file references for 15 source files. Files in `Intents/` and `LiveActivity/` were on disk but not included in any build target.

### Fix
Used the Ruby `xcodeproj` gem (`gem install xcodeproj --user-install`) to programmatically add missing files to the main app target's Sources build phase. XcodeGen was not installed and Homebrew was unavailable.

**Files added to xcodeproj:**
- `Intents/GymFocusFilter.swift`
- `Intents/FitNotesShortcuts.swift`
- `Intents/StartWorkoutIntent.swift`
- `Intents/LogSetIntent.swift`
- `Intents/StartRestTimerIntent.swift`
- `Intents/ExerciseStatusIntent.swift`
- `Intents/OneRMIntent.swift`
- `LiveActivity/RestTimerAttributes.swift`
- `Services/AppGroup.swift`

---

## 2. SwiftData `@Relationship` Circular Macro Expansion

### Problem
The most pervasive error: "Circular reference resolving attached macro 'Relationship'" in multiple model files.

### Root Cause
SwiftData's `@Relationship` macro auto-discovers its inverse by scanning the other model's properties. When **both sides** of a bidirectional relationship declare `@Relationship`, the macro expander for side A scans side B, which triggers macro expansion for side B, which scans side A — an infinite cycle.

This applies even when the child side has NO explicit `inverse:` parameter. The macro still tries to infer the inverse automatically.

### Rule (critical for future edits)
**Only one side of a bidirectional relationship should have `@Relationship`.**

- The **parent/has-many** side keeps `@Relationship(deleteRule: .X, inverse: \ChildType.backRef)`
- The **child/back-pointer** side uses a plain `var backRef: ParentType?` — NO `@Relationship` macro

### Files Fixed

| File | Property removed `@Relationship` from |
|------|---------------------------------------|
| `Models/Exercise.swift` | `category` |
| `Models/TrainingEntry.swift` | `exercise`, `workoutGroup`, `routineSet` |
| `Models/SetComment.swift` | `trainingEntry` |
| `Models/Goal.swift` | `exercise` |
| `Models/ExerciseGraphFavourite.swift` | `exercise` |
| `Models/RepMaxGridFavourite.swift` | `primaryExercise`, `secondaryExercise` |
| `Models/RoutineSectionExercise.swift` | `section`, `exercise` |
| `Models/RoutineSectionExerciseSet.swift` | `sectionExercise` |
| `Models/RoutineSection.swift` | `routine` |
| `Models/MeasurementRecord.swift` | `measurement` |

The cascade side always retains its declaration. Examples:
```swift
// Exercise.swift — KEEP (parent side, has inverse:)
@Relationship(deleteRule: .cascade, inverse: \TrainingEntry.exercise)
var trainingEntries: [TrainingEntry] = []

// TrainingEntry.swift — plain var, NO @Relationship (child side)
var exercise: Exercise?
```

---

## 3. Actor Isolation vs GRDB Synchronous Closures

### Problem
`SQLiteImporter` was declared as `actor`. GRDB's `db.read { }` closure is synchronous and non-isolated; calling `actor`-isolated methods from inside it is a compiler error.

### Fix
Changed `actor SQLiteImporter` → `final class SQLiteImporter` and `importBackup() async throws` → `importBackup() throws`.

---

## 4. `GymFocusFilter` — `SetFocusFilterIntent` Conformance

### Problem
`SetFocusFilterIntent` requires `InstanceDisplayRepresentable` conformance and all `@Parameter` properties must be optional.

### Fix
- Added `typeDisplayRepresentation` and `displayRepresentation` computed properties
- Changed `isWorkoutActive: Bool` → `isWorkoutActive: Bool?`
- Updated all callers: `intent.isWorkoutActive = true` → `intent.isWorkoutActive = .some(true)`

---

## 5. App Intents Phrase Interpolation

### Problem
`FitNotesShortcuts.swift` used `String`-typed parameter interpolation in Siri phrases (e.g., `\(\.$weight)`). Only `AppEntity` and `AppEnum` types are allowed in phrase interpolation. Also: a single phrase cannot interpolate two dynamic parameters.

### Fix
Removed all dynamic parameter interpolation from phrases. Kept only `.applicationName` references.

---

## 6. `ImportVerificationReport` Redeclared

### Problem
The struct was defined in both `SQLiteImporter.swift` and `ImportVerificationView.swift`.

### Fix
Merged both definitions into `SQLiteImporter.swift` (adding `warnings` field and all count statistics). Removed the duplicate from the view file.

---

## 7. `ForEach` with `.enumerated()` in SwiftUI

### Problem
SwiftUI `ForEach` closure does not support tuple destructuring in the parameter list:
```swift
// WRONG — compiler error
ForEach(Array(items.enumerated()), id: \.offset) { index, item in ... }
```

### Fix
```swift
// CORRECT
ForEach(Array(items.enumerated()), id: \.offset) { item in
    // use item.offset and item.element
}
```

---

## 8. `#Preview` with Imperative Code

### Problem
`#Preview` closures are `@ViewBuilder`; imperative `var` assignments and explicit `return` statements are invalid inside them.

### Fix
Wrapped multi-line report construction in immediately-invoked closures:
```swift
#Preview("Title") {
    MyView(data: {
        var r = MyStruct()
        r.field = 42
        return r
    }())
}
```

---

## 9. `AppGroup` Missing

### Problem
`CloudSyncManager.swift` and several Intent files referenced `AppGroup` (shared container) but no such type was defined.

### Fix
Created `Services/AppGroup.swift` with:
- `AppGroup.identifier` — App Group bundle ID
- `AppGroup.containerURL` — shared container URL with fallback
- `AppGroup.makeModelContainer()` — builds a `ModelContainer` for use in widgets/intents

---

## 10. First-Launch Data Seeding

### Problem
On a fresh install SwiftData is empty — no categories, no settings. The home screen showed nothing useful.

### Fix
Added `seedBuiltInDataIfNeeded(context:)` in `FitNotesApp.swift`, called once in `.task`. Seeds:
- 8 built-in `WorkoutCategory` objects (Shoulders, Triceps, Biceps, Chest, Back, Legs, Abs, Cardio) with correct Android ARGB colours from `database_discovery.md`
- 1 default `AppSettings` row
- Guard: `fetchCount == 0` so it only runs once

---

## 11. Empty Exercise Library UX

### Problem
On first launch (no exercises imported yet), `ExercisePickerView` showed a blank list with no way to create exercises. The "New Exercise" button was buried inside a filter menu.

### Fix
Added three-state display in `ExercisePickerView`:
1. **No exercises at all** → `ContentUnavailableView` ("No Exercises Yet") with a prominent "Create Exercise" button
2. **Search returns nothing** → `ContentUnavailableView.search(text:)`
3. **Normal** → grouped list

Moved the `+` button to a permanent toolbar position (always visible, not behind the filter menu).

---

## 12. Compiler Warnings Fixed

| File | Warning | Fix |
|------|---------|-----|
| `Import/SQLiteImporter.swift` | `wgeRows` assigned but never used | Removed dead `Row.fetchAll` call |
| `Import/SQLiteImporter.swift` | `targetFetch` never mutated | Changed `var` → `let` |
| `Services/HealthKitManager.swift` | `metadata` defined but never consumed | Added `builder.addMetadata(metadata)` before `finishWorkout()` |
| `Views/TrainingView.swift` | `endsAt` captured in pattern but unused | Replaced `let endsAt` with `_` |

---

## Known Non-Issues (safe to ignore)

| Console message | Cause | Action |
|----------------|-------|--------|
| `CHHapticPattern hapticpatternlibrary.plist` errors | iOS Simulator has no Taptic Engine hardware | None — won't appear on device |
| `CoreData: Recovery attempt was successful` | Background SwiftData migration notice | None — not a real failure |
| `NSLayoutConstraint` conflicts (`_UIRemoteKeyboardPlaceholderView`) | Internal UIKit keyboard bridge bug in Apple's own code | None — not fixable from app code, iOS self-recovers |
| `LazyVGridLayout: ID used by multiple child views` | System-level SwiftUI grid ID warning | None — layout still correct |

---

## Current State

- **BUILD SUCCEEDED** — zero errors, four warnings addressed
- App launches and seeds 8 categories on first install
- Exercise picker shows correct empty state with create button
- Last session's weight + reps auto-fill when revisiting an exercise
- All SwiftData models correctly configured (one-sided `@Relationship` pattern)
- Widget extension target (`Widget/`) — files exist on disk but are not yet added to a widget extension target in xcodeproj. Rest timer Live Activity will not function until that target is created.
