//
//  LastWorkoutWidget.swift
//  FitNotes iOS Widget Extension
//
//  Large widget showing the most recent workout's date, total volume,
//  exercises, and duration. product_roadmap.md section 3.3.
//

import SwiftData
import SwiftUI
import WidgetKit

struct LastWorkoutWidget: Widget {
    let kind = "LastWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastWorkoutProvider()) { entry in
            LastWorkoutView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Workout")
        .description("Summary of your most recent workout.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Timeline

struct LastWorkoutEntry: TimelineEntry {
    let date: Date
    let workout: WidgetData.LastWorkout?
}

struct LastWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastWorkoutEntry {
        LastWorkoutEntry(date: .now, workout: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastWorkoutEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastWorkoutEntry>) -> Void) {
        let entry = fetchEntry()
        let nextRefresh = Date.now.addingTimeInterval(30 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func fetchEntry() -> LastWorkoutEntry {
        guard let container = try? AppGroup.makeModelContainer() else {
            return LastWorkoutEntry(date: .now, workout: nil)
        }
        let context = ModelContext(container)
        let workout = try? WidgetData.fetchLastWorkout(context: context)
        return LastWorkoutEntry(date: .now, workout: workout)
    }
}

// MARK: - View

struct LastWorkoutView: View {
    let entry: LastWorkoutEntry

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        if let workout = entry.workout {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Workout")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(Self.dateFormatter.string(from: workout.date))
                            .font(.headline)
                    }
                    Spacer()
                    if let mins = workout.durationMinutes {
                        Label("\(mins) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Stats row
                HStack(spacing: 16) {
                    StatBlock(
                        value: formatVolume(workout.totalVolumeLbs),
                        label: "Volume (lbs)",
                        icon: "scalemass.fill"
                    )
                    StatBlock(
                        value: "\(workout.totalSets)",
                        label: "Sets",
                        icon: "number"
                    )
                    StatBlock(
                        value: "\(workout.exercises.count)",
                        label: "Exercises",
                        icon: "figure.strengthtraining.traditional"
                    )
                }

                Divider()

                // Exercise list
                ForEach(workout.exercises.prefix(6)) { exercise in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFromARGB(exercise.categoryColor))
                            .frame(width: 4, height: 16)

                        Text(exercise.name)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text("\(exercise.setCount) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if workout.exercises.count > 6 {
                    Text("+\(workout.exercises.count - 6) more exercises")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .widgetURL(URL(string: "fitnotes://workout/last"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Complete a workout to see it here")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatVolume(_ lbs: Double) -> String {
        if lbs >= 1000 {
            return String(format: "%.1fk", lbs / 1000.0)
        }
        return String(format: "%.0f", lbs)
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

private struct StatBlock: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
