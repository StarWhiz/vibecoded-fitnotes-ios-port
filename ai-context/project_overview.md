# FitNotes iOS — Project Overview

## What We're Building

A native iOS port of **FitNotes**, a popular Android workout tracker. The goal is a first-class iOS app that feels native on iPhone — not a wrapper or a cross-platform build — while being fully backward compatible with the user's existing Android workout history.

## Why

The user has been logging workouts in FitNotes on Android for years (3,191 sets, 125 exercises). FitNotes does not have an official iOS app. Rather than lose that history or switch to a different tracker, the plan is to build an iOS version from scratch that can import the existing `.fitnotes` SQLite backup and pick up exactly where the Android app left off.

## Tech Stack

| Concern | Choice |
|---|---|
| Platform | iOS 17+ |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`, `ModelContainer`) |
| Reactive state | Swift Observation (`@Observable`) — no Combine |
| Concurrency | `async/await` + `Actor` |
| SQLite import | GRDB.swift (read-only access to `.fitnotes` backup) |

## How It Works

The Android app exports data as a plain SQLite file (`FitNotes_Backup.fitnotes`). The iOS app includes a one-time importer that reads this file and converts every row into SwiftData model objects. After import, the app runs entirely on SwiftData — the original SQLite file is no longer needed.

## Data Model in a Sentence

Every logged **set** is a `TrainingEntry`. Sets belong to an `Exercise`, which belongs to a `WorkoutCategory`. Everything else (routines, rest timer, body tracker, goals, progress graphs) hangs off that core spine.

## User Profile

Imperial units throughout (lbs, inches). `settings.metric = 0` in the source DB means Imperial — a counterintuitive column name documented in `database_discovery.md`.

## Document Map

| File | What it covers |
|---|---|
| `database_discovery.md` | Full SQLite schema, Android-isms, enum values, colour encoding |
| `product_roadmap.md` | Feature inventory (26 features), schema gaps, iOS-first enhancements |
| `technical_architecture.md` | SwiftData `@Model` classes, enums, layer architecture, state management |
| `migration_plan.md` | Import order, row→object mapping code, type conversions, post-i?mport verification |
| `phase1_summary.md` | Phase 1 completion report — 21 models, 3 enums, importer, verification |
| `phase4_summary.md` | Phase 4 completion report — 24 views, navigation, all 1.1–1.26 features |
| `FitNotes_Backup.fitnotes` | The actual source SQLite backup (do not modify) |

## Current Status

Phases 1 through 5 are complete. The codebase has all models, import pipeline, state management stores, domain services, platform integrations, full SwiftUI view layer, and iOS-first enhancements. Ready for Xcode project setup, compilation, and device testing.

### Action Phases
Phase 1: Data Foundation (Core Models & Import) — **Complete.** Documented in `phase1_summary.md`
Phase 2: Core Functionality (State Management & Business Logic) — **Complete.** Stores, services, LiveActivity, Widgets, Intents, HealthKit, CloudSync all implemented.
Phase 3: iOS-Native Features (Platform Integration) — **Complete.** Part of Phase 2 implementation.
Phase 4: User Interface (Views & Navigation) — **Complete.** Documented in `phase4_summary.md`
Phase 5: Polish & Testing — **Complete.** Documented in `phase5_summary.md`

### Phase 5 Deliverables
- ✅ Haptic feedback polish throughout workout flow
- ✅ Focus Filter integration for distraction-free training
- ✅ Share workout as image (social-media-ready workout cards)
- ✅ Import verification test view for data integrity checking
