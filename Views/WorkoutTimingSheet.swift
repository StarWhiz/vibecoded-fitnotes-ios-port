//
//  WorkoutTimingSheet.swift
//  FitNotes iOS
//
//  Workout timing controls (product_roadmap.md 1.6).
//  Start/stop timer, manual entry, shows duration.
//  Uses WorkoutSession model via ActiveWorkoutStore.
//

import SwiftUI
import SwiftData

struct WorkoutTimingSheet: View {
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var manualStart = Date.now
    @State private var manualEnd = Date.now
    @State private var showManualEntry = false

    private var session: WorkoutSession? { workoutStore.workoutSession }

    var body: some View {
        NavigationStack {
            Form {
                // Current status
                Section("Workout Timer") {
                    if let session {
                        if session.isActive {
                            HStack {
                                Image(systemName: "record.circle")
                                    .foregroundStyle(.red)
                                Text("In Progress")
                                    .font(.headline)
                                Spacer()
                                if let start = session.startDateTime {
                                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                                        Text(formatDuration(Date.now.timeIntervalSince(start)))
                                            .font(.title2.monospacedDigit().bold())
                                    }
                                }
                            }

                            if let start = session.startDateTime {
                                LabeledContent("Started") {
                                    Text(start, format: .dateTime.hour().minute())
                                }
                            }

                            Button(role: .destructive) {
                                workoutStore.endWorkout(context: context)
                            } label: {
                                Label("Stop Workout", systemImage: "stop.fill")
                            }
                        } else if let duration = session.duration {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Completed")
                                    .font(.headline)
                                Spacer()
                                Text(formatDuration(duration))
                                    .font(.title2.monospacedDigit().bold())
                            }

                            if let start = session.startDateTime {
                                LabeledContent("Started") {
                                    Text(start, format: .dateTime.hour().minute())
                                }
                            }
                            if let end = session.endDateTime {
                                LabeledContent("Ended") {
                                    Text(end, format: .dateTime.hour().minute())
                                }
                            }

                            Button {
                                workoutStore.startWorkout(context: context)
                            } label: {
                                Label("Restart Workout", systemImage: "play.fill")
                            }
                        }
                    } else {
                        Button {
                            workoutStore.startWorkout(context: context)
                        } label: {
                            Label("Start Workout", systemImage: "play.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // Manual entry
                Section {
                    DisclosureGroup("Manual Entry", isExpanded: $showManualEntry) {
                        DatePicker("Start Time", selection: $manualStart, displayedComponents: [.hourAndMinute])
                        DatePicker("End Time", selection: $manualEnd, displayedComponents: [.hourAndMinute])

                        let duration = manualEnd.timeIntervalSince(manualStart)
                        if duration > 0 {
                            LabeledContent("Duration") {
                                Text(formatDuration(duration))
                                    .monospacedDigit()
                            }
                        }

                        Button("Apply Manual Times") {
                            applyManualTimes()
                        }
                        .disabled(manualEnd <= manualStart)
                    }
                }
            }
            .navigationTitle("Workout Timing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let start = session?.startDateTime {
                    manualStart = start
                }
                if let end = session?.endDateTime {
                    manualEnd = end
                } else {
                    manualEnd = .now
                }
            }
        }
    }

    private func applyManualTimes() {
        if let session {
            session.startDateTime = manualStart
            session.endDateTime = manualEnd
        } else {
            let session = WorkoutSession(date: workoutStore.date)
            session.startDateTime = manualStart
            session.endDateTime = manualEnd
            context.insert(session)
            workoutStore.workoutSession = session
        }
        try? context.save()
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
