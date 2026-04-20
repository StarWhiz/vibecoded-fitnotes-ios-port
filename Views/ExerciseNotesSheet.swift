//
//  ExerciseNotesSheet.swift
//  FitNotes iOS
//
//  Per-exercise notes editor (product_roadmap.md 1.3).
//  Shows and edits exercise.notes, plus per-exercise overrides
//  (weight increment, default rest time, default graph).
//

import SwiftUI
import SwiftData

struct ExerciseNotesSheet: View {
    @Bindable var exercise: Exercise
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var notesText: String = ""
    @State private var restTimeText: String = ""
    @State private var incrementText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    TextEditor(text: $notesText)
                        .frame(minHeight: 120)
                }

                Section("Exercise Overrides") {
                    HStack {
                        Text("Weight Increment (\(settingsStore.weightSymbol))")
                        Spacer()
                        TextField("Default", text: $incrementText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Rest Timer (seconds)")
                        Spacer()
                        TextField("Default", text: $restTimeText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Info") {
                    LabeledContent("Type", value: exercise.exerciseType.label)
                    LabeledContent("Category", value: exercise.category?.name ?? "None")
                    LabeledContent("Total Sets", value: "\(exercise.trainingEntries.count)")
                }
            }
            .navigationTitle("Exercise Notes")
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
                }
            }
            .onAppear {
                notesText = exercise.notes ?? ""
                if let inc = exercise.weightIncrementKg {
                    incrementText = String(format: "%.1f", settingsStore.display(kg: inc))
                }
                if let rest = exercise.defaultRestTimeSeconds {
                    restTimeText = "\(rest)"
                }
            }
        }
    }

    private func applyChanges() {
        exercise.notes = notesText.isEmpty ? nil : notesText

        if let inc = Double(incrementText), inc > 0 {
            exercise.weightIncrementKg = settingsStore.kg(from: inc)
        } else {
            exercise.weightIncrementKg = nil
        }

        if let rest = Int(restTimeText), rest > 0 {
            exercise.defaultRestTimeSeconds = rest
        } else {
            exercise.defaultRestTimeSeconds = nil
        }

        try? context.save()
    }
}
