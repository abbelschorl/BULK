import Foundation

/// Produces short, plain-language, fully deterministic insights from local
/// data. No AI, no network — just arithmetic and fixed sentence templates.
enum InsightsEngine {
    static func insights(
        days: [DaySummary],
        weights: [WeightTrendCalculator.Point],
        calorieMin: Decimal,
        proteinMin: Decimal,
        weightUnit: WeightUnit,
        today: Date = DayKey.today(),
        calendar: Calendar = .current
    ) -> [String] {
        var results: [String] = []

        // Weight: compare today's 7-day moving average with the one from 7 days ago.
        let ma = WeightTrendCalculator.movingAverage7(points: weights, calendar: calendar)
        if let last = ma.last, ma.count >= 2 {
            let weekAgoCutoff = calendar.date(byAdding: .day, value: -7, to: last.date)!
            if let reference = ma.last(where: { $0.date <= weekAgoCutoff }) {
                let deltaKg = last.kg - reference.kg
                let delta = weightUnit.fromKilograms(deltaKg)
                let magnitude = String(format: "%.1f", abs(delta))
                if abs(delta) < 0.05 {
                    results.append("Your 7-day average weight has been stable this week.")
                } else if delta > 0 {
                    results.append("Your 7-day average weight is up \(magnitude) \(weightUnit.displayName) this week.")
                } else {
                    results.append("Your 7-day average weight is down \(magnitude) \(weightUnit.displayName) this week.")
                }
            }
        }

        // Nutrition: goals hit in the last 7 finished-or-current days.
        let lastWeekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let lastWeek = days.filter { $0.dayKey >= lastWeekStart && $0.dayKey <= today }
        if !lastWeek.isEmpty {
            let bothHit = lastWeek.filter { $0.bothGoalsReached(calorieMin: calorieMin, proteinMin: proteinMin) }.count
            results.append("You reached both nutrition goals on \(bothHit) of the last \(lastWeek.count) days.")
        }

        // Run of consecutive most-recent logged days below the calorie minimum
        // (ignoring today, which is usually still in progress).
        let finishedDays = days.filter { $0.dayKey < today }.sorted { $0.dayKey > $1.dayKey }
        var belowRun = 0
        for day in finishedDays {
            if day.calories < calorieMin { belowRun += 1 } else { break }
        }
        if belowRun >= 2 {
            results.append("Your calorie intake has been below goal for \(belowRun) days.")
        }

        return results
    }
}
