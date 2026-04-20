//
//  HapticManager.swift
//  FitNotes iOS
//
//  Centralized haptic feedback for key workout moments (product_roadmap.md 3.8).
//  Reinforces actions without sound — critical in a noisy gym.
//

import UIKit

enum HapticManager {

    // MARK: - Workout Events

    /// Set saved successfully — medium impact.
    static func setSaved() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Personal Record achieved — success notification + longer pattern.
    static func personalRecord() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        // Second tap after brief delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
        }
    }

    /// Rest timer expired — warning notification.
    static func restTimerExpired() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Set deleted — light impact.
    static func setDeleted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Workout completed (all exercises done / timer stopped) — success with pattern.
    static func workoutComplete() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - General UI

    /// Light tap for selection changes, toggles, etc.
    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
