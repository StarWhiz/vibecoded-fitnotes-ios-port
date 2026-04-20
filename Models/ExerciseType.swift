//
//  ExerciseType.swift
//  FitNotes iOS
//
//  Exercise type enumeration as defined in technical_architecture.md
//

import Foundation

enum ExerciseType: Int, Codable, CaseIterable {
    case weightReps = 0   // Standard barbell / dumbbell / machine
    case cardio     = 1   // Distance + duration
    case timed      = 3   // Isometric / plank — duration only
    // Note: value 2 is unobserved in backup; reserved in app
    // Premium types (not in backup) handled by .unknown on import
    case unknown    = -1

    init(rawValue: Int) {
        switch rawValue {
        case 0: self = .weightReps
        case 1: self = .cardio
        case 3: self = .timed
        default: self = .unknown
        }
    }

    var usesWeight: Bool    { self == .weightReps }
    var usesDistance: Bool  { self == .cardio }
    var usesDuration: Bool  { self == .cardio || self == .timed }
    var usesReps: Bool      { self == .weightReps }
}