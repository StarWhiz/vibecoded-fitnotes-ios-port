//
//  TrainingView.swift
//  FitNotes iOS
//
//  Training screen (product_roadmap.md 1.1, 1.2, 1.3, 1.4, 1.8, 1.13).
//  Core set logging view: weight/reps input, save/update/delete,
//  logged sets list, PR indicators, rest timer integration,
//  exercise notes, and set-level comments.
//

import SwiftUI
import SwiftData

struct TrainingView: View {
    let sessionIndex: Int

    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(RestTimerStore.self) private var timerStore
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    // Input state
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var distanceText = ""
    @State private var durationMinText = ""
    @State private var durationSecText = ""

    // UI state
    @State private var showExerciseNotes = false
    @State private var showOneRMCalc = false
    @State private var showSetCalc = false
    @State private var showPlateCalc = false
    @State private var showHistory = false
    @State private var prAnimation = false
    @State private var commentText = ""
    @State private var showCommentField = false

    private var session: ExerciseSession? {
        workoutStore.sessions.indices.contains(sessionIndex)
            ? workoutStore.sessions[sessionIndex]
            : nil
    }

    private var exercise: Exercise? { session?.exercise }
    private var exerciseType: ExerciseType { exercise?.exerciseType ?? .weightReps }

    private var isEditing: Bool { workoutStore.selectedEntryID != nil }

    var body: some View {
        // List is the root view so it gets a stable full-screen frame from NavigationStack.
        // Putting List inside VStack caused expensive layout recalculation on every keystroke.
        Group {
            if let exercise {
                loggedSetsList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            exerciseHeader(exercise)
                            Divider()
                            inputSection
                            actionButtons
                            restTimerSection
                        }
                        .background(.background)
                    }
            } else {
                ContentUnavailableView("Exercise Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(exercise?.name ?? "Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showExerciseNotes) {
            if let exercise {
                ExerciseNotesSheet(exercise: exercise)
            }
        }
        .sheet(isPresented: $showOneRMCalc) {
            OneRMCalculatorView(exercise: exercise)
        }
        .sheet(isPresented: $showSetCalc) {
            SetCalculatorView(exercise: exercise) { weight in
                weightText = formatWeight(weight)
            }
        }
        .sheet(isPresented: $showPlateCalc) {
            PlateCalculatorView(targetWeight: Double(weightText) ?? 0)
        }
        .sheet(isPresented: $showHistory) {
            if let exercise {
                ExerciseOverviewView(exercise: exercise)
            }
        }
        .onAppear { prefillFromLastSession() }
        .overlay {
            if prAnimation {
                PRCelebrationOverlay()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            prAnimation = false
                        }
                    }
            }
        }
    }

    // MARK: - Exercise Header

    private func exerciseHeader(_ exercise: Exercise) -> some View {
        HStack {
            if let cat = exercise.category {
                RoundedRectangle(cornerRadius: 3)
                    .fill(cat.color)
                    .frame(width: 5, height: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.headline)
                if let cat = exercise.category {
                    Text(cat.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if exercise.notes != nil {
                Button {
                    showExerciseNotes = true
                } label: {
                    Image(systemName: "note.text")
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            if exerciseType.usesWeight {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight (\(settingsStore.weightSymbol))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }

                    // Weight increment buttons
                    VStack(spacing: 4) {
                        Button {
                            adjustWeight(by: settingsStore.display(kg: exercise?.weightIncrementKg ?? settingsStore.defaultWeightIncrementKg))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        Button {
                            adjustWeight(by: -settingsStore.display(kg: exercise?.weightIncrementKg ?? settingsStore.defaultWeightIncrementKg))
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }

            if exerciseType.usesReps {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                            .frame(maxWidth: 100)

                        // Quick rep buttons
                        ForEach([5, 8, 10, 12], id: \.self) { rep in
                            Button("\(rep)") {
                                repsText = "\(rep)"
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }
            }

            if exerciseType.usesDistance {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance (km)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $distanceText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2.monospacedDigit())
                }
            }

            if exerciseType.usesDuration {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $durationMinText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $durationSecText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }
                }
            }

            // Set comment field
            if showCommentField || !commentText.isEmpty {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    TextField("Set comment...", text: $commentText)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if isEditing {
                Button(role: .destructive) {
                    deleteSelectedSet()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button {
                    clearSelection()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
            }

            Button {
                showCommentField.toggle()
            } label: {
                Image(systemName: "text.bubble")
            }
            .buttonStyle(.bordered)
            .tint(commentText.isEmpty ? .secondary : .blue)

            Spacer()

            Button {
                saveSet()
            } label: {
                Label(isEditing ? "Update" : "Save", systemImage: "checkmark.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Rest Timer Section

    @ViewBuilder
    private var restTimerSection: some View {
        if case .running(_, _, let name) = timerStore.state, name == exercise?.name {
            HStack(spacing: 8) {
                Image(systemName: "timer").foregroundStyle(.orange)
                Text("Rest: \(timerStore.remainingSeconds)s")
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Button("+30s") { timerStore.addTime(30) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button { timerStore.pause() } label: {
                    Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
                }
                .buttonStyle(.bordered)
                Button { timerStore.stop() } label: {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
        } else if case .paused(_, _, let name) = timerStore.state, name == exercise?.name {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle").foregroundStyle(.orange)
                Text("Paused: \(timerStore.remainingSeconds)s")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button { timerStore.restart() } label: {
                    Image(systemName: "arrow.counterclockwise").foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                Button { timerStore.resume() } label: {
                    Label("Resume", systemImage: "play.fill").foregroundStyle(.orange)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.05))
        }
    }

    // MARK: - Logged Sets List

    private var loggedSetsList: some View {
        List {
            if let session, !session.sets.isEmpty {
                Section("Logged Sets") {
                    ForEach(Array(session.sets.enumerated()), id: \.element.persistentModelID) { index, entry in
                        SetRowView(
                            entry: entry,
                            setNumber: index + 1,
                            isSelected: workoutStore.selectedEntryID == entry.persistentModelID
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectEntry(entry)
                        }
                    }
                }

                // Mark sets complete toggle
                if settingsStore.markSetsComplete {
                    Section {
                        let completedCount = session.sets.filter(\.isComplete).count
                        ProgressView(value: Double(completedCount), total: Double(session.sets.count))
                        Text("\(completedCount)/\(session.sets.count) sets complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showExerciseNotes = true
                } label: {
                    Label("Exercise Notes", systemImage: "note.text")
                }
                Button {
                    showHistory = true
                } label: {
                    Label("History & Stats", systemImage: "chart.bar")
                }
                Divider()
                Button {
                    showOneRMCalc = true
                } label: {
                    Label("1RM Calculator", systemImage: "function")
                }
                Button {
                    showSetCalc = true
                } label: {
                    Label("Set Calculator", systemImage: "percent")
                }
                Button {
                    showPlateCalc = true
                } label: {
                    Label("Plate Calculator", systemImage: "circle.grid.2x1.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Actions

    private func saveSet() {
        guard let exercise else { return }
        let weightKg = settingsStore.kg(from: Double(weightText) ?? 0)
        let reps = Int(repsText) ?? 0
        let distance = (Double(distanceText) ?? 0) * 1000  // km → metres
        let durationSec = (Int(durationMinText) ?? 0) * 60 + (Int(durationSecText) ?? 0)

        let entry: TrainingEntry
        if let selectedID = workoutStore.selectedEntryID,
           let existing = session?.sets.first(where: { $0.persistentModelID == selectedID }) {
            entry = existing
            entry.weightKg = weightKg
            entry.reps = reps
            entry.distanceMetres = distance
            entry.durationSeconds = durationSec
        } else {
            entry = TrainingEntry(date: workoutStore.date, weightKg: weightKg, reps: reps)
            entry.distanceMetres = distance
            entry.durationSeconds = durationSec
            entry.exercise = exercise
            entry.weightUnitRaw = settingsStore.isImperial ? 2 : 0
        }

        do {
            let result = try workoutStore.saveSet(entry, context: context)

            // Handle set comment
            if !commentText.isEmpty {
                if entry.comment != nil {
                    entry.comment?.text = commentText
                } else {
                    let comment = SetComment(text: commentText)
                    comment.trainingEntry = entry
                    context.insert(comment)
                }
                try? context.save()
            } else if let existingComment = entry.comment, commentText.isEmpty {
                context.delete(existingComment)
                try? context.save()
            }

            // PR celebration
            if result.isRecord {
                prAnimation = true
                HapticManager.personalRecord()
            } else {
                HapticManager.setSaved()
            }

            // Auto-start rest timer
            if settingsStore.restTimerAutoStart {
                let seconds = exercise.defaultRestTimeSeconds ?? settingsStore.restTimerSeconds
                timerStore.start(seconds: seconds, exerciseName: exercise.name)
            }

            // Auto-advance
            if settingsStore.autoSelectNextSet {
                workoutStore.advanceToNextSet()
            }

            clearInputs()
        } catch {
            // Handle error silently — data stays in fields for retry
        }
    }

    private func deleteSelectedSet() {
        guard let selectedID = workoutStore.selectedEntryID,
              let entry = session?.sets.first(where: { $0.persistentModelID == selectedID }) else { return }

        try? workoutStore.deleteSet(entry, context: context)
        HapticManager.setDeleted()
        clearInputs()
    }

    private func selectEntry(_ entry: TrainingEntry) {
        workoutStore.selectedEntryID = entry.persistentModelID
        weightText = formatWeight(settingsStore.display(kg: entry.weightKg))
        repsText = entry.reps > 0 ? "\(entry.reps)" : ""
        distanceText = entry.distanceMetres > 0 ? String(format: "%.2f", entry.distanceMetres / 1000) : ""
        durationMinText = entry.durationSeconds > 0 ? "\(entry.durationSeconds / 60)" : ""
        durationSecText = entry.durationSeconds > 0 ? "\(entry.durationSeconds % 60)" : ""
        commentText = entry.comment?.text ?? ""
        showCommentField = !commentText.isEmpty
    }

    private func clearSelection() {
        workoutStore.selectedEntryID = nil
        clearInputs()
    }

    private func clearInputs() {
        workoutStore.selectedEntryID = nil
        weightText = ""
        repsText = ""
        distanceText = ""
        durationMinText = ""
        durationSecText = ""
        commentText = ""
        showCommentField = false
    }

    private func prefillFromLastSession() {
        guard let exercise else { return }
        // Pre-fill from last session's first set
        let allEntries = exercise.trainingEntries
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: workoutStore.date) }
            .sorted { $0.date > $1.date }

        guard let lastEntry = allEntries.first else { return }

        if exerciseType.usesWeight {
            weightText = formatWeight(settingsStore.display(kg: lastEntry.weightKg))
        }
        if exerciseType.usesReps {
            repsText = lastEntry.reps > 0 ? "\(lastEntry.reps)" : ""
        }
    }

    private func adjustWeight(by amount: Double) {
        let current = Double(weightText) ?? 0
        let newWeight = max(0, current + amount)
        weightText = formatWeight(newWeight)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - PR Celebration Overlay

struct PRCelebrationOverlay: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text("Personal Record!")
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.5)) {
                opacity = 0
            }
        }
    }
}
