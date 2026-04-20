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
    case paused(remainingSeconds: Int, totalSeconds: Int, exerciseName: String)
    case expired(exerciseName: String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        case .running, .paused, .expired: return true
        }
    }

    var exerciseName: String? {
        switch self {
        case .idle: return nil
        case .running(_, _, let name): return name
        case .paused(_, _, let name): return name
        case .expired(let name): return name
        }
    }

    var totalSeconds: Int? {
        switch self {
        case .running(_, let total, _): return total
        case .paused(_, let total, _): return total
        default: return nil
        }
    }
}
