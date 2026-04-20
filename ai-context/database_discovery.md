# FitNotes Database Discovery

**Source file:** `FitNotes_Backup.fitnotes` (SQLite 3)  
**Locale in backup:** `en_US` (Imperial user — lbs/inches)  
**Total workout log entries:** 3,191 | **Exercises defined:** 125

---

## Table Inventory

| Table | Purpose |
|---|---|
| `exercise` | Exercise definitions (name, category, type) |
| `training_log` | Every logged set — the core workout data |
| `Category` | Muscle-group categories with display colours |
| `BodyWeight` | Daily body-weight check-ins |
| `Measurement` / `MeasurementRecord` | Body measurements (neck, chest, waist, etc.) |
| `MeasurementUnit` | Unit look-up table (kg, lbs, cm, in, %) |
| `Routine` / `RoutineSection` / `RoutineSectionExercise` / `RoutineSectionExerciseSet` | Planned workout templates |
| `WorkoutGroup` / `WorkoutGroupExercise` | Grouping of exercises within a session |
| `WorkoutTime` | Workout start/end timestamps |
| `WorkoutComment` | Free-text notes attached to a workout date |
| `Comment` | Generic polymorphic comments (owner_type_id + owner_id) |
| `Goal` | User-defined performance goals |
| `Barbell` | Saved barbell weights |
| `Plate` | Plate calculator config (weight, count, colour, dimensions) |
| `ExerciseGraphFavourite` | Pinned exercise graphs |
| `RepMaxGridFavourite` | Pinned 1RM comparison grids |
| `settings` | Single-row global app settings |
| `android_metadata` | Android SQLite artifact — contains only `locale TEXT` |

---

## Core Table Schemas

### `exercise`
```sql
CREATE TABLE exercise (
    _id               INTEGER PRIMARY KEY AUTOINCREMENT,
    name              TEXT    NOT NULL,
    category_id       INTEGER NOT NULL,             -- FK → Category._id
    exercise_type_id  INTEGER NOT NULL DEFAULT 0,   -- see Exercise Type enum
    notes             TEXT,
    weight_increment  INTEGER,                       -- per-exercise increment override (stored in kg × 1000, see weight encoding)
    default_graph_id  INTEGER,
    default_rest_time INTEGER,                       -- seconds
    weight_unit_id    INTEGER NOT NULL DEFAULT 0,   -- see Weight Unit enum
    is_favourite      INTEGER NOT NULL DEFAULT 0    -- boolean 0/1
);
```

### `training_log`
```sql
CREATE TABLE training_log (
    _id                            INTEGER PRIMARY KEY AUTOINCREMENT,
    exercise_id                    INTEGER NOT NULL,  -- FK → exercise._id
    date                           DATE    NOT NULL,  -- TEXT 'YYYY-MM-DD'
    metric_weight                  INTEGER NOT NULL,  -- ⚠ stored as kg REAL despite INTEGER type (see weight encoding)
    reps                           INTEGER NOT NULL,
    unit                           INTEGER NOT NULL DEFAULT 0,  -- see Weight Unit enum
    routine_section_exercise_set_id INTEGER NOT NULL DEFAULT 0, -- 0 = ad-hoc set
    timer_auto_start               INTEGER NOT NULL DEFAULT 0,  -- boolean
    is_personal_record             INTEGER NOT NULL DEFAULT 0,  -- boolean
    is_personal_record_first       INTEGER NOT NULL DEFAULT 0,  -- boolean (first time hitting this PR)
    is_complete                    INTEGER NOT NULL DEFAULT 0,  -- boolean (set was marked done)
    is_pending_update              INTEGER NOT NULL DEFAULT 0,  -- boolean (sync flag)
    distance                       INTEGER NOT NULL DEFAULT 0,  -- cardio: metres × 1000
    duration_seconds               INTEGER NOT NULL DEFAULT 0   -- cardio / timed exercises
);
```

### `Category`
```sql
CREATE TABLE Category (
    _id        INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL,
    colour     INTEGER NOT NULL DEFAULT 0,  -- ⚠ Android signed ARGB int (see colour encoding)
    sort_order INTEGER NOT NULL DEFAULT 0
);
```

**Built-in categories and their colours:**

| _id | name | Android ARGB int | Hex (AARRGGBB) | Approx colour |
|---|---|---|---|---|
| 1 | Shoulders | -7453523 | `FF8E44AD` | Purple |
| 2 | Triceps | -14176672 | `FF27AE60` | Green |
| 3 | Biceps | -812014 | `FFF39C12` | Orange |
| 4 | Chest | -4179669 | `FFC0392B` | Red |
| 5 | Back | -14057287 | `FF2980B9` | Blue |
| 6 | Legs | -11226442 | `FF54B2B6` | Teal |
| 7 | Abs | -13877680 | `FF2C3E50` | Dark slate |
| 8 | Cardio | -8418163 | `FF7F8C8D` | Grey |

### `BodyWeight`
```sql
CREATE TABLE BodyWeight (
    _id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    date                TEXT NOT NULL,   -- 'YYYY-MM-DD'
    body_weight_metric  REAL NOT NULL,   -- ⚠ always kg; convert to lbs for display (× 2.20462)
    body_fat            REAL NOT NULL,   -- percentage (0.0 if not tracked)
    comments            TEXT
);
```
> No entries exist in this backup (table is empty).

### `Measurement` + `MeasurementRecord`
```sql
CREATE TABLE Measurement (
    _id        INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL,
    unit_id    INTEGER NOT NULL DEFAULT 0,  -- FK → MeasurementUnit._id
    goal_type  INTEGER NOT NULL DEFAULT 0,
    goal_value REAL    NOT NULL DEFAULT 0,
    custom     INTEGER NOT NULL DEFAULT 0,  -- boolean: 0=built-in, 1=user-created
    enabled    INTEGER NOT NULL DEFAULT 0,  -- boolean
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE MeasurementRecord (
    _id            INTEGER PRIMARY KEY AUTOINCREMENT,
    measurement_id INTEGER NOT NULL,  -- FK → Measurement._id
    date           TEXT    NOT NULL,  -- 'YYYY-MM-DD'
    time           TEXT    NOT NULL,  -- time of day (format: 'HH:MM' or similar)
    value          REAL    NOT NULL,
    comment        TEXT
);
```

### `MeasurementUnit`
```sql
CREATE TABLE MeasurementUnit (
    _id        INTEGER PRIMARY KEY AUTOINCREMENT,
    type       INTEGER NOT NULL DEFAULT 0,
    long_name  TEXT    NOT NULL,
    short_name TEXT    NOT NULL
);
```

| _id | type | long_name | short_name | Notes |
|---|---|---|---|---|
| 1 | 0 | _(empty)_ | _(empty)_ | "None" / bodyweight-only placeholder |
| 2 | 1 | Kilograms | kgs | Weight |
| 3 | 1 | Pounds | lbs | Weight |
| 4 | 2 | Centimetres | cm | Length |
| 5 | 2 | Inches | in | Length |
| 6 | 3 | Percent | % | Body fat, etc. |

---

## Enum / Flag Reference

### Exercise Type (`exercise.exercise_type_id`)

| Value | Meaning | Relevant fields |
|---|---|---|
| `0` | Standard weight exercise (barbell, dumbbell, cable, machine) | `metric_weight`, `reps` |
| `1` | Cardio | `distance`, `duration_seconds` |
| `3` | Timed / isometric (e.g. Plank, Side Plank) | `duration_seconds` |

> No exercises with `exercise_type_id = 2` exist in this backup. The value may be reserved for a "bodyweight reps" variant in the app.

### Weight Unit (`training_log.unit`, `exercise.weight_unit_id`, `RoutineSectionExerciseSet.unit`)

| Value | Meaning |
|---|---|
| `0` | Kilograms (metric) |
| `2` | Pounds (imperial) — confirmed from this backup (Imperial user, all sets show `unit=2`) |

> `exercise.weight_unit_id` has observed values 0, 1, 2. The meaning of `1` is unclear from this dataset but may represent a per-exercise override state.

### `settings.metric`

| Value | Meaning |
|---|---|
| `0` | **Imperial** (lbs) — this backup's value |
| `1` | Metric (kg) |

> Counterintuitive naming: `metric = 0` means the user is **not** using metric units.

---

## Android-isms to Handle on iOS

### 1. Weights are always stored in kg — even for Imperial users
`training_log.metric_weight` (and all `metric_weight` columns) are **always stored in kilograms** regardless of the user's unit preference. The schema declares the column as `INTEGER` but SQLite's dynamic typing allows it to hold `REAL` values. Confirmed: `4.5359290943564` → `10.0000 lbs` (multiply by `2.20462` to display).

**iOS action:** Read `settings.metric` to determine display unit. Always store kg internally; convert on read for display.

### 2. Dates are stored as `TEXT 'YYYY-MM-DD'` — NOT Unix milliseconds
FitNotes avoids the common Android pattern of storing timestamps as milliseconds since epoch. Dates throughout the database are plain ISO-8601 date strings. `WorkoutTime` uses a separate `start_date_time` / `end_date_time` text pair (format likely `'YYYY-MM-DD HH:MM:SS'`).

**iOS action:** Use `DateFormatter` with `"yyyy-MM-dd"` format. No epoch conversion needed.

### 3. Category colours are Android signed 32-bit ARGB integers
`Category.colour` stores colours as Java/Android `int` values (signed 32-bit, ARGB channel order). Example: `-7453523` = `0xFF8E44AD` = fully opaque purple.

**iOS action:** Mask to unsigned: `UInt32(bitPattern: Int32(colourValue))`. Extract channels: A=bits 24-31, R=16-23, G=8-15, B=0-7. Create `UIColor` / `Color` from those components.

### 4. `android_metadata` table — ignore on import
Every Android SQLite database contains an `android_metadata` table with a single `locale` text row (here: `en_US`). It is not part of the FitNotes data model.

**iOS action:** Skip this table entirely during import.

### 5. Boolean flags are `INTEGER 0/1`
SQLite has no native boolean type. FitNotes uses `INTEGER NOT NULL DEFAULT 0` throughout (`is_favourite`, `is_complete`, `is_personal_record`, `enabled`, `custom`, etc.).

**iOS action:** Map to Swift `Bool` via `value != 0`.

### 6. Colour is a signed int in `WorkoutGroup.colour` too
Same Android ARGB integer pattern as `Category.colour`.

### 7. `settings` is a single-row table
The `settings` table always has exactly one row (`_id = 1`). There is no user-ID scoping.

---

## Settings Row (this backup)

Decoded from the single row in `settings`:

| Column | Value | Notes |
|---|---|---|
| `metric` | `0` | Imperial (lbs) |
| `first_day_of_week` | `1` | Monday (0=Sunday, 1=Monday) |
| `weight_increment` | `2.5` | Default increment in kg (≈ 5 lbs) |
| `body_weight_increment` | `0.1` | |
| `track_personal_records` | `1` | Enabled |
| `mark_sets_complete` | `1` | Enabled |
| `auto_select_next_set` | `1` | Enabled |
| `rest_timer_seconds` | `120` | 2-minute default rest |
| `rest_timer_auto_start` | `1` | Enabled |
| `app_theme_id` | `0` | Default theme |

---

## Routine / Template Structure

```
Routine
  └─ RoutineSection          (e.g. "Day A", "Day B")
       └─ RoutineSectionExercise   (exercise + populate_sets_type)
            └─ RoutineSectionExerciseSet  (planned sets: weight, reps, distance, duration)
```

`populate_sets_type` on `RoutineSectionExercise` controls how the log is pre-filled from the template (observed value: `0` = use planned sets as-is).

`training_log.routine_section_exercise_set_id` links a logged set back to its template set; value `0` means the set was logged ad-hoc (not from a routine).

---

## Workout Session Structure

```
WorkoutGroup  (a named session block, tied to a date + optional RoutineSection)
  └─ WorkoutGroupExercise   (which exercises were performed in that block)

WorkoutTime   (overall session start / end datetimes)
WorkoutComment (free-text note for the day)
```
