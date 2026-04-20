//
//  StreakCounterWidget.swift
//  FitNotes iOS Widget Extension
//
//  Small widget showing consecutive training days and longest streak.
//  product_roadmap.md section 3.3.
//

import SwiftData
import SwiftUI
import WidgetKit

struct StreakCounterWidget: Widget {
    let kind = "StreakCounterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakCounterView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak Counter")
        .description("Track your consecutive workout days.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Timeline

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: WidgetData.Streak?
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = fetchEntry()
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func fetchEntry() -> StreakEntry {
        guard let container = try? AppGroup.makeModelContainer() else {
            return StreakEntry(date: .now, streak: nil)
        }
        let context = ModelContext(container)
        let streak = try? WidgetData.fetchStreak(context: context)
        return StreakEntry(date: .now, streak: streak)
    }
}

// MARK: - View

struct StreakCounterView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(streakColor)

            Text("\(entry.streak?.currentStreak ?? 0)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(streakColor)

            Text(entry.streak?.currentStreak == 1 ? "day" : "days")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 8)

            HStack(spacing: 2) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                Text("\(entry.streak?.longestStreak ?? 0)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "fitnotes://calendar"))
    }

    private var streakColor: Color {
        let streak = entry.streak?.currentStreak ?? 0
        switch streak {
        case 0: return .secondary
        case 1...3: return .orange
        case 4...7: return .red
        default: return .purple
        }
    }
}
