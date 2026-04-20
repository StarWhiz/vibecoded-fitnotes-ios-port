//
//  OneRMCalculatorView.swift
//  FitNotes iOS
//
//  1RM Calculator sheet (product_roadmap.md 1.9).
//  Given weight + reps, estimates 1RM and shows the 2RM-15RM table.
//  Pre-fills from the user's actual personal record if available.
//

import SwiftUI

struct OneRMCalculatorView: View {
    var exercise: Exercise?

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var formula: OneRMCalculator.Formula = .epley

    private var weight: Double { Double(weightText) ?? 0 }
    private var reps: Int { Int(repsText) ?? 0 }
    private var estimated1RM: Double {
        OneRMCalculator.estimate1RM(weight: weight, reps: reps, formula: formula)
    }
    private var repMaxTable: [OneRMCalculator.RepMax] {
        OneRMCalculator.repMaxTable(weight: weight, reps: reps, formula: formula)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Input") {
                    HStack {
                        Text("Weight (\(settingsStore.weightSymbol))")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    Picker("Formula", selection: $formula) {
                        ForEach(OneRMCalculator.Formula.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }

                    if let exercise {
                        Button("Select from Records") {
                            prefillFromRecords(exercise)
                        }
                    }
                }

                if estimated1RM > 0 {
                    Section("Estimated 1RM") {
                        HStack {
                            Text("1 Rep Max")
                                .font(.headline)
                            Spacer()
                            Text("\(formatWeight(estimated1RM)) \(settingsStore.weightSymbol)")
                                .font(.title2.bold().monospacedDigit())
                        }
                    }

                    Section("Rep Max Table") {
                        ForEach(repMaxTable) { rm in
                            HStack {
                                Text("\(rm.reps) RM")
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Text("\(formatWeight(rm.weight)) \(settingsStore.weightSymbol)")
                                    .monospacedDigit()
                                Spacer()
                                Text("\(String(format: "%.0f", rm.percentage))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .navigationTitle("1RM Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func prefillFromRecords(_ exercise: Exercise) {
        // Find the entry with the highest estimated 1RM
        let entries = exercise.trainingEntries.filter { $0.reps > 0 && $0.weightKg > 0 }
        guard let best = entries.max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }) else { return }
        weightText = formatWeight(settingsStore.display(kg: best.weightKg))
        repsText = "\(best.reps)"
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
