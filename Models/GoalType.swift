//
//  GoalType.swift
//  FitNotes iOS
//
//  Goal type enumeration as defined in technical_architecture.md
//

import Foundation

enum GoalType: Int, Codable {
    case increase = 0
    case decrease = 1
    case specific = 2
}