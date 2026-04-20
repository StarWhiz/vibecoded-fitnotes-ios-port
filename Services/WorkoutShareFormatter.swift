//
//  WorkoutShareFormatter.swift
//  FitNotes iOS
//
//  Formats workout data as plain text for sharing (product_roadmap.md 1.26, 2§ gap).
//  Pure function — queries no DB, takes pre-loaded data, produces a string.
//

import Foundation

struct WorkoutShareFormatter {

    /// Renders a shareable plain-text workout summary.
    ///
    /// - Parameters:
    ///   - sessions: Today's exercise sessions with their logged sets.
    ///   - date: The workout date.
    ///   - comment: Optional day-level comment.
    ///   - workoutSession: Optional timing information.
    ///   - isImperial: Whether to display in lbs.
    /// - Returns: Formatted multi-line string suitable for sharing.
    static func format(
        sessions: [ExerciseSession],
        date: Date,
        comment: String,
        workoutSession: WorkoutSession?,
        isImperial: Bool
    ) -> String {
        var lines: [String] = []

        // Header
        let dateStr = date.formatted(.dateTime.weekday(.wide).month().day().year())
        lines.append("Workout - \(dateStr)")
        lines.append(String(repeating: "-", count: 40))

        // Timing
        if let session = workoutSession, let duration = session.duration {
            let h = Int(duration) / 3600
            let m = (Int(duration) % 3600) / 60
            if h > 0 {
                lines.append("Duration: \(h)h \(m)m")
            } else {
                lines.append("Duration: \(m)m")
            }
        }

        // Comment
        if !comment.isEmpty {
            lines.append("Note: \(comment)")
        }

        if workoutSession != nil || !comment.isEmpty {
            lines.append("")
        }

        let weightSymbol = isImperial ? "lbs" : "kg"
        let toDisplay: (Double) -> Double = { kg in isImperial ? kg * 2.20462 : kg }

        // Exercises
        for session in sessions {
            let exercise = session.exercise
            lines.append(exercise.name)

            for (index, entry) in session.sets.enumerated() {
                let setNum = index + 1
                let type = exercise.exerciseType

                var setLine = "  \(setNum). "

                switch type {
                case .weightReps:
                    let w = toDisplay(entry.weightKg)
                    setLine += "\(formatWeight(w)) \(weightSymbol) x \(entry.reps)"
                    if entry.isPersonalRecord {
                        setLine += " PR!"
                    }
                case .cardio:
                    if entry.distanceMetres > 0 {
                        setLine += String(format: "%.2f km", entry.distanceMetres / 1000)
                    }
                    if entry.durationSeconds > 0 {
                        if entry.distanceMetres > 0 { setLine += ", " }
                        setLine += formatDuration(entry.durationSeconds)
                    }
                case .timed:
                    setLine += formatDuration(entry.durationSeconds)
                case .unknown:
                    setLine += "--"
                }

                // Set comment
                if let comment = entry.comment?.text, !comment.isEmpty {
                    setLine += " (\(comment))"
                }

                lines.append(setLine)
            }

            // Exercise totals for weight exercises
            if exercise.exerciseType.usesWeight && !session.sets.isEmpty {
                let totalVol = toDisplay(session.sets.reduce(0) { $0 + $1.volume })
                let totalReps = session.sets.reduce(0) { $0 + $1.reps }
                lines.append("  Total: \(formatWeight(totalVol)) \(weightSymbol), \(totalReps) reps")
            }

            lines.append("")
        }

        // Summary
        let totalSets = sessions.reduce(0) { $0 + $1.sets.count }
        let totalVolume = toDisplay(sessions.flatMap(\.sets).reduce(0) { $0 + $1.volume })

        lines.append(String(repeating: "-", count: 40))
        lines.append("\(sessions.count) exercises, \(totalSets) sets")
        if totalVolume > 0 {
            lines.append("Total volume: \(formatWeight(totalVolume)) \(weightSymbol)")
        }

        lines.append("")
        lines.append("Logged with FitNotes")

        return lines.joined(separator: "\n")
    }

    private static func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
    }
}
