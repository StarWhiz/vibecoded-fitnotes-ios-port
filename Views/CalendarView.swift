//
//  CalendarView.swift
//  FitNotes iOS
//
//  Calendar view (product_roadmap.md 1.22).
//  Month grid with colored category dots for trained days.
//  List view mode shows reverse-chronological workout summaries.
//  Tapping a day opens workout detail.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(\.modelContext) private var context

    @Query(sort: \TrainingEntry.date, order: .reverse)
    private var allEntries: [TrainingEntry]

    @State private var displayDate = Date.now
    @State private var viewMode: ViewMode = .month
    @State private var selectedDate: Date? = nil
    @State private var showWorkoutDetail = false
    @State private var showFilters = false
    @State private var categoryFilter: Set<PersistentIdentifier> = []

    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case list = "List"
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = settingsStore.firstDayOfWeek == 1 ? 2 : 1 // Mon or Sun
        return cal
    }

    // Group entries by date for calendar dots
    private var entriesByDate: [Date: [TrainingEntry]] {
        Dictionary(grouping: filteredEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
    }

    private var filteredEntries: [TrainingEntry] {
        if categoryFilter.isEmpty { return allEntries }
        return allEntries.filter { entry in
            guard let catID = entry.exercise?.category?.persistentModelID else { return false }
            return categoryFilter.contains(catID)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // View mode picker
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch viewMode {
            case .month:
                monthView
            case .list:
                listView
            }
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: categoryFilter.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let date = selectedDate {
                WorkoutDetailView(date: date)
            }
        }
        .sheet(isPresented: $showFilters) {
            CategoryFilterView(selectedCategories: $categoryFilter)
        }
    }

    // MARK: - Month View

    private var monthView: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button {
                    displayDate = calendar.date(byAdding: .month, value: -1, to: displayDate)!
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(displayDate, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button {
                    displayDate = calendar.date(byAdding: .month, value: 1, to: displayDate)!
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { day in
                    if let day {
                        CalendarDayCell(
                            date: day,
                            entries: entriesByDate[calendar.startOfDay(for: day)] ?? [],
                            isToday: calendar.isDateInToday(day),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                        )
                        .onTapGesture {
                            selectedDate = day
                            let dayEntries = entriesByDate[calendar.startOfDay(for: day)]
                            if dayEntries != nil && !dayEntries!.isEmpty {
                                showWorkoutDetail = true
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            let dates = uniqueDates
            ForEach(dates, id: \.self) { date in
                Button {
                    selectedDate = date
                    showWorkoutDetail = true
                } label: {
                    WorkoutSummaryRow(
                        date: date,
                        entries: entriesByDate[date] ?? []
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private var uniqueDates: [Date] {
        Array(entriesByDate.keys).sorted(by: >)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayDate)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayDate))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        return days
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let entries: [TrainingEntry]
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption.monospacedDigit())
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .blue : .primary)

            // Category color dots
            if !entries.isEmpty {
                HStack(spacing: 2) {
                    let categories = uniqueCategories
                    ForEach(categories.prefix(3), id: \.persistentModelID) { cat in
                        Circle()
                            .fill(cat.color)
                            .frame(width: 5, height: 5)
                    }
                    if categories.count > 3 {
                        Circle()
                            .fill(.gray)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.15) : (isToday ? Color.blue.opacity(0.05) : .clear))
        )
    }

    private var uniqueCategories: [WorkoutCategory] {
        var seen = Set<PersistentIdentifier>()
        var result: [WorkoutCategory] = []
        for entry in entries {
            guard let cat = entry.exercise?.category else { continue }
            if seen.insert(cat.persistentModelID).inserted {
                result.append(cat)
            }
        }
        return result.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Workout Summary Row (List mode)

struct WorkoutSummaryRow: View {
    let date: Date
    let entries: [TrainingEntry]

    @Environment(AppSettingsStore.self) private var settingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(date, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.subheadline.bold())
                Spacer()
                Text("\(exerciseCount) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Category dots
                HStack(spacing: 3) {
                    ForEach(uniqueCategories.prefix(5), id: \.persistentModelID) { cat in
                        Circle()
                            .fill(cat.color)
                            .frame(width: 8, height: 8)
                    }
                }

                Text("\(entries.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let totalVol = settingsStore.display(kg: entries.reduce(0) { $0 + $1.volume })
                if totalVol > 0 {
                    Text("\(String(format: "%.0f", totalVol)) \(settingsStore.weightSymbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var exerciseCount: Int {
        Set(entries.compactMap { $0.exercise?.persistentModelID }).count
    }

    private var uniqueCategories: [WorkoutCategory] {
        var seen = Set<PersistentIdentifier>()
        var result: [WorkoutCategory] = []
        for entry in entries {
            guard let cat = entry.exercise?.category else { continue }
            if seen.insert(cat.persistentModelID).inserted {
                result.append(cat)
            }
        }
        return result.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Category Filter

struct CategoryFilterView: View {
    @Binding var selectedCategories: Set<PersistentIdentifier>

    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Clear All") {
                        selectedCategories.removeAll()
                    }
                    .disabled(selectedCategories.isEmpty)
                }

                Section("Categories") {
                    ForEach(categories) { category in
                        Button {
                            if selectedCategories.contains(category.persistentModelID) {
                                selectedCategories.remove(category.persistentModelID)
                            } else {
                                selectedCategories.insert(category.persistentModelID)
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategories.contains(category.persistentModelID) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
