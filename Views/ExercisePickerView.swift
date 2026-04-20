//
//  ExercisePickerView.swift
//  FitNotes iOS
//
//  Exercise picker grouped by Category with search (product_roadmap.md 1.1, 1.18).
//  Presented as a sheet from the home screen. Supports favourites filter.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    var onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @Query(sort: \Exercise.name)
    private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var showFavouritesOnly = false
    @State private var showAddExercise = false

    private var filteredExercises: [Exercise] {
        var exercises = allExercises
        if showFavouritesOnly {
            exercises = exercises.filter { $0.isFavourite }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            exercises = exercises.filter { $0.name.lowercased().contains(query) }
        }
        return exercises
    }

    private var groupedByCategory: [(WorkoutCategory, [Exercise])] {
        let exercises = filteredExercises
        var result: [(WorkoutCategory, [Exercise])] = []

        // Favourites pseudo-category at top
        if !showFavouritesOnly {
            let favs = exercises.filter { $0.isFavourite }
            if !favs.isEmpty {
                let pseudoCat = WorkoutCategory(
                    name: "Favourites",
                    colourARGB: Int32(bitPattern: 0xFFFFD700),
                    sortOrder: -1,
                    isBuiltIn: true
                )
                result.append((pseudoCat, favs))
            }
        }

        for category in categories {
            let catExercises = exercises.filter { $0.category?.persistentModelID == category.persistentModelID }
            if !catExercises.isEmpty {
                result.append((category, catExercises.sorted { $0.name < $1.name }))
            }
        }

        // Uncategorized
        let uncategorized = exercises.filter { $0.category == nil }
        if !uncategorized.isEmpty {
            let pseudoCat = WorkoutCategory(
                name: "Uncategorized",
                colourARGB: Int32(bitPattern: 0xFF888888),
                sortOrder: 999,
                isBuiltIn: false
            )
            result.append((pseudoCat, uncategorized))
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if allExercises.isEmpty {
                    emptyLibraryView
                } else if groupedByCategory.isEmpty {
                    emptySearchView
                } else {
                    List {
                        ForEach(groupedByCategory, id: \.0.name) { category, exercises in
                            Section {
                                ForEach(exercises) { exercise in
                                    Button {
                                        onSelect(exercise)
                                    } label: {
                                        ExercisePickerRow(exercise: exercise)
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 10, height: 10)
                                    Text(category.name)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if !allExercises.isEmpty {
                            Menu {
                                Toggle(isOn: $showFavouritesOnly) {
                                    Label("Favourites Only", systemImage: "star.fill")
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                        }
                        Button {
                            showAddExercise = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView()
            }
        }
    }

    private var emptyLibraryView: some View {
        ContentUnavailableView {
            Label("No Exercises Yet", systemImage: "dumbbell.fill")
        } description: {
            Text("Create your first exercise to get started.")
        } actions: {
            Button("Create Exercise") {
                showAddExercise = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptySearchView: some View {
        ContentUnavailableView.search(text: searchText)
    }
}

// MARK: - Exercise Picker Row

private struct ExercisePickerRow: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Text(exercise.exerciseType.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isFavourite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }
}

// MARK: - ExerciseType label extension

extension ExerciseType {
    var label: String {
        switch self {
        case .weightReps: return "Weight & Reps"
        case .cardio: return "Cardio"
        case .timed: return "Timed"
        case .unknown: return "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .weightReps: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .timed: return "timer"
        case .unknown: return "questionmark.circle"
        }
    }
}
