//
//  PlateCalculatorView.swift
//  FitNotes iOS
//
//  Plate calculator sheet (product_roadmap.md 1.11).
//  Given a target barbell weight, displays plates needed per side.
//

import SwiftUI
import SwiftData

struct PlateCalculatorView: View {
    var targetWeight: Double

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Plate.weightKg, order: .reverse)
    private var plates: [Plate]

    @Query private var barbells: [Barbell]

    @State private var targetText = ""
    @State private var barWeightText = ""

    private var result: PlateCalculator.Result {
        let target = Double(targetText) ?? 0
        let bar = Double(barWeightText) ?? 0
        return PlateCalculator.calculate(
            targetWeight: target,
            barWeight: bar,
            availablePlates: plates,
            isImperial: settingsStore.isImperial
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Input") {
                    HStack {
                        Text("Target (\(settingsStore.weightSymbol))")
                        Spacer()
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Bar Weight (\(settingsStore.weightSymbol))")
                        Spacer()
                        TextField("45", text: $barWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    if !barbells.isEmpty {
                        Picker("Saved Bars", selection: $barWeightText) {
                            ForEach(barbells) { barbell in
                                let displayW = settingsStore.display(kg: barbell.weightKg)
                                Text("\(barbell.name ?? "Bar") - \(formatWeight(displayW)) \(settingsStore.weightSymbol)")
                                    .tag(formatWeight(displayW))
                            }
                        }
                    }
                }

                if !result.plates.isEmpty {
                    Section("Plates Per Side") {
                        ForEach(result.plates) { selection in
                            HStack {
                                Circle()
                                    .fill(selection.plate.color)
                                    .frame(width: 20, height: 20)
                                Text("\(formatWeight(settingsStore.display(kg: selection.plate.weightKg))) \(settingsStore.weightSymbol)")
                                    .monospacedDigit()
                                Spacer()
                                Text("x \(selection.countPerSide)")
                                    .font(.headline.monospacedDigit())
                            }
                        }
                    }

                    Section("Summary") {
                        let achieved = settingsStore.display(kg: result.achievedWeightKg)
                        LabeledContent("Achieved Weight") {
                            Text("\(formatWeight(achieved)) \(settingsStore.weightSymbol)")
                                .monospacedDigit()
                        }
                        if !result.isExact {
                            let remainder = settingsStore.display(kg: result.remainderKg)
                            LabeledContent("Remaining") {
                                Text("\(formatWeight(remainder)) \(settingsStore.weightSymbol)")
                                    .foregroundStyle(.orange)
                                    .monospacedDigit()
                            }
                        } else {
                            LabeledContent("Status") {
                                Label("Exact", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } else if (Double(targetText) ?? 0) > 0 {
                    Section {
                        ContentUnavailableView(
                            "No Plates Needed",
                            systemImage: "circle.slash",
                            description: Text("Target weight is at or below bar weight.")
                        )
                    }
                }

                Section("Available Plates") {
                    ForEach(plates) { plate in
                        HStack {
                            Circle()
                                .fill(plate.color)
                                .frame(width: 16, height: 16)
                            Text("\(formatWeight(settingsStore.display(kg: plate.weightKg))) \(settingsStore.weightSymbol)")
                            Spacer()
                            Text("x \(plate.count)")
                                .foregroundStyle(.secondary)
                            Toggle("", isOn: Binding(
                                get: { plate.isAvailable },
                                set: { plate.isAvailable = $0 }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if targetWeight > 0 {
                    targetText = formatWeight(targetWeight)
                }
                let defaultBar = settingsStore.isImperial ? 45.0 : 20.0
                if let savedBar = barbells.first {
                    barWeightText = formatWeight(settingsStore.display(kg: savedBar.weightKg))
                } else {
                    barWeightText = formatWeight(defaultBar)
                }
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
