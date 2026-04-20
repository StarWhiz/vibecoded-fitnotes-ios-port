//
//  WorkoutCardView.swift
//  FitNotes iOS
//
//  Social-media-ready workout card rendered as an image (product_roadmap.md 3.10).
//  Uses ImageRenderer to produce a UIImage from a SwiftUI view,
//  then shares via UIActivityViewController.
//

import SwiftUI

// MARK: - Workout Card View (rendered to image)

struct WorkoutCardView: View {
    let sessions: [ExerciseSession]
    let date: Date
    let comment: String
    let workoutSession: WorkoutSession?
    let isImperial: Bool

    private var weightSymbol: String { isImperial ? "lbs" : "kg" }
    private func display(kg: Double) -> Double { isImperial ? kg * 2.20462 : kg }

    var body: some View {
        VStack(spacing: 0) {
            // Header gradient
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Exercise grid
            exerciseGrid
                .padding(.horizontal, 20)

            // Footer with totals
            footerSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .frame(width: 390)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.14),
                         Color(red: 0.12, green: 0.10, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKOUT")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)

            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if let session = workoutSession, let duration = session.duration {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(formatDuration(duration))
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.7))
            }

            if !comment.isEmpty {
                Text("\"\(comment)\"")
                    .font(.subheadline.italic())
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Exercise Grid

    private var exerciseGrid: some View {
        VStack(spacing: 2) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { _, session in
                exerciseRow(session)
            }
        }
    }

    private func exerciseRow(_ session: ExerciseSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Category color bar
            if let cat = session.exercise.category {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cat.color)
                    .frame(width: 4, height: 40)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if session.sets.contains(where: \.isPersonalRecord) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                }

                Text(setsSummary(session))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text("\(session.sets.count)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            // Total stats
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    statBadge(
                        value: "\(sessions.count)",
                        label: "exercises"
                    )
                    statBadge(
                        value: "\(totalSets)",
                        label: "sets"
                    )
                    if totalVolume > 0 {
                        statBadge(
                            value: formatWeight(display(kg: totalVolume)),
                            label: weightSymbol
                        )
                    }
                }
            }

            Spacer()

            // App branding
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                Text("FitNotes")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Helpers

    private var totalSets: Int {
        sessions.reduce(0) { $0 + $1.sets.count }
    }

    private var totalVolume: Double {
        sessions.flatMap(\.sets).reduce(0) { $0 + $1.volume }
    }

    private func setsSummary(_ session: ExerciseSession) -> String {
        let type = session.exercise.exerciseType
        guard !session.sets.isEmpty else { return "No sets" }

        if type.usesWeight {
            let best = session.sets.map { (display(kg: $0.weightKg), $0.reps) }
                .max(by: { $0.0 < $1.0 })
            if let best {
                return "\(formatWeight(best.0)) \(weightSymbol) x \(best.1) (best)"
            }
        } else if type == .cardio {
            let dist = session.sets.reduce(0.0) { $0 + $1.distanceMetres } / 1000
            let time = session.sets.reduce(0) { $0 + $1.durationSeconds }
            return "\(String(format: "%.1f", dist)) km, \(time / 60) min"
        } else if type == .timed {
            let time = session.sets.reduce(0) { $0 + $1.durationSeconds }
            return "\(time)s total"
        }
        return "\(session.sets.count) sets"
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}

// MARK: - Image Renderer

@MainActor
enum WorkoutCardRenderer {
    /// Renders the WorkoutCardView to a UIImage at 2x scale for retina quality.
    static func render(
        sessions: [ExerciseSession],
        date: Date,
        comment: String,
        workoutSession: WorkoutSession?,
        isImperial: Bool
    ) -> UIImage? {
        let card = WorkoutCardView(
            sessions: sessions,
            date: date,
            comment: comment,
            workoutSession: workoutSession,
            isImperial: isImperial
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        return renderer.uiImage
    }
}
