//
//  SetRowView.swift
//  FitNotes iOS
//
//  Displays a single logged set within the Training screen (1.1, 1.4, 1.13).
//  Shows weight x reps, PR indicator, comment icon, and completion checkbox.
//

import SwiftUI
import SwiftData

struct SetRowView: View {
    let entry: TrainingEntry
    let setNumber: Int
    var isSelected: Bool = false

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 10) {
            // Set number
            Text("#\(setNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            // Mark complete checkbox
            if settingsStore.markSetsComplete {
                Button {
                    entry.isComplete.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(entry.isComplete ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Main content
            mainContent

            Spacer()

            // PR indicator
            if entry.isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            // Comment indicator
            if entry.comment != nil {
                Image(systemName: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var mainContent: some View {
        let type = entry.exercise?.exerciseType ?? .weightReps

        switch type {
        case .weightReps:
            weightRepsContent
        case .cardio:
            cardioContent
        case .timed:
            timedContent
        case .unknown:
            weightRepsContent
        }
    }

    private var weightRepsContent: some View {
        HStack(spacing: 4) {
            Text(formatWeight(settingsStore.display(kg: entry.weightKg)))
                .font(.body.monospacedDigit().bold())
            Text(settingsStore.weightSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("x")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(entry.reps)")
                .font(.body.monospacedDigit().bold())

            // Volume
            let vol = settingsStore.display(kg: entry.volume)
            Text("(\(formatWeight(vol)) \(settingsStore.weightSymbol))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cardioContent: some View {
        HStack(spacing: 8) {
            if entry.distanceMetres > 0 {
                HStack(spacing: 2) {
                    Text(String(format: "%.2f", entry.distanceMetres / 1000))
                        .font(.body.monospacedDigit().bold())
                    Text("km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if entry.durationSeconds > 0 {
                HStack(spacing: 2) {
                    Text(formatDuration(entry.durationSeconds))
                        .font(.body.monospacedDigit().bold())
                }
            }
            if entry.distanceMetres > 0 && entry.durationSeconds > 0 {
                // Speed
                let speedKmh = (entry.distanceMetres / 1000) / (Double(entry.durationSeconds) / 3600)
                Text(String(format: "%.1f km/h", speedKmh))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timedContent: some View {
        Text(formatDuration(entry.durationSeconds))
            .font(.body.monospacedDigit().bold())
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return "\(s)s"
    }
}
