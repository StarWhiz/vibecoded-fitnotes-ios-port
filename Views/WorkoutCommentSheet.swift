//
//  WorkoutCommentSheet.swift
//  FitNotes iOS
//
//  Workout comment editor (product_roadmap.md 1.5).
//  Free-text note for the whole workout session.
//  One comment per date stored in WorkoutComment.
//

import SwiftUI
import SwiftData

struct WorkoutCommentSheet: View {
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Comment") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                }

                Section {
                    Text(workoutStore.date, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveComment()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                text = workoutStore.workoutComment
            }
        }
    }

    private func saveComment() {
        let targetDate = Calendar.current.startOfDay(for: workoutStore.date)
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: targetDate)!

        // Find existing comment for this date
        let descriptor = FetchDescriptor<WorkoutComment>(
            predicate: #Predicate<WorkoutComment> {
                $0.date >= targetDate && $0.date < nextDate
            }
        )
        let existing = try? context.fetch(descriptor).first

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Delete existing comment if text is empty
            if let existing {
                context.delete(existing)
            }
            workoutStore.workoutComment = ""
        } else if let existing {
            existing.text = text
            workoutStore.workoutComment = text
        } else {
            let comment = WorkoutComment(date: targetDate, text: text)
            context.insert(comment)
            workoutStore.workoutComment = text
        }

        try? context.save()
    }
}
