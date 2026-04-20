//
//  ExerciseManagementView.swift
//  FitNotes iOS
//
//  Exercise management (product_roadmap.md 1.18).
//  Browse, search, add, edit, delete, and favourite exercises.
//  Grouped by category with search, details toggle.
//

import SwiftUI
import SwiftData

struct ExerciseManagementView: View {
    @Query(sort: \Exercise.name)
    private var exercises: [Exercise]

    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var showDetails = false
    @State private var showAddExercise = false
    @State private var editingExercise: Exercise?

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return exercises }
        let query = searchText.lowercased()
        return exercises.filter { $0.name.lowercased().contains(query) }
    }

    private var groupedByCategory: [(String, [Exercise])] {
        let filtered = filteredExercises
        var result: [(String, [Exercise])] = []

        for category in categories {
            let catExercises = filtered.filter { $0.category?.persistentModelID == category.persistentModelID }
            if !catExercises.isEmpty {
                result.append((category.name, catExercises))
            }
        }

        let uncategorized = filtered.filter { $0.category == nil }
        if !uncategorized.isEmpty {
            result.append(("Uncategorized", uncategorized))
        }

        return result
    }

    var body: some View {
        List {
            ForEach(groupedByCategory, id: \.0) { categoryName, exercises in
                Section(categoryName) {
                    ForEach(exercises) { exercise in
                        Button {
                            editingExercise = exercise
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                        if exercise.isFavourite {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.yellow)
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        Label(exercise.exerciseType.label, systemImage: exercise.exerciseType.iconName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if showDetails {
                                            let count = exercise.trainingEntries.count
                                            if count > 0 {
                                                Text("\(count) sets")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let lastDate = exercise.trainingEntries.map(\.date).max() {
                                                Text("Last: \(lastDate, format: .dateTime.month(.abbreviated).day())")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                exercise.isFavourite.toggle()
                                try? context.save()
                            } label: {
                                Label(exercise.isFavourite ? "Unfavourite" : "Favourite", systemImage: "star")
                            }
                            .tint(.yellow)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let exercise = exercises[index]
                            context.delete(exercise)
                        }
                        try? context.save()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises (\(exercises.count))")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showDetails.toggle()
                    } label: {
                        Image(systemName: showDetails ? "info.circle.fill" : "info.circle")
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
        .sheet(item: $editingExercise) { exercise in
            EditExerciseView(exercise: exercise)
        }
    }
}

// MARK: - Add Exercise View

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @State private var name = ""
    @State private var exerciseTypeRaw = 0
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var notes = ""
    @State private var isFavourite = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise Name", text: $name)
                }

                Section {
                    Picker("Type", selection: $exerciseTypeRaw) {
                        Text("Weight & Reps").tag(0)
                        Text("Cardio").tag(1)
                        Text("Timed").tag(3)
                    }

                    Picker("Category", selection: $selectedCategoryID) {
                        Text("None").tag(nil as PersistentIdentifier?)
                        ForEach(categories) { cat in
                            HStack {
                                Circle().fill(cat.color).frame(width: 10, height: 10)
                                Text(cat.name)
                            }
                            .tag(cat.persistentModelID as PersistentIdentifier?)
                        }
                    }

                    Toggle("Favourite", isOn: $isFavourite)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            exerciseTypeRaw: exerciseTypeRaw,
            isFavourite: isFavourite
        )
        exercise.notes = notes.isEmpty ? nil : notes
        if let catID = selectedCategoryID {
            exercise.category = categories.first { $0.persistentModelID == catID }
        }
        context.insert(exercise)
        try? context.save()
    }
}

// MARK: - Edit Exercise View

struct EditExerciseView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WorkoutCategory.sortOrder)
    private var categories: [WorkoutCategory]

    @State private var name = ""
    @State private var exerciseTypeRaw = 0
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var notes = ""
    @State private var isFavourite = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise Name", text: $name)
                }

                Section {
                    Picker("Type", selection: $exerciseTypeRaw) {
                        Text("Weight & Reps").tag(0)
                        Text("Cardio").tag(1)
                        Text("Timed").tag(3)
                    }

                    Picker("Category", selection: $selectedCategoryID) {
                        Text("None").tag(nil as PersistentIdentifier?)
                        ForEach(categories) { cat in
                            HStack {
                                Circle().fill(cat.color).frame(width: 10, height: 10)
                                Text(cat.name)
                            }
                            .tag(cat.persistentModelID as PersistentIdentifier?)
                        }
                    }

                    Toggle("Favourite", isOn: $isFavourite)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                Section("Info") {
                    LabeledContent("Total Sets", value: "\(exercise.trainingEntries.count)")
                    if let lastDate = exercise.trainingEntries.map(\.date).max() {
                        LabeledContent("Last Used") {
                            Text(lastDate, format: .dateTime.month().day().year())
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                } footer: {
                    Text("Deleting this exercise will permanently remove all \(exercise.trainingEntries.count) logged sets, goals, and favourites.")
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        applyChanges()
                        dismiss()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = exercise.name
                exerciseTypeRaw = exercise.exerciseTypeRaw
                selectedCategoryID = exercise.category?.persistentModelID
                notes = exercise.notes ?? ""
                isFavourite = exercise.isFavourite
            }
            .alert("Delete Exercise?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    context.delete(exercise)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete \(exercise.name) and all \(exercise.trainingEntries.count) logged sets. This cannot be undone.")
            }
        }
    }

    private func applyChanges() {
        exercise.name = name.trimmingCharacters(in: .whitespaces)
        exercise.exerciseTypeRaw = exerciseTypeRaw
        exercise.notes = notes.isEmpty ? nil : notes
        exercise.isFavourite = isFavourite
        if let catID = selectedCategoryID {
            exercise.category = categories.first { $0.persistentModelID == catID }
        } else {
            exercise.category = nil
        }
        try? context.save()
    }
}
