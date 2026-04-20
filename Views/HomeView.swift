//
//  HomeView.swift
//  FitNotes iOS
//
//  Home screen (product_roadmap.md 1.1, 1.5, 1.6, 1.26).
//  Defaults to today's date. Shows exercises in today's workout,
//  workout comment, timing controls, and per-workout actions
//  (share, copy, move, delete, reorder).
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(RestTimerStore.self) private var timerStore
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @State private var showExercisePicker = false
    @State private var showNavigationPanel = false
    @State private var showWorkoutComment = false
    @State private var showWorkoutTiming = false
    @State private var showShareSheet = false
    @State private var showShareOptions = false
    @State private var showCopyWorkout = false
    @State private var showMoveWorkout = false
    @State private var showDeleteConfirmation = false
    @State private var shareText = ""
    @State private var shareImage: UIImage? = nil
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 0) {
            dateHeader
            workoutCommentBanner
            exerciseList
        }
        .navigationTitle("FitNotes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNavigationPanel = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    workoutActionsMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                workoutStore.addExercise(exercise, context: context)
                showExercisePicker = false
            }
        }
        .sheet(isPresented: $showNavigationPanel) {
            NavigationPanelView()
        }
        .sheet(isPresented: $showWorkoutComment) {
            WorkoutCommentSheet()
        }
        .sheet(isPresented: $showWorkoutTiming) {
            WorkoutTimingSheet()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: shareText, image: shareImage)
        }
        .confirmationDialog("Share as...", isPresented: $showShareOptions, titleVisibility: .visible) {
            Button("Text Only") {
                shareAsTextOnly()
            }
            Button("Image Card") {
                shareAsImage()
            }
        }
        .sheet(isPresented: $showCopyWorkout) {
            CopyMoveWorkoutSheet(mode: .copy)
        }
        .sheet(isPresented: $showMoveWorkout) {
            CopyMoveWorkoutSheet(mode: .move)
        }
        .confirmationDialog("Delete selected exercises?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Handled by delete action
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            Button {
                navigateDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(workoutStore.date, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(workoutStore.date, format: .dateTime.month().day().year())
                    .font(.headline)
            }
            .onTapGesture {
                // Reset to today
                navigateTo(date: Calendar.current.startOfDay(for: .now))
            }

            Spacer()

            Button {
                navigateDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(Calendar.current.isDateInToday(workoutStore.date))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Workout Comment Banner

    @ViewBuilder
    private var workoutCommentBanner: some View {
        if !workoutStore.workoutComment.isEmpty {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundStyle(.secondary)
                Text(workoutStore.workoutComment)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .onTapGesture { showWorkoutComment = true }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        Group {
            if workoutStore.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "dumbbell")
                } description: {
                    Text("Tap + to add an exercise to today's workout.")
                }
            } else {
                List {
                    // Workout summary header
                    if workoutStore.isWorkoutActive || workoutStore.totalSets > 0 {
                        workoutSummarySection
                    }

                    // Exercise sessions
                    ForEach(Array(workoutStore.sessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            TrainingView(sessionIndex: index)
                        } label: {
                            ExerciseSessionRow(session: session)
                        }
                    }
                    .onMove { source, destination in
                        workoutStore.moveExercise(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            try? workoutStore.removeExercise(at: index, context: context)
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            }
        }
    }

    // MARK: - Workout Summary

    private var workoutSummarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(workoutStore.sessions.count) exercises")
                        .font(.subheadline)
                    Text("\(workoutStore.totalSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    let vol = settingsStore.display(kg: workoutStore.totalVolume)
                    Text("\(vol, specifier: "%.0f") \(settingsStore.weightSymbol)")
                        .font(.subheadline.bold())
                    Text("total volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Workout timing row
            if let session = workoutStore.workoutSession {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.blue)
                    if let duration = session.duration {
                        Text(formatDuration(duration))
                    } else if session.isActive {
                        Text("In progress...")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    if session.isActive {
                        Button("Stop") {
                            workoutStore.endWorkout(context: context)
                            HapticManager.workoutComplete()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
        }
    }

    // MARK: - Workout Actions Menu (1.26)

    @ViewBuilder
    private var workoutActionsMenu: some View {
        Button {
            showWorkoutComment = true
        } label: {
            Label("Comment Workout", systemImage: "text.bubble")
        }

        Button {
            showWorkoutTiming = true
        } label: {
            Label("Time Workout", systemImage: "timer")
        }

        if !workoutStore.isWorkoutActive && workoutStore.workoutSession == nil {
            Button {
                workoutStore.startWorkout(context: context)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
        } else if workoutStore.isWorkoutActive {
            Button {
                workoutStore.endWorkout(context: context)
                HapticManager.workoutComplete()
            } label: {
                Label("End Workout", systemImage: "stop.fill")
            }
        }

        Divider()

        Button {
            showShareOptions = true
        } label: {
            Label("Share Workout", systemImage: "square.and.arrow.up")
        }
        .disabled(workoutStore.sessions.isEmpty)

        Button {
            showCopyWorkout = true
        } label: {
            Label("Copy Workout", systemImage: "doc.on.doc")
        }
        .disabled(workoutStore.sessions.isEmpty)

        Button {
            showMoveWorkout = true
        } label: {
            Label("Move Workout", systemImage: "arrow.right.doc.on.clipboard")
        }
        .disabled(workoutStore.sessions.isEmpty)

        Divider()

        Button {
            isEditing.toggle()
        } label: {
            Label(isEditing ? "Done Editing" : "Reorder Exercises", systemImage: "arrow.up.arrow.down")
        }
        .disabled(workoutStore.sessions.isEmpty)
    }

    // MARK: - Navigation

    private func navigateDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: workoutStore.date) else { return }
        navigateTo(date: newDate)
    }

    private func navigateTo(date: Date) {
        try? workoutStore.load(for: date, context: context)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }
        return String(format: "%dm %02ds", m, s)
    }

    // MARK: - Sharing (3.10)

    private func shareAsTextOnly() {
        shareText = WorkoutShareFormatter.format(
            sessions: workoutStore.sessions,
            date: workoutStore.date,
            comment: workoutStore.workoutComment,
            workoutSession: workoutStore.workoutSession,
            isImperial: settingsStore.isImperial
        )
        shareImage = nil
        showShareSheet = true
    }

    private func shareAsImage() {
        shareImage = WorkoutCardRenderer.render(
            sessions: workoutStore.sessions,
            date: workoutStore.date,
            comment: workoutStore.workoutComment,
            workoutSession: workoutStore.workoutSession,
            isImperial: settingsStore.isImperial
        )
        shareText = ""
        showShareSheet = true
    }
}

// MARK: - Exercise Session Row

struct ExerciseSessionRow: View {
    let session: ExerciseSession
    @Environment(AppSettingsStore.self) private var settingsStore

    var body: some View {
        HStack(spacing: 12) {
            // Workout group color indicator
            if let group = session.workoutGroup {
                RoundedRectangle(cornerRadius: 2)
                    .fill(group.color)
                    .frame(width: 4, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.exercise.name)
                        .font(.body.weight(.medium))
                    if session.exercise.isFavourite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                if session.sets.isEmpty {
                    Text("No sets logged")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(setsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(session.sets.count)")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var setsSummary: String {
        let exercise = session.exercise
        let type = exercise.exerciseType

        if type.usesWeight {
            let weights = session.sets.map { settingsStore.display(kg: $0.weightKg) }
            if let maxW = weights.max() {
                let maxReps = session.sets.filter { settingsStore.display(kg: $0.weightKg) == maxW }.map(\.reps).max() ?? 0
                return "\(formatWeight(maxW)) \(settingsStore.weightSymbol) x \(maxReps) (best set)"
            }
        } else if type == .cardio {
            let totalDist = session.sets.reduce(0.0) { $0 + $1.distanceMetres }
            let totalTime = session.sets.reduce(0) { $0 + $1.durationSeconds }
            return "\(String(format: "%.1f", totalDist / 1000)) km, \(totalTime / 60) min"
        } else if type == .timed {
            let totalTime = session.sets.reduce(0) { $0 + $1.durationSeconds }
            return "\(totalTime)s total"
        }
        return "\(session.sets.count) sets"
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
