//
//  GymFocusFilter.swift
//  FitNotes iOS
//
//  Focus Filter integration (product_roadmap.md 3.9).
//  When a workout is active, signals the Focus system so the user's
//  "Gym Focus" can automatically filter non-fitness notifications.
//
//  To use: the user creates a Focus called "Gym" in Settings → Focus,
//  then adds FitNotes as a Focus Filter source. When a workout is started
//  (WorkoutTime.start_date_time is set), the app publishes its context;
//  on workout end, the context is cleared.
//

import AppIntents

// MARK: - Focus Filter Intent

/// Declares that FitNotes participates in the Focus system.
/// iOS displays this in Settings → Focus → Focus Filters → FitNotes.
struct GymFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Gym Workout"
    static var description: IntentDescription? = IntentDescription(
        "Activates when a workout is in progress. Use with a Gym Focus to silence non-fitness notifications during training.",
        categoryName: "Workout"
    )

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Gym Focus"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Gym Workout", subtitle: isWorkoutActive == true ? "Active" : "Inactive")
    }

    /// Whether the workout is currently active.
    /// The Focus system reads this parameter to decide filter behavior.
    @Parameter(title: "Workout Active")
    var isWorkoutActive: Bool?

    init() {
        self.isWorkoutActive = nil
    }

    /// Called by the system when the Focus Filter is toggled.
    /// We don't need to do anything here — the app reads Focus state
    /// from the system, not the other way around.
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Focus Filter Context Publisher

/// Utility to publish/withdraw the Focus Filter context
/// when a workout starts or ends.
enum FocusFilterPublisher {
    /// Call when a workout starts (WorkoutTime.start_date_time is set).
    static func workoutStarted() {
        let intent = GymFocusFilter()
        intent.isWorkoutActive = .some(true)
        updateFocusFilter(intent)
    }

    /// Call when a workout ends (WorkoutTime.end_date_time is set).
    static func workoutEnded() {
        let intent = GymFocusFilter()
        intent.isWorkoutActive = .some(false)
        updateFocusFilter(intent)
    }

    private static func updateFocusFilter(_ intent: GymFocusFilter) {
        // The system reads the app's declared SetFocusFilterIntent
        // parameters to determine filter state. By executing the intent
        // we update the filter context for the current Focus.
        Task {
            try? await intent.perform()
        }
    }
}
