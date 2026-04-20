//
//  SetCalculatorView.swift
//  FitNotes iOS
//
//  Percentage-based set calculator (product_roadmap.md 1.10).
//  Compute target weights as percentages of a base max (e.g., Wendler 5/3/1).
//  "Add To Workout" inserts the computed weight into the current set.
//

import SwiftUI

struct SetCalculatorView: View {
    var exercise: Exercise?
    var onSelectWeight: (Double) -> Void

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var baseWeightText = ""
    @State private var selectedPercentage: Double = 100
    @State private var customPercentageText = ""
    @State private var roundTo: Double = 5.0

    private let presetPercentages: [Double] = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]
    private let roundingOptions: [Double] = [2.5, 5.0, 10.0]

    private var baseWeight: Double { Double(baseWeightText) ?? 0 }

    private var computedWeight: Double {
        let pct = customPercentageText.isEmpty ? selectedPercentage : (Double(customPercentageText) ?? selectedPercentage)
        let raw = baseWeight * pct / 100.0
        guard roundTo > 0 else { return raw }
        return (raw / roundTo).rounded() * roundTo
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Base Weight") {
                    HStack {
                        Text("Max (\(settingsStore.weightSymbol))")
                        Spacer()
                        TextField("0", text: $baseWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    if let exercise {
                        Button("Select Max from Records") {
                            prefillMax(exercise)
                        }
                    }
                }

                Section("Percentage") {
                    Picker("Preset", selection: $selectedPercentage) {
                        ForEach(presetPercentages, id: \.self) { pct in
                            Text("\(Int(pct))%").tag(pct)
                        }
                    }

                    HStack {
                        Text("Custom %")
                        Spacer()
                        TextField("", text: $customPercentageText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Rounding") {
                    Picker("Round To Closest", selection: $roundTo) {
                        Text("None").tag(0.0)
                        ForEach(roundingOptions, id: \.self) { opt in
                            Text("\(formatWeight(opt)) \(settingsStore.weightSymbol)").tag(opt)
                        }
                    }
                }

                if baseWeight > 0 {
                    Section("Result") {
                        HStack {
                            Text("Target Weight")
                                .font(.headline)
                            Spacer()
                            Text("\(formatWeight(computedWeight)) \(settingsStore.weightSymbol)")
                                .font(.title2.bold().monospacedDigit())
                        }

                        Button {
                            onSelectWeight(computedWeight)
                            dismiss()
                        } label: {
                            Label("Add To Workout", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Section("Quick Reference") {
                        ForEach(presetPercentages, id: \.self) { pct in
                            let raw = baseWeight * pct / 100.0
                            let rounded = roundTo > 0 ? ((raw / roundTo).rounded() * roundTo) : raw
                            HStack {
                                Text("\(Int(pct))%")
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Text("\(formatWeight(rounded)) \(settingsStore.weightSymbol)")
                                    .monospacedDigit()
                            }
                            .foregroundStyle(pct == selectedPercentage ? .blue : .primary)
                        }
                    }
                }
            }
            .navigationTitle("Set Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func prefillMax(_ exercise: Exercise) {
        let entries = exercise.trainingEntries.filter { $0.reps > 0 && $0.weightKg > 0 }
        guard let best = entries.max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }) else { return }
        let estimated1RM = OneRMCalculator.estimate1RM(
            weight: settingsStore.display(kg: best.weightKg),
            reps: best.reps
        )
        baseWeightText = formatWeight(estimated1RM)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
