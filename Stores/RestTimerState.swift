//
//  RestTimerState.swift
//  FitNotes iOS
//
//  Rest timer state enum as defined in technical_architecture.md section 3
//  Value type — not persisted; timer state is purely ephemeral
//

import Foundation

enum RestTimerState: Equatable {
    case idle
    case running(endsAt: Date, totalSeconds: Int, exerciseName: String)
    case expired(exerciseName: String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        case .running, .expired: return true
        }
    }

    var remainingSeconds: Int {
        guard case .running(let endsAt, _, _) = self else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
    }

    var exerciseName: String? {
        switch self {
        case .idle: return nil
        case .running(_, _, let name): return name
        case .expired(let name): return name
        }
    }
}
