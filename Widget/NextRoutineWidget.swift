//
//  NextRoutineWidget.swift
//  FitNotes iOS Widget Extension
//
//  Medium widget showing which routine day is up next with key exercises.
//  product_roadmap.md section 3.3.
//

import SwiftData
import SwiftUI
import WidgetKit

struct NextRoutineWidget: Widget {
    let kind = "NextRoutineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextRoutineProvider()) { entry in
            NextRoutineView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Routine Day")
        .description("See which routine day is up next.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline

struct NextRoutineEntry: TimelineEntry {
    let date: Date
    let routine: WidgetData.NextRoutine?
}

struct NextRoutineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextRoutineEntry {
        NextRoutineEntry(date: .now, routine: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextRoutineEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextRoutineEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh every hour — routine data changes infrequently
        let nextRefresh = Date.now.addingTimeInterval(60 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func fetchEntry() -> NextRoutineEntry {
        guard let container = try? AppGroup.makeModelContainer() else {
            return NextRoutineEntry(date: .now, routine: nil)
        }
        let context = ModelContext(container)
        let routine = try? WidgetData.fetchNextRoutine(context: context)
        return NextRoutineEntry(date: .now, routine: routine)
    }
}

// MARK: - View

struct NextRoutineView: View {
    let entry: NextRoutineEntry

    var body: some View {
        if let routine = entry.routine {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundStyle(.blue)
                    Text(routine.routineName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(routine.sectionName)
                    .font(.headline)

                ForEach(routine.exercises.prefix(4), id: \.self) { name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.blue.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }

                if routine.exercises.count > 4 {
                    Text("+\(routine.exercises.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .widgetURL(URL(string: "fitnotes://routine/next"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No routines")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Create a routine to see it here")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
