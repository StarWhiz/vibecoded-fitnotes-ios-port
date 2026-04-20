//
//  OneRMCalculator.swift
//  FitNotes iOS
//
//  1RM Calculator domain service as defined in product_roadmap.md section 1.9
//  Pure computation — no persistence. Given weight + reps, estimates one-rep maximum
//  and derives the full 2RM–15RM table using Epley and Brzycki formulas.
//

import Foundation

struct OneRMCalculator {

    // MARK: - Formula enum

    enum Formula: String, CaseIterable, Identifiable {
        case epley
        case brzycki

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .epley: return "Epley"
            case .brzycki: return "Brzycki"
            }
        }
    }

    // MARK: - Single 1RM estimate

    /// Estimates the 1RM from a given weight and rep count.
    ///
    /// - Parameters:
    ///   - weight: The weight lifted (in any unit — result will be in the same unit).
    ///   - reps: Number of reps performed. Must be >= 1.
    ///   - formula: Which estimation formula to use (default: Epley).
    /// - Returns: Estimated 1RM, or the weight itself if reps == 1.
    static func estimate1RM(weight: Double, reps: Int, formula: Formula = .epley) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }

        switch formula {
        case .epley:
            // Epley: w × (1 + r/30)
            return weight * (1.0 + Double(reps) / 30.0)
        case .brzycki:
            // Brzycki: w × 36 / (37 − r)
            let denominator = 37.0 - Double(reps)
            guard denominator > 0 else { return weight }
            return weight * 36.0 / denominator
        }
    }

    // MARK: - Rep Max table entry

    struct RepMax: Identifiable {
        let reps: Int
        let weight: Double
        let percentage: Double   // percentage of 1RM

        var id: Int { reps }
    }

    // MARK: - Full RM table (1RM through 15RM)

    /// Generates a table of estimated max weights for 1 through 15 reps.
    ///
    /// - Parameters:
    ///   - weight: The weight lifted.
    ///   - reps: Number of reps performed.
    ///   - formula: Which estimation formula to use.
    /// - Returns: Array of `RepMax` from 1RM to 15RM.
    static func repMaxTable(weight: Double, reps: Int, formula: Formula = .epley) -> [RepMax] {
        let oneRM = estimate1RM(weight: weight, reps: reps, formula: formula)
        guard oneRM > 0 else { return [] }

        return (1...15).map { targetReps in
            let targetWeight = estimateWeight(for: targetReps, from1RM: oneRM, formula: formula)
            let percentage = targetWeight / oneRM * 100.0
            return RepMax(reps: targetReps, weight: targetWeight, percentage: percentage)
        }
    }

    // MARK: - Reverse: from 1RM, estimate weight at N reps

    /// Given a 1RM, estimates the max weight achievable at a target rep count.
    ///
    /// - Parameters:
    ///   - targetReps: The number of reps to estimate for.
    ///   - oneRM: The known or estimated 1RM.
    ///   - formula: Which estimation formula to use.
    /// - Returns: Estimated weight at the target rep count.
    static func estimateWeight(for targetReps: Int, from1RM oneRM: Double, formula: Formula = .epley) -> Double {
        guard oneRM > 0, targetReps > 0 else { return 0 }
        if targetReps == 1 { return oneRM }

        switch formula {
        case .epley:
            // Inverse Epley: 1RM / (1 + r/30)
            return oneRM / (1.0 + Double(targetReps) / 30.0)
        case .brzycki:
            // Inverse Brzycki: 1RM × (37 − r) / 36
            return oneRM * (37.0 - Double(targetReps)) / 36.0
        }
    }
}
