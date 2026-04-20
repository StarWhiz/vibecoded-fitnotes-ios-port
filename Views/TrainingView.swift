//
//  TrainingView.swift
//  FitNotes iOS
//
//  Training screen (product_roadmap.md 1.1, 1.2, 1.3, 1.4, 1.8, 1.13).
//  Core set logging view: weight/reps input, save/update/delete,
//  logged sets list, PR indicators, rest timer integration,
//  exercise notes, and set-level comments.
//
//  Input state is isolated in TrainingInputState (@Observable) so that
//  text-field keystrokes only re-render TrainingInputCard, not the parent
//  view which owns the (expensive) logged sets List.
//

import SwiftUI
import SwiftData

// @Observable so mutations only invalidate TrainingInputCard, not TrainingView.
@Observable
final class TrainingInputState {
    var weightText = ""
    var repsText = ""
    var distanceText = ""
    var durationMinText = ""
    var durationSecText = ""
    var commentText = ""
    var showCommentField = false
}

struct TrainingView: View {
    let sessionIndex: Int

    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @State private var inputState = TrainingInputState()
    @State private var showExerciseNotes = false
    @State private var showOneRMCalc = false
    @State private var showSetCalc = false
    @State private var showPlateCalc = false
    @State private var plateCalcWeight: Double = 0
    @State private var showHistory = false
    @State private var prAnimation = false

    private var session: ExerciseSession? {
        workoutStore.sessions.indices.contains(sessionIndex)
            ? workoutStore.sessions[sessionIndex]
            : nil
    }

    private var exercise: Exercise? { session?.exercise }

    var body: some View {
        Group {
            if let exercise {
                loggedSetsList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            exerciseHeader(exercise)
                            Divider()
                            TrainingInputCard(
                                exercise: exercise,
                                sessionIndex: sessionIndex,
                                inputState: inputState,
                                onPR: { prAnimation = true }
                            )
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
            if let exercise { ExerciseNotesSheet(exercise: exercise) }
        }
        .sheet(isPresented: $showOneRMCalc) {
            OneRMCalculatorView(exercise: exercise)
        }
        .sheet(isPresented: $showSetCalc) {
            SetCalculatorView(exercise: exercise) { weight in
                inputState.weightText = weight.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", weight)
                    : String(format: "%.1f", weight)
            }
        }
        .sheet(isPresented: $showPlateCalc) {
            PlateCalculatorView(targetWeight: plateCalcWeight)
        }
        .sheet(isPresented: $showHistory) {
            if let exercise { ExerciseOverviewView(exercise: exercise) }
        }
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
                Text(exercise.name).font(.headline)
                if let cat = exercise.category {
                    Text(cat.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if exercise.notes != nil {
                Button { showExerciseNotes = true } label: {
                    Image(systemName: "note.text").foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                            isSelected: workoutStore.selectedEntryID == entry.persistentModelID,
                            onDelete: {
                                try? workoutStore.deleteSet(entry, context: context)
                                HapticManager.setDeleted()
                                if workoutStore.selectedEntryID == entry.persistentModelID {
                                    workoutStore.selectedEntryID = nil
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            workoutStore.selectedEntryID = entry.persistentModelID
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                try? workoutStore.deleteSet(entry, context: context)
                                HapticManager.setDeleted()
                                if workoutStore.selectedEntryID == entry.persistentModelID {
                                    workoutStore.selectedEntryID = nil
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

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
                Button { showExerciseNotes = true } label: {
                    Label("Exercise Notes", systemImage: "note.text")
                }
                Button { showHistory = true } label: {
                    Label("History & Stats", systemImage: "chart.bar")
                }
                Divider()
                Button { showOneRMCalc = true } label: {
                    Label("1RM Calculator", systemImage: "function")
                }
                Button { showSetCalc = true } label: {
                    Label("Set Calculator", systemImage: "percent")
                }
                Button {
                    // Capture weight at tap time — avoids subscribing TrainingView to inputState.weightText
                    plateCalcWeight = Double(inputState.weightText) ?? 0
                    showPlateCalc = true
                } label: {
                    Label("Plate Calculator", systemImage: "circle.grid.2x1.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Training Input Card

// Owns all text-field @State. Isolated so keystrokes don't re-render TrainingView.
private struct TrainingInputCard: View {
    let exercise: Exercise
    let sessionIndex: Int
    @Bindable var inputState: TrainingInputState
    var onPR: () -> Void

    @Environment(ActiveWorkoutStore.self) private var workoutStore
    @Environment(RestTimerStore.self) private var timerStore
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    private var session: ExerciseSession? {
        workoutStore.sessions.indices.contains(sessionIndex)
            ? workoutStore.sessions[sessionIndex]
            : nil
    }

    private var exerciseType: ExerciseType { exercise.exerciseType }
    private var isEditing: Bool { workoutStore.selectedEntryID != nil }

    var body: some View {
        VStack(spacing: 0) {
            inputSection
            actionButtons
            restTimerSection
        }
        .onAppear {
            guard inputState.weightText.isEmpty else { return }
            prefillFromRecentSet()
        }
        .onChange(of: workoutStore.selectedEntryID) { _, newID in
            if let newID, let entry = session?.sets.first(where: { $0.persistentModelID == newID }) {
                populateFields(from: entry)
            } else if newID == nil {
                resetInputFields()
                prefillFromRecentSet()
            }
        }
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
                        TextField("0", text: $inputState.weightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }
                    VStack(spacing: 4) {
                        Button {
                            adjustWeight(by: settingsStore.display(kg: exercise.weightIncrementKg ?? settingsStore.defaultWeightIncrementKg))
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        Button {
                            adjustWeight(by: -settingsStore.display(kg: exercise.weightIncrementKg ?? settingsStore.defaultWeightIncrementKg))
                        } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
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
                        TextField("0", text: $inputState.repsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                            .frame(maxWidth: 100)
                        ForEach([5, 8, 10, 12], id: \.self) { rep in
                            Button("\(rep)") { inputState.repsText = "\(rep)" }
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
                    TextField("0", text: $inputState.distanceText)
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
                        TextField("0", text: $inputState.durationMinText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $inputState.durationSecText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.monospacedDigit())
                    }
                }
            }

            if inputState.showCommentField || !inputState.commentText.isEmpty {
                HStack {
                    Image(systemName: "text.bubble").foregroundStyle(.secondary)
                    TextField("Set comment...", text: $inputState.commentText)
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

                Button { workoutStore.selectedEntryID = nil } label: { Text("Cancel") }
                    .buttonStyle(.bordered)
            }

            Button { inputState.showCommentField.toggle() } label: {
                Image(systemName: "text.bubble")
            }
            .buttonStyle(.bordered)
            .tint(inputState.commentText.isEmpty ? .secondary : .blue)

            Spacer()

            Button { saveSet() } label: {
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
        if case .running(_, _, let name) = timerStore.state, name == exercise.name {
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
        } else if case .paused(_, _, let name) = timerStore.state, name == exercise.name {
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

    // MARK: - Actions

    private func saveSet() {
        let weightKg = settingsStore.kg(from: Double(inputState.weightText) ?? 0)
        let reps = Int(inputState.repsText) ?? 0
        let distance = (Double(inputState.distanceText) ?? 0) * 1000
        let durationSec = (Int(inputState.durationMinText) ?? 0) * 60 + (Int(inputState.durationSecText) ?? 0)

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

            if !inputState.commentText.isEmpty {
                if entry.comment != nil {
                    entry.comment?.text = inputState.commentText
                } else {
                    let comment = SetComment(text: inputState.commentText)
                    comment.trainingEntry = entry
                    context.insert(comment)
                }
                try? context.save()
            } else if let existingComment = entry.comment, inputState.commentText.isEmpty {
                context.delete(existingComment)
                try? context.save()
            }

            if result.isRecord {
                onPR()
                HapticManager.personalRecord()
            } else {
                HapticManager.setSaved()
            }

            if settingsStore.restTimerAutoStart {
                let seconds = exercise.defaultRestTimeSeconds ?? settingsStore.restTimerSeconds
                timerStore.start(seconds: seconds, exerciseName: exercise.name)
            }

            if settingsStore.autoSelectNextSet {
                workoutStore.advanceToNextSet()
            }

            workoutStore.selectedEntryID = nil
            resetInputFields()
            prefillFromRecentSet()
        } catch {
            // keep fields populated for retry
        }
    }

    private func deleteSelectedSet() {
        guard let selectedID = workoutStore.selectedEntryID,
              let entry = session?.sets.first(where: { $0.persistentModelID == selectedID }) else { return }
        try? workoutStore.deleteSet(entry, context: context)
        HapticManager.setDeleted()
        workoutStore.selectedEntryID = nil
    }

    private func populateFields(from entry: TrainingEntry) {
        inputState.weightText = formatWeight(settingsStore.display(kg: entry.weightKg))
        inputState.repsText = entry.reps > 0 ? "\(entry.reps)" : ""
        inputState.distanceText = entry.distanceMetres > 0 ? String(format: "%.2f", entry.distanceMetres / 1000) : ""
        inputState.durationMinText = entry.durationSeconds > 0 ? "\(entry.durationSeconds / 60)" : ""
        inputState.durationSecText = entry.durationSeconds > 0 ? "\(entry.durationSeconds % 60)" : ""
        inputState.commentText = entry.comment?.text ?? ""
        inputState.showCommentField = !inputState.commentText.isEmpty
    }

    private func resetInputFields() {
        inputState.weightText = ""
        inputState.repsText = ""
        inputState.distanceText = ""
        inputState.durationMinText = ""
        inputState.durationSecText = ""
        inputState.commentText = ""
        inputState.showCommentField = false
    }

    private func prefillFromRecentSet() {
        // session.sets is appended in save order, so .last is always the most recently logged set.
        // Fallback to previous-day entries when no sets exist in the current session yet.
        let entry: TrainingEntry?
        if let last = session?.sets.last {
            entry = last
        } else {
            entry = exercise.trainingEntries
                .filter { !Calendar.current.isDate($0.date, inSameDayAs: workoutStore.date) }
                .sorted { $0.date > $1.date }
                .first
        }
        guard let entry else { return }
        if exerciseType.usesWeight {
            inputState.weightText = formatWeight(settingsStore.display(kg: entry.weightKg))
        }
        if exerciseType.usesReps {
            inputState.repsText = entry.reps > 0 ? "\(entry.reps)" : ""
        }
    }

    private func adjustWeight(by amount: Double) {
        let current = Double(inputState.weightText) ?? 0
        inputState.weightText = formatWeight(max(0, current + amount))
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
