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

## 13. Rest Timer Frozen at Starting Value

**Date:** 2026-04-19

### Problem
The rest timer banner and inline training view timer displayed the correct starting value (e.g. 120 s) but never counted down — it stayed frozen for the entire duration.

### Root Cause
`RestTimerState` is `Equatable`. The countdown `Task` never mutated the `state` property during the countdown — it only changed it once at expiry (`.expired`). An earlier attempted fix reassigned `state` to the same enum value each second, but SwiftUI's `@Observable` machinery deduplicates mutations on `Equatable` value types, so no re-renders were triggered.

### Fix
Added `private(set) var remainingSeconds: Int = 0` as a dedicated stored property on `RestTimerStore`. This is an `Int` (not `Equatable`-deduplicated in practice because the value changes every second: 120 → 119 → …). The countdown task now sets `remainingSeconds` each second via `await MainActor.run`. Views read `timerStore.remainingSeconds` directly instead of computing it from the `state` enum.

**Files changed:**
- `Stores/RestTimerStore.swift` — added `remainingSeconds`, updated `start()`, `stop()`, `addTime()`, and `runCountdown()`
- `Views/RestTimerBannerView.swift` — reads `timerStore.remainingSeconds` for countdown text and ring progress
- `Views/TrainingView.swift` — reads `timerStore.remainingSeconds` in inline rest timer section

### Rule for future edits
Never drive a per-second countdown display by reassigning the same `Equatable` enum value. Use a dedicated `Int` or `TimeInterval` stored property whose value actually changes each tick.

---

## 14. Expired Timer Banner Never Shown

### Problem
After the rest timer reached zero, the "Time's up! Dismiss" banner (`.expired` state) never appeared in the global overlay.

### Root Cause
`RestTimerState.isActive` only returned `true` for `.running`, not `.expired`. `ContentView` gates the `RestTimerBannerView` overlay on `timerStore.state.isActive`, so the expired view was always hidden.

### Fix
Changed `isActive` to return `true` for both `.running` and `.expired`:

```swift
// Stores/RestTimerState.swift
var isActive: Bool {
    switch self {
    case .idle: return false
    case .running, .expired: return true
    }
}
```

---

## 15. Weight TextField Lag (TrainingView)

### Problem
Typing in the weight field was visually laggy / stuttery.

### Root Cause
`TrainingView.body` placed a `List` (`.insetGrouped`) inside a `VStack`. Every `@State` change (including each keystroke updating `weightText`) caused SwiftUI to re-run the entire view body. With `List` embedded in a `VStack`, SwiftUI must resolve the List's intrinsic height on every pass — this involves the UITableView's layout system and is expensive even for a short list.

### Fix
Restructured `TrainingView` so `loggedSetsList` (the `List`) is the **root view** returned from `body`. The exercise header, input fields, action buttons, and rest timer section are pinned above the list via `.safeAreaInset(edge: .top)`. This gives the List a stable full-screen frame from `NavigationStack`, eliminating the layout recalculation cycle.

```swift
// Before
VStack(spacing: 0) {
    exerciseHeader; inputSection; actionButtons; restTimerSection; loggedSetsList
}

// After
Group {
    loggedSetsList
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                exerciseHeader; inputSection; actionButtons; restTimerSection
            }
            .background(.background)
        }
}
```

---

## 16. Stale Derived Data Showing Old Build Errors

### Problem
After applying model fixes, Xcode still showed `@Relationship` circular reference errors and `RestTimerAttributes not found` from files that had already been corrected. The error messages showed different line numbers than the actual on-disk source.

### Root Cause
Xcode's incremental build cache retained compiled artifacts from the pre-fix source. The compiler was expanding macros against cached intermediate files, not the current source.

### Fix
**Product → Clean Build Folder** (`Shift+Cmd+K`) in Xcode, then rebuild. No source changes required.

---

---

## 17. Timer Banner Blocking Tab Bar Navigation

**Date:** 2026-04-19

### Problem
The rest timer banner rendered over the bottom tab bar, making the navigation buttons unreachable.

### Root Cause
The banner was placed in a `ZStack` over the entire `TabView` with a fixed 50pt bottom padding. On iPhones with a home indicator the tab bar is 49pt content + 34pt home indicator = 83pt total, so the fixed padding was insufficient.

### Fix
Removed the `ZStack`. Attached the banner to each `NavigationStack` inside `TabView` via `.safeAreaInset(edge: .bottom, spacing: 0)`. This is device-agnostic — SwiftUI automatically places the inset above the tab bar on all form factors.

```swift
// ContentView.swift — same pattern for all 4 tabs
NavigationStack { HomeView() }
    .safeAreaInset(edge: .bottom, spacing: 0) { timerBanner }
    .tag(Tab.home)
    .tabItem { ... }
```

---

## 18. Rest Timer Pause / Resume / Restart

**Date:** 2026-04-19

### Addition
Added full pause/resume/restart control to the rest timer.

**`RestTimerState`** — added `.paused(remainingSeconds:totalSeconds:exerciseName:)` case; `isActive` now returns `true` for `.running`, `.paused`, and `.expired`.

**`RestTimerStore`** — added three methods:
- `pause()` — cancels the countdown task, ends Live Activity, stores remaining seconds in `.paused` state
- `resume()` — computes `endsAt = now + remainingSeconds`, restarts task and Live Activity
- `restart()` — calls `start()` with the original `totalSeconds`

**UI** — `RestTimerBannerView` and `TrainingView.restTimerSection` updated:
- Running: `+30s`, ⏸ pause, ✕ stop
- Paused: dimmed ring, ⟳ restart, ▶ resume, ✕ stop

---

## 19. Set Deletion UX

**Date:** 2026-04-19

### Problem
The only way to delete a logged set was to tap the row (selecting it), then find and tap the "Delete" button that appeared in the input area at the top of the screen — not obvious.

### Fix
Two complementary affordances added:

1. **Swipe-to-delete** (`.swipeActions(edge: .trailing, allowsFullSwipe: true)`) on every set row — standard iOS pattern, works on any row regardless of selection state.
2. **Inline trash icon** on the selected row — when a row is tapped (blue highlight), a `trash.fill` button appears at the trailing edge of that row via `onDelete` callback passed into `SetRowView`.

---

## 20. Weight TextField Lag — Deeper Fix (TrainingInputState)

**Date:** 2026-04-19

### Problem
Weight field was still sluggish after the List-root fix (§15), especially with several logged sets.

### Root Cause
All text-field `@State` (`weightText`, `repsText`, etc.) lived directly on `TrainingView`. In SwiftUI, any `@State` mutation causes the containing view's `body` to re-evaluate. That re-evaluation rebuilds `loggedSetsList`, calling `Array(session.sets.enumerated())` on every keystroke — O(n) SwiftData relationship access even though the list itself didn't change.

### Fix
Extracted all text-field state into `TrainingInputState`, a dedicated `@Observable` final class. SwiftUI's observation system tracks property access at the point of use: only `TrainingInputCard` (the child struct) accesses `inputState.weightText`, so only it re-renders on keystrokes. `TrainingView` (which owns the `List`) never re-renders during typing.

```swift
@Observable final class TrainingInputState {
    var weightText = ""
    var repsText = ""
    // ...
}

// TrainingView holds the instance as @State (reference doesn't change):
@State private var inputState = TrainingInputState()

// TrainingInputCard owns @Bindable for TextField binding syntax:
@Bindable var inputState: TrainingInputState
```

**Rule for future edits:** If a view contains both a `List`/`ForEach` and text fields, always isolate the text `@State` in a child view or `@Observable` object so keystrokes don't invalidate the list's parent body.

---

## 21. Weight Prefill Non-Deterministic for Same-Day Sets

**Date:** 2026-04-19

### Problem
After logging set 1 at 120 lbs and set 2 at 125 lbs, the field sometimes prefilled 120 instead of 125 when starting set 3.

### Root Cause
`prefillFromLastSession` sorted `exercise.trainingEntries` by `date`, which is stored as midnight UTC for all sets on the same day. Among same-day sets the sort order is non-deterministic — SwiftData can return them in any order, so set 1 could win over set 2.

### Fix
Replaced the sorted-date approach with `session.sets.last`. `session.sets` is an in-memory array appended in save order, so `.last` is always the most recently logged set regardless of date.

```swift
// session.sets is append-ordered, .last = most recently saved
if let last = session?.sets.last {
    entry = last
} else {
    // First set of the day — fall back to most recent historical set
    entry = exercise.trainingEntries
        .filter { !Calendar.current.isDate($0.date, inSameDayAs: workoutStore.date) }
        .sorted { $0.date > $1.date }
        .first
}
```

Prefill now carries forward within the session after every save (including when fields are cleared post-save).

---

## 22. No Alarm Sound on Timer Expiry (Foreground)

**Date:** 2026-04-19

### Problem
When the rest timer expired while the app was in the foreground, only a haptic vibration fired. The scheduled `UNUserNotificationCenter` notification is suppressed by iOS when the app is active, so no sound played.

### Fix
Added `AudioToolbox` import to `HapticManager`. `restTimerExpired()` now plays three "ding" sounds (system sound ID 1005) spaced 0.5 s apart via `AudioServicesPlayAlertSound`, which routes through the ringer/alert channel. If the device is on silent, it falls back to vibration only — appropriate gym behavior.

```swift
// Services/HapticManager.swift
import AudioToolbox

static func restTimerExpired() {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    for i in 0..<3 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
            AudioServicesPlayAlertSound(1005)
        }
    }
}
```

---

## Current State

- **BUILD SUCCEEDED** — zero errors
- Rest timer counts down, pauses, resumes, restarts, and sounds an alarm on expiry
- Weight input field is responsive with no lag (text state isolated in `TrainingInputState`)
- Weight prefill always uses the most recently logged set within the session
- Set rows support swipe-to-delete and inline trash icon when selected
- All SwiftData models correctly configured (one-sided `@Relationship` pattern)
- Widget extension target (`Widget/`) — files exist on disk but are not yet added to a widget extension target in xcodeproj. Rest timer Live Activity will not function until that target is created.
