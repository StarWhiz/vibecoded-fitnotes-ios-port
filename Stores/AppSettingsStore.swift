//
//  AppSettingsStore.swift
//  FitNotes iOS
//
//  @Observable settings store as defined in technical_architecture.md section 6.4
//  Wraps the single AppSettings row. Injected into the environment so all views
//  read the same unit preference without @Query boilerplate.
//

import Foundation
import SwiftData

@Observable final class AppSettingsStore {
    private(set) var settings: AppSettings

    // MARK: - Unit system

    var isImperial: Bool {
        get { settings.isImperial }
        set { settings.isImperial = newValue }
    }

    var weightSymbol: String { isImperial ? "lbs" : "kg" }
    var distanceSymbol: String { isImperial ? "mi" : "km" }

    /// Converts a user-entered display weight to kg for storage.
    func kg(from displayWeight: Double) -> Double {
        isImperial ? displayWeight / 2.20462 : displayWeight
    }

    /// Converts stored kg to the user's display unit.
    func display(kg: Double) -> Double {
        isImperial ? kg * 2.20462 : kg
    }

    /// Rounds a display weight to the nearest increment.
    func roundToIncrement(_ displayWeight: Double) -> Double {
        let increment = display(kg: settings.defaultWeightIncrementKg)
        guard increment > 0 else { return displayWeight }
        return (displayWeight / increment).rounded() * increment
    }

    // MARK: - Calendar

    var firstDayOfWeek: Int {
        get { settings.firstDayOfWeek }
        set { settings.firstDayOfWeek = newValue }
    }

    // MARK: - Behaviour flags

    var trackPersonalRecords: Bool {
        get { settings.trackPersonalRecords }
        set { settings.trackPersonalRecords = newValue }
    }

    var markSetsComplete: Bool {
        get { settings.markSetsComplete }
        set { settings.markSetsComplete = newValue }
    }

    var autoSelectNextSet: Bool {
        get { settings.autoSelectNextSet }
        set { settings.autoSelectNextSet = newValue }
    }

    // MARK: - Rest timer

    var restTimerSeconds: Int {
        get { settings.restTimerSeconds }
        set { settings.restTimerSeconds = newValue }
    }

    var restTimerAutoStart: Bool {
        get { settings.restTimerAutoStart }
        set { settings.restTimerAutoStart = newValue }
    }

    // MARK: - Theme

    var appThemeID: Int {
        get { settings.appThemeID }
        set { settings.appThemeID = newValue }
    }

    // MARK: - Increments

    var defaultWeightIncrementKg: Double {
        get { settings.defaultWeightIncrementKg }
        set { settings.defaultWeightIncrementKg = newValue }
    }

    var bodyWeightIncrementKg: Double {
        get { settings.bodyWeightIncrementKg }
        set { settings.bodyWeightIncrementKg = newValue }
    }

    // MARK: - Init

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    /// Loads the settings row from SwiftData, or creates a default one if none exists.
    static func load(from context: ModelContext) throws -> AppSettingsStore {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try context.fetch(descriptor).first {
            return AppSettingsStore(settings: existing)
        }
        let defaults = AppSettings()
        context.insert(defaults)
        try context.save()
        return AppSettingsStore(settings: defaults)
    }
}
