//
//  BodyTrackerView.swift
//  FitNotes iOS
//
//  Body tracker (product_roadmap.md 1.23).
//  Log and view body weight, body fat, and custom measurements.
//  Shows last value, delta, time since last entry. Graph of progress.
//

import SwiftUI
import SwiftData

struct BodyTrackerView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var bodyWeightEntries: [BodyWeightEntry]

    @Query(sort: \Measurement.sortOrder)
    private var measurements: [Measurement]

    @State private var showLogWeight = false
    @State private var showLogMeasurement = false
    @State private var selectedMeasurement: Measurement?

    var body: some View {
        List {
            // Body Weight Section
            Section("Body Weight") {
                if let latest = bodyWeightEntries.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatWeight(latest.displayWeight(isImperial: settingsStore.isImperial)))
                                .font(.title.bold().monospacedDigit())
                            + Text(" \(settingsStore.weightSymbol)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if latest.bodyFatPercent > 0 {
                                Text("\(String(format: "%.1f", latest.bodyFatPercent))% body fat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(latest.date, format: .dateTime.month().day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Delta from previous
                        if bodyWeightEntries.count >= 2 {
                            let prev = bodyWeightEntries[1]
                            let delta = latest.displayWeight(isImperial: settingsStore.isImperial) - prev.displayWeight(isImperial: settingsStore.isImperial)
                            VStack(alignment: .trailing) {
                                HStack(spacing: 2) {
                                    Image(systemName: delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "arrow.right")
                                    Text("\(String(format: "%+.1f", delta)) \(settingsStore.weightSymbol)")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(delta > 0 ? .red : delta < 0 ? .green : .secondary)
                            }
                        }
                    }
                }

                Button {
                    showLogWeight = true
                } label: {
                    Label("Log Body Weight", systemImage: "plus.circle.fill")
                }

                // Recent history
                if !bodyWeightEntries.isEmpty {
                    NavigationLink {
                        BodyWeightHistoryView()
                    } label: {
                        Label("View History (\(bodyWeightEntries.count) entries)", systemImage: "clock")
                    }
                }
            }

            // Measurements Section
            Section("Measurements") {
                let enabled = measurements.filter(\.isEnabled)
                if enabled.isEmpty {
                    ContentUnavailableView {
                        Label("No Measurements", systemImage: "ruler")
                    } description: {
                        Text("Enable measurements in Settings to track them here.")
                    }
                } else {
                    ForEach(enabled) { measurement in
                        Button {
                            selectedMeasurement = measurement
                            showLogMeasurement = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(measurement.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    if let latest = measurement.records.sorted(by: { $0.recordedAt > $1.recordedAt }).first {
                                        Text("\(String(format: "%.1f", latest.value)) \(measurement.unit?.shortName ?? "")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("No entries")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Body Tracker")
        .sheet(isPresented: $showLogWeight) {
            LogBodyWeightSheet(lastEntry: bodyWeightEntries.first)
        }
        .sheet(isPresented: $showLogMeasurement) {
            if let measurement = selectedMeasurement {
                LogMeasurementSheet(measurement: measurement)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Log Body Weight Sheet

struct LogBodyWeightSheet: View {
    var lastEntry: BodyWeightEntry?

    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var commentText = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField("Weight (\(settingsStore.weightSymbol))", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                        Text(settingsStore.weightSymbol)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("Body Fat %", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Comment (optional)", text: $commentText)
                }
            }
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .bold()
                    .disabled(Double(weightText) == nil)
                }
            }
            .onAppear {
                if let last = lastEntry {
                    weightText = formatWeight(last.displayWeight(isImperial: settingsStore.isImperial))
                }
            }
        }
    }

    private func save() {
        guard let displayW = Double(weightText) else { return }
        let entry = BodyWeightEntry(
            date: date,
            weightKg: settingsStore.kg(from: displayW),
            bodyFatPercent: Double(bodyFatText) ?? 0,
            comment: commentText.isEmpty ? nil : commentText
        )
        context.insert(entry)
        try? context.save()
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Body Weight History

struct BodyWeightHistoryView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.modelContext) private var context

    @Query(sort: \BodyWeightEntry.date, order: .reverse)
    private var entries: [BodyWeightEntry]

    var body: some View {
        List {
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatWeight(entry.displayWeight(isImperial: settingsStore.isImperial)))
                            .font(.body.bold().monospacedDigit())
                        + Text(" \(settingsStore.weightSymbol)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if entry.bodyFatPercent > 0 {
                            Text("\(String(format: "%.1f", entry.bodyFatPercent))% bf")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let comment = entry.comment {
                            Text(comment)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(entries[index])
                }
                try? context.save()
            }
        }
        .listStyle(.plain)
        .navigationTitle("Body Weight History")
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}

// MARK: - Log Measurement Sheet

struct LogMeasurementSheet: View {
    let measurement: Measurement

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var valueText = ""
    @State private var commentText = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section(measurement.name) {
                    HStack {
                        TextField("Value", text: $valueText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                        Text(measurement.unit?.shortName ?? "")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Comment (optional)", text: $commentText)
                }

                // Recent entries
                let recentRecords = measurement.records.sorted { $0.recordedAt > $1.recordedAt }.prefix(5)
                if !recentRecords.isEmpty {
                    Section("Recent") {
                        ForEach(Array(recentRecords), id: \.persistentModelID) { record in
                            HStack {
                                Text(String(format: "%.1f", record.value))
                                    .monospacedDigit()
                                Text(measurement.unit?.shortName ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(record.recordedAt, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log \(measurement.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .bold()
                    .disabled(Double(valueText) == nil)
                }
            }
            .onAppear {
                // Pre-fill from last entry
                if let last = measurement.records.sorted(by: { $0.recordedAt > $1.recordedAt }).first {
                    valueText = String(format: "%.1f", last.value)
                }
            }
        }
    }

    private func save() {
        guard let value = Double(valueText) else { return }
        let record = MeasurementRecord(
            recordedAt: date,
            value: value,
            comment: commentText.isEmpty ? nil : commentText
        )
        record.measurement = measurement
        context.insert(record)
        try? context.save()
    }
}
