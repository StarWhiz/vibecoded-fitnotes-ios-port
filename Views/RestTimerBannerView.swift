//
//  RestTimerBannerView.swift
//  FitNotes iOS
//
//  Floating rest timer banner (product_roadmap.md 1.8).
//  Shown across all tabs when the timer is active. Compact display
//  with exercise name, countdown, and stop/extend controls.
//

import SwiftUI

struct RestTimerBannerView: View {
    @Environment(RestTimerStore.self) private var timerStore

    var body: some View {
        switch timerStore.state {
        case .idle:
            EmptyView()

        case .running(_, let totalSeconds, let exerciseName):
            bannerRow {
                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress(remaining: timerStore.remainingSeconds, total: totalSeconds))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(timerStore.remainingSeconds)")
                        .font(.caption.monospacedDigit().bold())
                }
                .frame(width: 36, height: 36)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(exerciseName)
                        .font(.caption.bold())
                        .lineLimit(1)
                }
            } controls: {
                Button("+30s") { timerStore.addTime(30) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                timerIconButton("pause.circle.fill", tint: .orange) { timerStore.pause() }
                timerIconButton("xmark.circle.fill", tint: .secondary) { timerStore.stop() }
            }

        case .paused(_, let totalSeconds, let exerciseName):
            bannerRow {
                // Static progress ring with pause indicator
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress(remaining: timerStore.remainingSeconds, total: totalSeconds))
                        .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(timerStore.remainingSeconds)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 36, height: 36)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(exerciseName)
                        .font(.caption.bold())
                        .lineLimit(1)
                }
            } controls: {
                timerIconButton("arrow.counterclockwise", tint: .secondary) { timerStore.restart() }
                timerIconButton("play.circle.fill", tint: .orange) { timerStore.resume() }
                timerIconButton("xmark.circle.fill", tint: .secondary) { timerStore.stop() }
            }

        case .expired(let exerciseName):
            bannerRow {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time's up!")
                        .font(.caption.bold())
                    Text(exerciseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } controls: {
                Button("Dismiss") { timerStore.stop() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func bannerRow<Icon: View, Label: View, Controls: View>(
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder label: () -> Label,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        HStack(spacing: 12) {
            icon()
            label()
            Spacer()
            controls()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal)
    }

    private func timerIconButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(tint)
        }
    }

    private func progress(remaining: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(remaining) / CGFloat(total)
    }
}
