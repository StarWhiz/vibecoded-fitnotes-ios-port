//
//  TodayWorkoutWidget.swift
//  FitNotes iOS Widget Extension
//
//  Medium widget showing today's exercise list with set counts and
//  a "Start Workout" deep link. product_roadmap.md section 3.3.
//

import SwiftData
import SwiftUI
import WidgetKit

struct TodayWorkoutWidget: Widget {
    let kind = "TodayWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWorkoutProvider()) { entry in
            TodayWorkoutView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Workout")
        .description("See today's exercises and set counts at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline

struct TodayWorkoutEntry: TimelineEntry {
    let date: Date
    let workout: WidgetData.TodayWorkout?
}

struct TodayWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWorkoutEntry {
        TodayWorkoutEntry(date: .now, workout: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWorkoutEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWorkoutEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh at midnight or in 15 minutes, whichever is sooner
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        let fifteenMin = Date.now.addingTimeInterval(15 * 60)
        let nextRefresh = min(midnight, fifteenMin)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func fetchEntry() -> TodayWorkoutEntry {
        guard let container = try? AppGroup.makeModelContainer() else {
            return TodayWorkoutEntry(date: .now, workout: nil)
        }
        let context = ModelContext(container)
        let workout = try? WidgetData.fetchTodayWorkout(context: context)
        return TodayWorkoutEntry(date: .now, workout: workout)
    }
}

// MARK: - View

struct TodayWorkoutView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        if let workout = entry.workout, !workout.exercises.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today's Workout")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(workout.totalSets) sets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(workout.exercises.prefix(4)) { exercise in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFromARGB(exercise.categoryColor))
                            .frame(width: 4, height: 16)

                        Text(exercise.name)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text("\(exercise.setCount)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if workout.exercises.count > 4 {
                    Text("+\(workout.exercises.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .widgetURL(URL(string: "fitnotes://workout/today"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No workout yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Tap to start")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "fitnotes://workout/today"))
        }
    }

    private func colorFromARGB(_ argb: Int32) -> Color {
        let u = UInt32(bitPattern: argb)
        return Color(
            .sRGB,
            red: Double((u >> 16) & 0xFF) / 255.0,
            green: Double((u >> 8) & 0xFF) / 255.0,
            blue: Double(u & 0xFF) / 255.0,
            opacity: Double((u >> 24) & 0xFF) / 255.0
        )
    }
}
