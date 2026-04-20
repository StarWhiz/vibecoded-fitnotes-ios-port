# FitNotes iOS — Product Roadmap

**Source:** FitNotes Android (fitnotesapp.com help docs) + `FitNotes_Backup.fitnotes` schema analysis  
**Date:** 2026-04-13  
**User profile:** Imperial (lbs/inches), 3,191 logged sets, 125 exercises

---

## Table of Contents

1. [Feature Inventory](#1-feature-inventory)
2. [Schema Coverage Gaps](#2-schema-coverage-gaps)
3. [iOS-First Enhancements](#3-ios-first-enhancements)

---

## 1. Feature Inventory

Each feature lists: what it does, its UX logic/flow, and which DB tables back it.

---

### 1.1 Workout Tracking

**Description:** The core loop — start a workout, pick exercises, log sets, finish.

**UX Logic:**
- Home screen defaults to today's date. A `+` button opens the exercise picker (grouped by `Category`, searchable by name).
- Selecting an exercise opens the **Training Screen**: weight/reps input fields pre-filled from the last session's first set (`training_log` lookup by exercise + latest date).
- Tapping **Save** appends a row to `training_log`. The system checks whether the new set beats stored personal records and sets `is_personal_record = 1` / `is_personal_record_first = 1` accordingly.
- Multiple sets log as individual rows — intentional (allows per-set comments and individual edits).
- Tap a logged set → fields re-populate; Save becomes **Update** (UPDATE on existing `training_log` row) and a **Delete** button appears.
- **Mark Sets Complete:** when enabled in settings, a checkbox per set flips `is_complete`; `auto_select_next_set` then advances focus to the next unchecked set.

**DB tables:** `training_log`, `exercise`, `Category`, `settings`

---

### 1.2 Supersets / Circuits (WorkoutGroups)

**Description:** Exercises can be grouped so the app auto-advances through them after each set.

**UX Logic:**
- "Add To Group" assigns an exercise to a `WorkoutGroup` for the current date.
- The group gets a color (Android signed ARGB int stored in `WorkoutGroup.colour`) and an optional name.
- After saving a set for exercise A, the app auto-navigates to exercise B, then C, cycling back to A.
- Visual: colored sidebar bars distinguish groups on the training screen.
- Groups can be renamed, recolored, reordered, or dissolved.

**DB tables:** `WorkoutGroup`, `WorkoutGroupExercise`

---

### 1.3 Exercise Notes

**Description:** Per-exercise text memo for form cues, machine settings, or video links.

**UX Logic:**
- Accessible from the Training Screen via a notes icon.
- Stored in `exercise.notes` (TEXT, nullable).
- The same notes UI also hosts per-exercise overrides: `weight_increment`, `default_rest_time`, `default_graph_id`, and `weight_unit_id`.

**DB tables:** `exercise` (notes, weight_increment, default_rest_time, default_graph_id, weight_unit_id)

---

### 1.4 Set-Level Comments

**Description:** Annotate individual sets (e.g., "had a spotter", "paused reps").

**UX Logic:**
- Comment icon on each logged set row. Commented sets show a blue icon in history.
- Stored in the polymorphic `Comment` table (`owner_type_id` + `owner_id` pointing to `training_log._id`).
- Deleting a set cascades to its comment(s).

**DB tables:** `Comment`

---

### 1.5 Workout Comment

**Description:** Free-text note for the whole workout session (e.g., "felt sluggish today").

**UX Logic:**
- Accessed via the overflow menu on the home screen or training screen.
- Appears above the exercise list on home screen and calendar detail view.
- One comment per date per `WorkoutComment` row.

**DB tables:** `WorkoutComment`

---

### 1.6 Workout Timing

**Description:** Record when a workout started and ended; compute duration.

**UX Logic:**
- "Start Timer" taps record `start_date_time` in `WorkoutTime`. Stopping records `end_date_time`.
- Manual entry is also supported (auto-calculates duration).
- Shown in the workout detail header.
- iOS: use a background `Task` + `UserNotifications` to persist the running timer across app states.

**DB tables:** `WorkoutTime`

---

### 1.7 Navigation Panel

**Description:** Slide-out panel listing all exercises in today's workout with set counts; allows jump-to and reorder.

**UX Logic:**
- Opens via app logo tap or left-edge swipe (on iOS: `UIScreenEdgePanGestureRecognizer` or SwiftUI equivalent).
- Each row shows exercise name + how many sets logged.
- Drag-and-hold to reorder — this changes the display order, not `training_log` data (order is implicit by insertion or an explicit `sort_order` field, TBD).
- "Add Exercise" from panel appends to today's workout.

**DB tables:** `training_log` (read-only for this panel)

---

### 1.8 Rest Timer

**Description:** Countdown timer between sets with audio/vibration alert.

**UX Logic:**
- Auto-starts after a set is saved (if `settings.rest_timer_auto_start = 1`) or after a set is marked complete.
- Default duration: `settings.rest_timer_seconds` (120 s in this backup).
- Per-exercise override: `exercise.default_rest_time`.
- Alert modes: sound (volume slider) + vibration toggle.
- **iOS-critical:** Must post a `UNTimeIntervalNotificationRequest` so the alert fires even when the app is backgrounded or the screen is locked. A `UNNotificationAction` ("Stop Timer") should be included so users can dismiss without opening the app.

**DB tables:** `settings` (rest_timer_seconds, rest_timer_auto_start), `exercise` (default_rest_time)

---

### 1.9 1RM Calculator

**Description:** Given weight + reps, estimate one-rep maximum and derive 2RM–15RM.

**UX Logic:**
- Accessible from the Training Screen tools menu.
- Input: weight + rep count → output: Epley/Brzycki estimated 1RM and the full RM table.
- No persistence — purely computed at runtime.
- "Select from Records" pre-fills with the user's actual personal record for the current exercise.

**DB tables:** None (pure computation); reads `training_log` for pre-fill.

---

### 1.10 Set Calculator (Percentage-Based)

**Description:** Compute target set weights as percentages of a base max (e.g., Wendler 5/3/1).

**UX Logic:**
- Choose a base weight (or pick from personal records via "Select Max").
- Choose percentage from a predefined list or type a custom value.
- "Round To Closest" snaps to 2.5 / 5.0 / 10.0 lb (or kg) increments.
- "Add To Workout" inserts the computed weight into the current set's weight field.
- No persistence of percentage schemes — purely runtime.

**DB tables:** None (reads `training_log` for "Select Max"); writes to UI state only.

---

### 1.11 Plate Calculator

**Description:** Given a target barbell weight, display the plates needed per side.

**UX Logic:**
- Default bar weights: 20 kg / 45 lbs. Per-exercise bar overrides are supported.
- Plate library (weight, color, quantity, dimensions) is user-customizable.
- Calculation: `(target − bar) / 2`, greedy largest-first plate selection.
- Checkboxes toggle plate availability without deleting the plate definition.

**DB tables:** `Plate` (weight, colour, count, dimensions), `Barbell`

---

### 1.12 Progress Graphs

**Description:** Visual history charts per exercise across a wide range of metrics.

**UX Logic:**
- Accessed via the Graph tab on the Training Screen or Exercise Overview modal.
- Metric options (for weight exercises): Estimated 1RM, Max Weight, Volume, Total Reps, Max Reps, Weight+Reps, Rep Maxes (1RM–15RM progression).
- Metric options (for cardio): Max Distance, Max Time, Max Speed, Max Pace, Total Distance, Total Time.
- Each point is tappable for exact value + date.
- Overlay options: trend line, graph points toggle, Y-axis from zero.
- Pinned favorites stored in `ExerciseGraphFavourite`.

**DB tables:** `training_log`, `exercise`, `ExerciseGraphFavourite`

---

### 1.13 Personal Records

**Description:** Track max weight per rep-count, with estimated and actual variants.

**UX Logic:**
- **Estimated:** Derived from highest estimated 1RM across all sets for an exercise; generates projected 2RM–15RM. A rep-limit setting (10–12 reps) prevents outliers from inflating estimates.
- **Actual:** Highest real weight at each rep count; enforces "precedence" (heavier weight at more reps supersedes lighter at fewer reps).
- PR flags: `training_log.is_personal_record` and `is_personal_record_first` set on write.
- A trophy icon appears inline on the Training Screen when a PR is set.
- **Recalculate PRs** action in Settings reprocesses all history (useful after deleting or editing old sets).

**DB tables:** `training_log` (is_personal_record, is_personal_record_first), `settings` (track_personal_records)

---

### 1.14 Training History

**Description:** Browse past logged sets for any exercise, view totals, and edit.

**UX Logic:**
- History tab on the Training Screen shows all previous dates for the current exercise, most recent first.
- Tapping a date expands sets + comments and shows aggregate metrics (Total Volume, Total Reps for strength; Total Distance, Total Duration for cardio).
- Tapping an individual set shows its Estimated 1RM + Volume (strength) or Speed + Pace (cardio).
- Sets can be edited or deleted from here, not just from today's active workout.

**DB tables:** `training_log`, `Comment`

---

### 1.15 Statistics Dashboard

**Description:** Per-exercise numerical stats filterable by time period.

**UX Logic:**
- Time period filter: Workout, Week, Month, Year, All, Custom date range.
- Metrics computed server-side from `training_log`: max weight, total volume, total reps, etc.
- Tapping a date-linked stat launches the full workout view for that date.

**DB tables:** `training_log`

---

### 1.16 Goals

**Description:** User-defined performance targets per exercise.

**UX Logic:**
- Add/edit/delete goals via the Goals tab in the Exercise Overview.
- Displayed on progress graphs as a horizontal target line.
- Goal type (increase/decrease/specific value) determines color coding of deltas.

**DB tables:** `Goal`

---

### 1.17 Exercise Overview (Modal)

**Description:** Unified modal consolidating History, Graph, Records, Stats, and Goals for one exercise.

**UX Logic:**
- Accessible from: Calendar day detail, Training History, Progress Graphs, Statistics, Personal Records.
- Five tabs in one sheet — avoids deep navigation stacks.
- iOS: implement as a `UISheetPresentationController` / `.sheet` with tab bar inside, or a `NavigationSplitView` variant.

**DB tables:** All exercise-related tables.

---

### 1.18 Exercise Management

**Description:** Create, edit, delete, and search exercises.

**UX Logic:**
- Exercise list: hierarchical `Category` → `exercise` rows. Search supports partial matching ("dum press" finds "Dumbbell Press").
- **Add:** name, notes, category, exercise type, weight unit → save or "save and continue".
- **Edit:** same fields; changing exercise type deletes incompatible history data (warn user).
- **Delete:** cascades to all `training_log` rows, `Goal`, `Comment`, `ExerciseGraphFavourite`, `RepMaxGridFavourite`. Irreversible — require confirmation.
- **Favourite:** `exercise.is_favourite = 1`; a synthetic "Favourites" category appears at the top of the list.
- **Details toggle:** show workout count and last-used date inline (computed from `training_log`).

**DB tables:** `exercise`, `Category`, `training_log`, `Goal`, `Comment`, `ExerciseGraphFavourite`, `RepMaxGridFavourite`

---

### 1.19 Exercise Types

| Type ID | Name | Fields Used |
|---|---|---|
| `0` | Weight + Reps | metric_weight, reps |
| `1` | Cardio (Distance + Time) | distance, duration_seconds |
| `3` | Timed / Isometric | duration_seconds |
| Premium | Weight+Distance, Weight+Time, Reps+Distance, Reps+Time, Weight only, Reps only, Distance only, Time only | varies |

> **iOS note:** The premium exercise types are not in the observed `exercise_type_id` values (0, 1, 3). Map defensively — fall back to the closest known type on import.

---

### 1.20 Category Management

**Description:** Muscle-group buckets with color labels.

**UX Logic:**
- 8 built-in categories (Shoulders through Cardio); cannot be deleted.
- Custom categories: add, edit name/color, reorder (drag-and-drop or alphabetical sort), delete (cascades to all contained exercises — warn prominently).
- Colors are Android signed ARGB ints in DB; convert via `UInt32(bitPattern: Int32(value))` → extract ARGB channels → `Color(red:green:blue:opacity:)`.

**DB tables:** `Category`

---

### 1.21 Routines

**Description:** Pre-planned, reusable workout templates with multi-day structure.

**UX Logic:**
- Hierarchy: Routine → RoutineSection (Day A, Day B…) → RoutineSectionExercise → RoutineSectionExerciseSet.
- Predefined sets can have fixed values or be blank (auto-copies from last session on execution).
- **Log All:** one tap to materialize all sets for a day into `training_log`; user can deselect exercises or sets before confirming.
- Logged sets carry `routine_section_exercise_set_id` for traceability; ad-hoc sets use `0`.
- Routine duplication (copy) for creating variants.
- Superset groups within routines use the same `WorkoutGroup` pattern.

**DB tables:** `Routine`, `RoutineSection`, `RoutineSectionExercise`, `RoutineSectionExerciseSet`, `WorkoutGroup`, `WorkoutGroupExercise`, `training_log`

---

### 1.22 Calendar View

**Description:** Month and list views of workout history with category color dots.

**UX Logic:**
- **Month view:** colored dots beneath each trained day (one dot per `Category` trained). Tap day → workout detail popup. Optional Workout Panel splits screen with swipe-between-dates.
- **List view:** reverse-chronological workout summaries. Optional: show category dots, category names, and set details inline.
- **Category filter:** multi-select with Match All / Match Any modes.
- **Exercise filter:** target specific exercises, optionally filtering by weight/rep thresholds.
- Tapping an exercise in any calendar view opens the Exercise Overview modal.

**DB tables:** `training_log`, `exercise`, `Category`, `WorkoutComment`

---

### 1.23 Body Tracker

**Description:** Log and graph custom body measurements over time.

**UX Logic:**
- Two always-on measurements: Body Weight (`BodyWeight` table, always stored in kg) and Body Fat.
- Additional standard measurements disabled by default; users enable via checkbox.
- Custom measurements: name, unit (kg/lbs/cm/in/% or user-defined), goal (increase / decrease / specific value).
- Track screen: shows last value, delta, time since last entry; previous value pre-fills input; optional comment; custom date/time stamp.
- History screen: per-date entries with color-coded deltas (green = moving toward goal).
- Progress graphs: target-value line, interactive points showing value + cross-referenced same-day measurements.
- Disabling a measurement does NOT delete recorded values.

**DB tables:** `BodyWeight`, `Measurement`, `MeasurementRecord`, `MeasurementUnit`

---

### 1.24 Settings

**Description:** Global app configuration.

| Setting | DB Column | Notes |
|---|---|---|
| Unit system (kg / lbs) | `settings.metric` | 0 = Imperial, 1 = Metric — counterintuitive naming |
| First day of week | `settings.first_day_of_week` | 0=Sun, 1=Mon |
| Default weight increment | `settings.weight_increment` | Stored in kg |
| Body weight increment | `settings.body_weight_increment` | |
| Track personal records | `settings.track_personal_records` | |
| Mark sets complete | `settings.mark_sets_complete` | |
| Auto-select next set | `settings.auto_select_next_set` | |
| Rest timer duration | `settings.rest_timer_seconds` | |
| Rest timer auto-start | `settings.rest_timer_auto_start` | |
| App theme | `settings.app_theme_id` | 0 = default |

**Non-DB settings (device/OS level):**
- Keep Screen On → iOS: `UIApplication.shared.isIdleTimerDisabled = true` while workout is active.
- Light / Dark theme → `UIUserInterfaceStyle` / SwiftUI `preferredColorScheme`.

**DB tables:** `settings`

---

### 1.25 Data Backup & Export

**Description:** Save, restore, and export workout data.

**UX Logic:**
- **Backup:** writes the SQLite file as `FitNotes_Backup.fitnotes` (optionally timestamped). Share sheet lets users save to Files, email, cloud.
- **Restore:** picks a `.fitnotes` file → overwrites current DB after user confirmation.
- **Auto-backup:** Android uses Google Drive; iOS replacement → iCloud Drive automatic copy.
- **CSV Export:** two CSVs — workout log and body tracker — for spreadsheet analysis.
- **Delete workout history:** by date range or by exercise. Selective, not all-or-nothing.
- **Recalculate PRs:** full table scan to recompute `is_personal_record` / `is_personal_record_first`.

**DB tables:** All (full DB backup); `training_log` (CSV export); `BodyWeight`, `MeasurementRecord` (body CSV)

---

### 1.26 Home Screen Operations

**Description:** Per-workout actions accessible from the main date view.

| Action | UX Logic |
|---|---|
| **Comment workout** | Writes to `WorkoutComment` for the current date |
| **Time workout** | Start/stop via `WorkoutTime`; manual entry supported |
| **Share workout** | Renders `training_log` rows as plain text; share sheet (no DB write) |
| **Copy workout** | Multi-select exercises/sets → duplicate rows to a target date |
| **Move workout** | Change date on selected `training_log` rows via calendar picker |
| **Delete exercises** | Press-and-hold multi-select → bulk DELETE from `training_log` |
| **Reorder exercises** | Drag-and-drop — changes display order (implicit or explicit sort field) |

---

## 2. Schema Coverage Gaps

Features documented in the FitNotes UI that have **no direct table** in the discovered schema, requiring iOS-side implementation decisions.

| Feature | Gap | iOS Implementation Strategy |
|---|---|---|
| **Set Calculator (Wendler %)** | No persistence — purely computed | Implement as stateless view; no DB changes needed |
| **Advanced exercise types (premium)** | `exercise_type_id` values beyond 0/1/3 not in backup | Add mapping in app layer; handle unknown IDs gracefully on import |
| **Workout Share (text export)** | No DB table — runtime render only | Build a `WorkoutShareFormatter` that queries `training_log` and produces plain text |
| **Workout Copy** | No audit table — operation duplicates rows | Implement as INSERT SELECT with new date; no new table needed |
| **Auto-backup** | Android uses Google Drive integration | Replace with iCloud Drive using `NSFileManager` + `NSUbiquitousItemDownloadingStatusCurrent` |
| **CSV Export** | No DB table — runtime query → file | Export from `training_log` JOIN `exercise`; write to temp file → share sheet |
| **Keep Screen On** | OS-level, no DB | `UIApplication.shared.isIdleTimerDisabled` toggled on workout start/end |
| **Light/Dark theme** | `settings.app_theme_id = 0` but no theme definitions in DB | Map 0→system, 1→light, 2→dark in Swift; honour iOS system appearance |
| **Rep Max Grid Favourite** | `RepMaxGridFavourite` table exists but schema not fully documented | Reverse-engineer columns on import; likely stores exercise_id pairs |
| **Exercise Details display** (workout count, last-used date) | Computed, not stored | Compute via `COUNT` + `MAX(date)` query on `training_log` group by exercise_id |
| **Workout Panel split view** | UI state only | Implement as SwiftUI `NavigationSplitView` — no DB changes |
| **Custom measurement units** | `MeasurementUnit` has no "custom" flag in known schema | Add a `custom INTEGER DEFAULT 0` migration on first launch |

---

## 3. iOS-First Enhancements

Features that go beyond the Android original and take advantage of native iOS/Apple platform capabilities. Ordered roughly by implementation complexity (low → high).

---

### 3.1 Apple Health Integration (HealthKit)

**Value:** Users already track weight and workouts — sync to Health gives a unified view.

**What to sync:**
- `BodyWeight.body_weight_metric` → `HKQuantityType.bodyMass`
- `BodyWeight.body_fat` → `HKQuantityType.bodyFatPercentage`
- Completed workouts (`WorkoutTime`) → `HKWorkout` with `HKWorkoutActivityType.traditionalStrengthTraining`
- Total volume per workout → `HKQuantity` attached to the `HKWorkout`
- Cardio sessions → `HKWorkoutActivityType.running` / `.cycling` with distance + duration

**UX Logic:** Prompt HealthKit authorization on first launch. Write on save; read on first import to avoid duplicates. Allow users to disable in Settings.

---

### 3.2 Live Activities — Rest Timer on Lock Screen & Dynamic Island

**Value:** Users put their phone down between sets; currently must unlock to see the countdown.

**UX Logic:**
- When the rest timer starts, begin a `ActivityKit.Activity<RestTimerAttributes>`.
- Dynamic Island compact: remaining seconds + exercise name.
- Lock Screen: full countdown ring + exercise name + "Skip" button (via `ActivityAction`).
- On timer expiry: push a `UNNotificationRequest` with sound + haptic; end the Live Activity.
- On iOS 16 and below: fall back to a `UNTimeIntervalNotificationRequest` banner only.

**DB dependency:** None — timer state is ephemeral. `exercise.default_rest_time` seeds duration.

---

### 3.3 Home Screen Widgets (WidgetKit)

**Value:** Glanceable workout streak and "what's next" motivation without opening the app.

**Widget ideas:**

| Widget | Size | Content |
|---|---|---|
| **Today's Workout** | Medium | Exercise list for today with set counts; "Start Workout" deep link |
| **Streak Counter** | Small | Consecutive training days + longest streak |
| **Next Routine Day** | Medium | Which routine day is up next + key exercises |
| **Last Workout Summary** | Large | Date, total volume, exercises hit |

**UX Logic:** Use a `TimelineProvider` reading from the shared App Group SQLite. Tap widget deep-links to the correct screen via a custom URL scheme (`fitnotes://workout/today`).

**DB dependency:** Shared App Group container so WidgetKit extension can read the `.fitnotes` SQLite directly.

---

### 3.4 Apple Watch Companion (watchOS)

**Value:** Log sets and dismiss the rest timer from the wrist — phone stays in your bag.

**Feature scope:**
- **Active workout screen:** current exercise name, last set (weight × reps), `+1 Set` quick-log button with digital crown for weight adjustment.
- **Rest Timer:** full-screen countdown with haptic tap on expiry (`WKHapticType.stop`).
- **Personal Record alert:** trophy crown animation on PR.
- **End Workout:** button syncs final sets back to iPhone via `WCSession.sendMessage`.

**UX Logic:** Use `WCSession` for real-time sync during workout; `WKExtendedRuntimeSession` to keep the rest timer alive when the watch face is raised/lowered.

---

### 3.5 Siri Shortcuts (App Intents)

**Value:** Hands-free control for common actions during training.

**Suggested intents:**

| Phrase | Action |
|---|---|
| "Start my workout" | Opens training screen for today |
| "Log a set" | Voice-input weight + reps for current exercise |
| "Start rest timer" | Fires default rest timer |
| "How's my bench press?" | Reads back last session's sets |
| "What's my 1RM?" | Reads back PR for an exercise |

**UX Logic:** Implement `AppIntent` conforming structs for each. Donate `INInteraction` on each set save to build Siri suggestions.

---

### 3.6 iCloud Sync (CloudKit / NSUbiquitousKeyValueStore)

**Value:** Replaces the Android-only Google Drive auto-backup with first-class multi-device sync.

**Strategy options:**
1. **CloudKit + CKSyncEngine** — full record-level sync (complex but seamless; handles conflicts).
2. **iCloud Drive file sync** — push the `.fitnotes` SQLite to `NSUbiquitousItemDownloadingStatus`; simpler but no merge conflict resolution.
3. **NSUbiquitousKeyValueStore** — for lightweight settings only (under 1 MB limit, not suitable for 3K+ log rows).

**Recommended:** Option 2 as v1 (matches existing FitNotes backup paradigm), with Option 1 on the roadmap for v2.

**UX Logic:** On workout save, schedule a background copy of the DB file to iCloud Drive. On app launch, compare modification dates and prompt the user if the cloud version is newer.

---

### 3.7 StandBy Mode Rest Timer

**Value:** iPhone on nightstand / charging stand shows the countdown in full-screen clock style.

**UX Logic:**
- When a rest timer is active and the device enters StandBy (`UIApplicationState.background` + charging + landscape), display a `WidgetKit` StandBy widget showing the countdown.
- Requires a `StandByWidget` target alongside the main WidgetKit extension.
- Minimal implementation — reuse the `RestTimerAttributes` from Live Activities (§3.2).

---

### 3.8 Haptic Feedback Polish

**Value:** Reinforces actions without sound — critical in a noisy gym.

| Moment | Haptic |
|---|---|
| Set saved | `UIImpactFeedbackGenerator(.medium)` |
| Personal Record achieved | `UINotificationFeedbackGenerator(.success)` + brief banner |
| Rest timer expires | `UINotificationFeedbackGenerator(.warning)` |
| Set deleted | `UIImpactFeedbackGenerator(.light)` |
| Workout complete | `UINotificationFeedbackGenerator(.success)` with longer pattern |

---

### 3.9 Focus Filter Integration

**Value:** "Gym Focus" automatically silences non-fitness notifications during a workout.

**UX Logic:**
- Implement `AppContext` conforming to `FocusFilterIntent`.
- When a workout is active (`WorkoutTime.start_date_time` set, no `end_date_time`), signal the Focus system.
- On workout end, clear the context.
- No DB changes required — uses workout active state already tracked via `WorkoutTime`.

---

### 3.10 Share Workout as Image (Not Just Text)

**Value:** Social-media-ready workout card is more shareable than plain text.

**UX Logic:**
- Render a `WorkoutCard` SwiftUI view (dark gradient, exercise grid, total volume, PR callouts) into an image via `ImageRenderer`.
- Share via standard `UIActivityViewController`.
- User can toggle which exercises/sets to include (same UX as existing text share).
- No DB changes — read-only query of `training_log` + `exercise` + `Category` for colors.

---

*Document auto-generated from FitNotes help docs + backup schema analysis. Update as new schema tables are explored or iOS implementation decisions are finalised.*
