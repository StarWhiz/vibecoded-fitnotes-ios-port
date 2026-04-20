//
//  RestTimerStore.swift
//  FitNotes iOS
//
//  @Observable rest timer store as defined in technical_architecture.md section 6.2
//  Separated from ActiveWorkoutStore because timer state is purely ephemeral
//  and cross-cutting (training screen, Live Activities, lock screen widget).
//

import ActivityKit
import Foundation
import SwiftUI
import UserNotifications

@Observable final class RestTimerStore {
    var state: RestTimerState = .idle
    // Separate Int property so @Observable triggers a real value change each second.
    // Reassigning the same Equatable enum value is a no-op for SwiftUI observation.
    private(set) var remainingSeconds: Int = 0

    private var task: Task<Void, Never>? = nil
    private var currentActivity: Activity<RestTimerAttributes>? = nil

    // MARK: - Actions

    func start(seconds: Int, exerciseName: String) {
        task?.cancel()
        let endsAt = Date.now.addingTimeInterval(Double(seconds))
        state = .running(endsAt: endsAt, totalSeconds: seconds, exerciseName: exerciseName)
        remainingSeconds = seconds

        scheduleNotification(seconds: seconds, exerciseName: exerciseName)
        startLiveActivity(endsAt: endsAt, exerciseName: exerciseName)

        task = Task { await runCountdown(until: endsAt, exerciseName: exerciseName) }
    }

    func stop() {
        task?.cancel()
        cancelNotification()
        endLiveActivity()
        state = .idle
        remainingSeconds = 0
    }

    func addTime(_ seconds: Int) {
        guard case .running(let endsAt, let totalSeconds, let name) = state else { return }
        let newEnd = endsAt.addingTimeInterval(Double(seconds))
        let newTotal = totalSeconds + seconds
        state = .running(endsAt: newEnd, totalSeconds: newTotal, exerciseName: name)

        task?.cancel()
        cancelNotification()
        let remaining = max(1, Int(newEnd.timeIntervalSinceNow.rounded(.up)))
        remainingSeconds = remaining
        scheduleNotification(seconds: remaining, exerciseName: name)
        updateLiveActivity(endsAt: newEnd)
        task = Task { await runCountdown(until: newEnd, exerciseName: name) }
    }

    // MARK: - Countdown loop

    private func runCountdown(until end: Date, exerciseName: String) async {
        while true {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            let rem = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
            await MainActor.run { remainingSeconds = rem }
            if rem == 0 { break }
        }
        await MainActor.run {
            state = .expired(exerciseName: exerciseName)
            HapticManager.restTimerExpired()
        }
    }

    // MARK: - Local Notifications (background alert)

    private static let notificationID = "fitnotes.rest.timer"

    private func scheduleNotification(seconds: Int, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer Complete"
        content.body = "Time to start your next set of \(exerciseName)"
        content.sound = .default
        content.categoryIdentifier = "REST_TIMER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationID]
        )
    }

    // MARK: - Live Activity (ActivityKit)

    private func startLiveActivity(endsAt: Date, exerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            totalSeconds: Int(endsAt.timeIntervalSinceNow.rounded())
        )
        let initialState = RestTimerAttributes.ContentState(
            endTime: endsAt,
            timerState: .running
        )
        let content = ActivityContent(state: initialState, staleDate: endsAt)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activity not available — silent fallback to notification-only
        }
    }

    private func updateLiveActivity(endsAt: Date) {
        guard let activity = currentActivity else { return }

        let updatedState = RestTimerAttributes.ContentState(
            endTime: endsAt,
            timerState: .running
        )
        let content = ActivityContent(state: updatedState, staleDate: endsAt)
        Task {
            await activity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let activity = currentActivity else { return }

        let finalState = RestTimerAttributes.ContentState(
            endTime: .now,
            timerState: .expired
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        Task {
            await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(5)))
            currentActivity = nil
        }
    }
}
