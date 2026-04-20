//
//  WeightUnit.swift
//  FitNotes iOS
//
//  Weight unit enumeration as defined in technical_architecture.md
//

import Foundation

enum WeightUnit: Int, Codable {
    case kilograms = 0
    case pounds    = 2
    // Value 1 observed in exercise.weight_unit_id but semantics unclear — treat as kg
    case unknown   = 1

    var symbol: String { self == .pounds ? "lbs" : "kg" }
    var toKgFactor: Double { self == .pounds ? 1.0 / 2.20462 : 1.0 }
    var fromKgFactor: Double { self == .pounds ? 2.20462 : 1.0 }
}