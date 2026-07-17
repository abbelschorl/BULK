import Charts
import SwiftData
import SwiftUI

/// Weight chart: individual weigh-ins as points, 7-day moving average as a
/// smooth line, weekly rate, and a neutral comparison to the desired rate.
struct WeightTrendCard: View {
    @Environment(AppSettings.self) private var settings

    /// Weigh-ins inside the selected range (chart).
    var weights: [WeightEntry]
    /// Full history (trend math needs data beyond the visible range edge).
    var allWeights: [WeightEntry]
    var onAddWeight: () -> Void

    private var movingAverage: [WeightTrendCalculator.Point] {
        let all = WeightTrendCalculator.movingAverage7(entries: allWeights)
        guard let first = weights.first else { return [] }
        let start = Calendar.current.startOfDay(for: first.date)
        return all.filter { $0.date >= start }
    }

    private var weeklyRate: Double? {
        // Rate over the trailing 4 weeks (or what exists) for stability.
        let all = WeightTrendCalculator.movingAverage7(entries: allWeights)
        guard let last = all.last else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: last.date)!
        return WeightTrendCalculator.weeklyRateKg(movingAverage: all.filter { $0.date >= cutoff })
    }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Weight", systemImage: "scalemass")
            BulkCard {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if weights.isEmpty {
                        VStack(spacing: 8) {
                            Text("No weigh-ins in this range")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.textSecondary)
                            Button("Add weigh-in", action: onAddWeight)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.accentBlue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    } else {
                        chart
                        if let rate = weeklyRate {
                            trendSummary(rate: rate)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            if let latest = allWeights.last {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Format.weight(kg: latest.weightKg, unit: settings.weightUnit))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("latest · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Button(action: onAddWeight) {
                Label("Weigh in", systemImage: "plus")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityLabel("Add weigh-in")
        }
    }

    private var chart: some View {
        let unit = settings.weightUnit
        return Chart {
            ForEach(weights, id: \.persistentModelID) { entry in
                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", unit.fromKilograms(entry.weightKg))
                )
                .foregroundStyle(Theme.textSecondary.opacity(0.55))
                .symbolSize(26)
            }
            ForEach(movingAverage, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("7-day average", unit.fromKilograms(point.kg))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Theme.accentBlue)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .trailing) {
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.textTertiary).font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(Theme.textTertiary)
                    .font(.caption2)
            }
        }
        .frame(height: 170)
        .accessibilityLabel("Weight chart showing weigh-ins and a 7-day moving average line")
    }

    private func trendSummary(rate: Double) -> some View {
        let desired = settings.desiredWeeklyGainKg
        let assessment = WeightTrendCalculator.assess(weeklyRateKg: rate, desiredWeeklyGainKg: desired)
        let description: String = switch assessment {
        case .belowDesired: "below your desired rate"
        case .nearDesired: "near your desired rate"
        case .aboveDesired: "above your desired rate"
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text("Trending \(Format.weeklyRate(kgPerWeek: rate, unit: settings.weightUnit))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text("That's \(description) of \(Format.weeklyRate(kgPerWeek: desired, unit: settings.weightUnit)), based on the 7-day average over the last month.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Quick weigh-in entry, defaulting to now. Optionally writes to Apple Health
/// when sync is enabled in Settings.
struct AddWeightSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitService.self) private var healthKit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WeightEntry.date) private var allWeights: [WeightEntry]

    @State private var weightText = ""
    @State private var date = Date()
    @State private var note = ""
    @FocusState private var weightFocused: Bool

    private var parsedWeight: Double? {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0, value < 1000 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Weight", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($weightFocused)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .accessibilityLabel("Weight in \(settings.weightUnit.displayName)")
                        Text(settings.weightUnit.displayName)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Date", selection: $date, in: ...Date())
                    TextField("Note (optional)", text: $note)
                } footer: {
                    if settings.healthKitSyncEnabled {
                        Text("This weigh-in will also be saved to Apple Health.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Add Weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(parsedWeight == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let latest = allWeights.last {
                weightText = settings.weightUnit.fromKilograms(latest.weightKg)
                    .formatted(.number.precision(.fractionLength(1)).grouping(.never))
            }
            weightFocused = true
        }
    }

    private func save() {
        guard let value = parsedWeight else { return }
        let kg = settings.weightUnit.toKilograms(value)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = WeightEntry(date: date, weightKg: kg, note: trimmedNote.isEmpty ? nil : trimmedNote)
        context.insert(entry)
        try? context.save()

        if settings.healthKitSyncEnabled {
            Task {
                if let uuid = await healthKit.saveWeight(kg: kg, date: date) {
                    entry.healthKitUUID = uuid
                    try? context.save()
                }
            }
        }
        dismiss()
    }
}
