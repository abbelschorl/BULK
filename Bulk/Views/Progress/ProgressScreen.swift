import Charts
import SwiftData
import SwiftUI

/// Progress tab: understandable stats, not a dashboard. Range-filtered
/// calorie/protein charts with goal lines, goal-hit percentages, streaks,
/// weight trend with 7-day moving average, and deterministic insights.
struct ProgressScreen: View {
    @Environment(AppSettings.self) private var settings

    @Query(sort: \LogEntry.loggedAt) private var allEntries: [LogEntry]
    @Query(sort: \WeightEntry.date) private var allWeights: [WeightEntry]

    enum Range: String, CaseIterable, Identifiable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        case all = "All"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            case .all: nil
            }
        }
    }

    @State private var range: Range = .week
    @State private var showWeighIn = false

    private var rangeStart: Date? {
        guard let days = range.days else { return nil }
        return DayKey.shifted(DayKey.today(), by: -(days - 1))
    }

    private var summaries: [DaySummary] {
        let all = DailyStats.summaries(entries: allEntries)
        guard let start = rangeStart else { return all }
        return all.filter { $0.dayKey >= start }
    }

    private var rangeWeights: [WeightEntry] {
        guard let start = rangeStart else { return allWeights }
        return allWeights.filter { $0.date >= start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    if summaries.isEmpty && allWeights.isEmpty {
                        emptyState
                    } else {
                        insightsCard
                        nutritionCharts
                        statsGrid
                        WeightTrendCard(
                            weights: rangeWeights,
                            allWeights: allWeights,
                            onAddWeight: { showWeighIn = true }
                        )
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
            }
            .bulkScreen()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWeighIn = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add weigh-in")
                }
            }
            .sheet(isPresented: $showWeighIn) {
                AddWeightSheet()
            }
        }
    }

    private var emptyState: some View {
        BulkCard {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundStyle(Theme.textTertiary)
                Text("No data yet")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Log foods and weigh-ins for a few days and your trends will appear here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Insights

    private var insightsCard: some View {
        let insights = InsightsEngine.insights(
            days: DailyStats.summaries(entries: allEntries),
            weights: allWeights.map { .init(date: $0.date, kg: $0.weightKg) },
            calorieMin: settings.calorieMinimumDecimal,
            proteinMin: settings.proteinMinimumDecimal,
            weightUnit: settings.weightUnit
        )
        return Group {
            if !insights.isEmpty {
                BulkCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(insights, id: \.self) { insight in
                            Label {
                                Text(insight)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "lightbulb")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Charts

    private var nutritionCharts: some View {
        VStack(spacing: 12) {
            chartCard(
                title: "Calories",
                unit: "kcal",
                minimum: Double(settings.calorieMinimum),
                points: summaries.map { ($0.dayKey, $0.calories.doubleValue, $0.calorieGoalReached(minimum: settings.calorieMinimumDecimal)) }
            )
            chartCard(
                title: "Protein",
                unit: "g",
                minimum: Double(settings.proteinMinimum),
                points: summaries.map { ($0.dayKey, $0.protein.doubleValue, $0.proteinGoalReached(minimum: settings.proteinMinimumDecimal)) }
            )
        }
    }

    private func chartCard(title: String, unit: String, minimum: Double, points: [(Date, Double, Bool)]) -> some View {
        BulkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("goal ≥ \(minimum.formatted(.number.precision(.fractionLength(0)))) \(unit)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                if points.isEmpty {
                    Text("No logged days in this range.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    Chart {
                        ForEach(points, id: \.0) { point in
                            BarMark(
                                x: .value("Day", point.0, unit: .day),
                                y: .value(title, point.1)
                            )
                            .foregroundStyle(point.2 ? Theme.goalReached : Theme.belowGoal.opacity(0.75))
                            .cornerRadius(3)
                        }
                        RuleMark(y: .value("Minimum", minimum))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(Theme.textSecondary)
                    }
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
                    .frame(height: 150)
                    .accessibilityLabel("\(title) per day chart with minimum goal line at \(Int(minimum)) \(unit)")
                }
            }
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        let calorieMin = settings.calorieMinimumDecimal
        let proteinMin = settings.proteinMinimumDecimal
        let caloriePct = DailyStats.percentage(of: summaries) { $0.calorieGoalReached(minimum: calorieMin) }
        let proteinPct = DailyStats.percentage(of: summaries) { $0.proteinGoalReached(minimum: proteinMin) }
        let streaks = StreakCalculator.streaks(
            days: DailyStats.summaries(entries: allEntries),
            calorieMin: calorieMin,
            proteinMin: proteinMin
        )

        return VStack(spacing: 12) {
            SectionHeader(title: "\(summaries.count) logged days", systemImage: "calendar")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                statTile("Calorie goal hit", value: "\(Int(caloriePct.rounded()))%", subtitle: "of logged days")
                statTile("Protein goal hit", value: "\(Int(proteinPct.rounded()))%", subtitle: "of logged days")
                statTile("Avg calories", value: Format.kcal(DailyStats.averageCalories(summaries)), subtitle: "kcal per day")
                statTile("Avg protein", value: Format.macroGrams(DailyStats.averageProtein(summaries)), subtitle: "g per day")
                statTile("Current streak", value: "\(streaks.current)", subtitle: streaks.current == 1 ? "day, both goals" : "days, both goals")
                statTile("Longest streak", value: "\(streaks.longest)", subtitle: streaks.longest == 1 ? "day, both goals" : "days, both goals")
            }
        }
    }

    private func statTile(_ title: String, value: String, subtitle: String) -> some View {
        BulkCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
    }
}
