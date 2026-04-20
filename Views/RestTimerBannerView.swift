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

        case .running(let endsAt, let totalSeconds, let exerciseName):
            HStack(spacing: 12) {
                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress(endsAt: endsAt, total: totalSeconds))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(timerStore.state.remainingSeconds)")
                        .font(.caption.monospacedDigit().bold())
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(exerciseName)
                        .font(.caption.bold())
                        .lineLimit(1)
                }

                Spacer()

                Button("+30s") {
                    timerStore.addTime(30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    timerStore.stop()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal)

        case .expired(let exerciseName):
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time's up!")
                        .font(.caption.bold())
                    Text(exerciseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Dismiss") {
                    timerStore.stop()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal)
        }
    }

    private func progress(endsAt: Date, total: Int) -> CGFloat {
        let remaining = max(0, endsAt.timeIntervalSinceNow)
        guard total > 0 else { return 0 }
        return CGFloat(remaining / Double(total))
    }
}
