//
//  ImportVerificationView.swift
//  FitNotes iOS
//
//  Displays verification results after importing FitNotes backup
//  (migration_plan.md §6).
//

import SwiftUI
import SwiftData

struct ImportVerificationView: View {
    let report: ImportVerificationReport
    @Environment(\.dismiss) private var dismiss
    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status indicator
                    statusSection

                    // Statistics
                    statisticsSection

                    // Failures/warnings
                    if !report.failures.isEmpty || !report.warnings.isEmpty {
                        issuesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Import Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(!report.passed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !report.passed {
                        Button("Retry") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 16) {
            Image(systemName: report.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(report.passed ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(report.passed ? "Import Successful" : "Import Completed with Warnings")
                    .font(.title2.bold())
                Text(report.passed 
                    ? "All data verified successfully" 
                    : "\(report.failures.count) issue(s) found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Statistics")
                .font(.headline)

            VStack(spacing: 8) {
                StatRow(
                    label: "Training Sets",
                    source: report.sourceSets,
                    target: report.targetSets
                )
                StatRow(
                    label: "Workout Days",
                    source: report.sourceWorkoutDays,
                    target: report.targetWorkoutDays
                )
                StatRow(
                    label: "Exercises",
                    source: report.sourceExercises,
                    target: report.targetExercises
                )
                StatRow(
                    label: "Categories",
                    source: report.sourceCategories,
                    target: report.targetCategories
                )
                StatRow(
                    label: "Routines",
                    source: report.sourceRoutines,
                    target: report.targetRoutines
                )
                StatRow(
                    label: "Set Comments",
                    source: report.sourceComments,
                    target: report.targetComments
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Issues Section

    @ViewBuilder
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issues Detected")
                .font(.headline)
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                ForEach(Array(report.failures.enumerated()), id: \.offset) { item in
                    IssueRow(index: item.offset + 1, message: item.element, type: .error)
                }
                ForEach(Array(report.warnings.enumerated()), id: \.offset) { item in
                    IssueRow(index: report.failures.count + item.offset + 1, message: item.element, type: .warning)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let label: String
    let source: Int
    let target: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(source) → \(target)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(source == target ? .primary : secondaryColor)
                if source != target {
                    Text("\(delta > 0 ? "+" : "")\(delta)")
                        .font(.caption2)
                        .foregroundStyle(deltaColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var delta: Int { target - source }
    private var deltaColor: Color { delta == 0 ? .secondary : (delta < 0 ? .red : .orange) }
    private var secondaryColor: Color { delta == 0 ? .secondary : (delta < 0 ? .red : .orange) }
}

private struct IssueRow: View {
    let index: Int
    let message: String
    let type: IssueType

    enum IssueType {
        case error
        case warning
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            HStack(spacing: 8) {
                Image(systemName: type == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(type == .error ? .red : .orange)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Successful Import") {
    ImportVerificationView(report: {
        var r = ImportVerificationReport()
        r.sourceSets = 3191; r.targetSets = 3191
        r.sourceExercises = 125; r.targetExercises = 125
        r.sourceCategories = 8; r.targetCategories = 8
        r.sourceRoutines = 5; r.targetRoutines = 5
        r.sourceComments = 42; r.targetComments = 42
        r.sourceWorkoutDays = 180; r.targetWorkoutDays = 180
        return r
    }())
}

#Preview("Import with Warnings") {
    ImportVerificationView(report: {
        var r = ImportVerificationReport()
        r.sourceSets = 3191; r.targetSets = 3188
        r.sourceExercises = 125; r.targetExercises = 125
        r.sourceCategories = 8; r.targetCategories = 8
        r.sourceRoutines = 5; r.targetRoutines = 5
        r.sourceComments = 42; r.targetComments = 42
        r.sourceWorkoutDays = 180; r.targetWorkoutDays = 179
        r.failures = ["Sets: source=3191, iOS=3188 (delta: -3)", "Workout days: source=180, iOS=179"]
        r.warnings = ["Category 1 colour may appear different due to color space conversion"]
        return r
    }())
}