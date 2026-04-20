//
//  NavigationPanelView.swift
//  FitNotes iOS
//
//  Slide-out navigation panel (product_roadmap.md 1.7).
//  Lists all exercises in today's workout with set counts.
//  Allows jump-to and reorder via drag.
//

import SwiftUI

struct NavigationPanelView: View {
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if workoutStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "list.bullet",
                        description: Text("Add exercises to see them here.")
                    )
                } else {
                    ForEach(Array(workoutStore.sessions.enumerated()), id: \.element.id) { index, session in
                        Button {
                            workoutStore.activeSessionIndex = index
                            dismiss()
                        } label: {
                            HStack {
                                if let group = session.workoutGroup {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(group.color)
                                        .frame(width: 4, height: 32)
                                }

                                VStack(alignment: .leading) {
                                    Text(session.exercise.name)
                                        .font(.body)
                                        .foregroundStyle(index == workoutStore.activeSessionIndex ? .blue : .primary)
                                    if let cat = session.exercise.category {
                                        Text(cat.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text("\(session.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()

                                if index == workoutStore.activeSessionIndex {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        workoutStore.moveExercise(from: source, to: destination)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
