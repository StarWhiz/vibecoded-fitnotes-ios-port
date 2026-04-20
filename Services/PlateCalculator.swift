//
//  PlateCalculator.swift
//  FitNotes iOS
//
//  Plate Calculator domain service as defined in product_roadmap.md section 1.11
//  Given a target barbell weight, determines the plates needed per side.
//  Uses a greedy largest-first algorithm.
//

import Foundation

struct PlateCalculator {

    // MARK: - Result types

    /// A single plate selection: which plate and how many per side.
    struct PlateSelection: Identifiable {
        let plate: Plate
        let countPerSide: Int

        var id: Int { plate.legacyID }

        /// Total weight added by this plate selection (both sides).
        var totalWeight: Double { plate.weightKg * Double(countPerSide) * 2.0 }
    }

    /// Full result of a plate calculation.
    struct Result {
        let targetWeightKg: Double
        let barWeightKg: Double
        let plates: [PlateSelection]
        let achievedWeightKg: Double
        let remainderKg: Double

        /// Whether the exact target was achieved.
        var isExact: Bool { abs(remainderKg) < 0.001 }

        /// Total plate weight (both sides combined).
        var totalPlateWeight: Double { plates.reduce(0) { $0 + $1.totalWeight } }
    }

    // MARK: - Calculation

    /// Calculates the plates needed per side to reach a target weight.
    ///
    /// - Parameters:
    ///   - targetWeightKg: The desired total barbell weight in kg.
    ///   - barWeightKg: The bar weight in kg (default: 20 kg / ~45 lbs).
    ///   - availablePlates: The user's plate inventory. Only plates where `isAvailable == true`
    ///     are considered. Sorted largest-first internally.
    /// - Returns: A `Result` with the plate breakdown. If the target is less than or equal
    ///   to the bar weight, returns an empty plate list.
    static func calculate(
        targetWeightKg: Double,
        barWeightKg: Double,
        availablePlates: [Plate]
    ) -> Result {
        let weightPerSide = (targetWeightKg - barWeightKg) / 2.0

        guard weightPerSide > 0 else {
            return Result(
                targetWeightKg: targetWeightKg,
                barWeightKg: barWeightKg,
                plates: [],
                achievedWeightKg: barWeightKg,
                remainderKg: max(0, targetWeightKg - barWeightKg)
            )
        }

        // Filter to available plates, sorted heaviest first
        let sortedPlates = availablePlates
            .filter { $0.isAvailable && $0.weightKg > 0 }
            .sorted { $0.weightKg > $1.weightKg }

        var remaining = weightPerSide
        var selections: [PlateSelection] = []

        for plate in sortedPlates {
            guard remaining >= plate.weightKg else { continue }

            // Max plates per side is half the total count (plates go on both sides)
            let maxPerSide = plate.count / 2
            guard maxPerSide > 0 else { continue }

            let needed = Int(remaining / plate.weightKg)
            let used = min(needed, maxPerSide)

            if used > 0 {
                selections.append(PlateSelection(plate: plate, countPerSide: used))
                remaining -= plate.weightKg * Double(used)
            }
        }

        let achievedPerSide = weightPerSide - remaining
        let achievedTotal = barWeightKg + (achievedPerSide * 2.0)

        return Result(
            targetWeightKg: targetWeightKg,
            barWeightKg: barWeightKg,
            plates: selections,
            achievedWeightKg: achievedTotal,
            remainderKg: remaining * 2.0  // remainder is per-side, report total
        )
    }

    // MARK: - Convenience with display units

    /// Calculates plates using display-unit weights (lbs or kg), converting internally.
    ///
    /// - Parameters:
    ///   - targetWeight: Target weight in the user's display unit.
    ///   - barWeight: Bar weight in the user's display unit.
    ///   - availablePlates: The plate inventory from SwiftData.
    ///   - isImperial: Whether the user is working in lbs.
    /// - Returns: A `Result` with weights in kg (convert at display site).
    static func calculate(
        targetWeight: Double,
        barWeight: Double,
        availablePlates: [Plate],
        isImperial: Bool
    ) -> Result {
        let factor = isImperial ? 1.0 / 2.20462 : 1.0
        return calculate(
            targetWeightKg: targetWeight * factor,
            barWeightKg: barWeight * factor,
            availablePlates: availablePlates
        )
    }
}
