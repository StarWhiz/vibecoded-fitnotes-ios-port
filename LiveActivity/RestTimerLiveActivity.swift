//
//  RestTimerLiveActivity.swift
//  FitNotes iOS Widget Extension
//
//  Live Activity UI for rest timer as defined in product_roadmap.md section 3.2
//  Renders on Dynamic Island (compact + expanded) and Lock Screen.
//
//  This file belongs in the WidgetKit extension target alongside the home screen widgets.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // MARK: - Lock Screen / StandBy banner
            LockScreenTimerView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.exerciseName, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                        .monospacedDigit()
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: context.state.endTime.addingTimeInterval(
                            -Double(context.attributes.totalSeconds)
                        )...context.state.endTime,
                        countsDown: true
                    )
                    .tint(.blue)
                    .padding(.horizontal, 4)
                }
                DynamicIslandExpandedRegion(.center) {}
            } compactLeading: {
                // MARK: - Compact leading: timer icon
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
                    .imageScale(.medium)
            } compactTrailing: {
                // MARK: - Compact trailing: countdown
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 36)
            } minimal: {
                // MARK: - Minimal: just the countdown
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundStyle(.blue.opacity(0.3))

                ProgressView(
                    timerInterval: context.state.endTime.addingTimeInterval(
                        -Double(context.attributes.totalSeconds)
                    )...context.state.endTime,
                    countsDown: true
                ) {
                    // Empty label — the time is shown beside the ring
                }
                .progressViewStyle(.circular)
                .tint(.blue)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Rest Timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(context.attributes.exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Skip button via deep link
            Link(destination: URL(string: "fitnotes://timer/skip")!) {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.blue.opacity(0.5), in: Circle())
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

#if DEBUG
struct RestTimerLiveActivity_Previews: PreviewProvider {
    static let attributes = RestTimerAttributes(exerciseName: "Bench Press", totalSeconds: 120)
    static let state = RestTimerAttributes.ContentState(
        endTime: .now.addingTimeInterval(90),
        timerState: .running
    )

    static var previews: some View {
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")

        attributes
            .previewContext(state, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")

        attributes
            .previewContext(state, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
#endif
