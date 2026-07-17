import Foundation

/// One day's nutrition summary used by Progress charts, streaks, and insights.
struct DaySummary: Equatable {
    var dayKey: Date
    var calories: Decimal
    var protein: Decimal

    func calorieGoalReached(minimum: Decimal) -> Bool { calories >= minimum }
    func proteinGoalReached(minimum: Decimal) -> Bool { protein >= minimum }
    func bothGoalsReached(calorieMin: Decimal, proteinMin: Decimal) -> Bool {
        calorieGoalReached(minimum: calorieMin) && proteinGoalReached(minimum: proteinMin)
    }
}

enum DailyStats {
    /// Groups log entries into per-day summaries, sorted ascending by day.
    /// Days without entries are simply absent.
    static func summaries(entries: [LogEntry]) -> [DaySummary] {
        Dictionary(grouping: entries, by: \.dayKey)
            .map { day, dayEntries in
                let totals = NutritionCalculator.dayTotals(entries: dayEntries)
                return DaySummary(dayKey: day, calories: totals.calories, protein: totals.protein)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }

    /// Percentage (0...100) of the given days on which `predicate` holds.
    static func percentage(of days: [DaySummary], where predicate: (DaySummary) -> Bool) -> Double {
        guard !days.isEmpty else { return 0 }
        let hit = days.filter(predicate).count
        return Double(hit) / Double(days.count) * 100
    }

    static func averageCalories(_ days: [DaySummary]) -> Decimal {
        guard !days.isEmpty else { return 0 }
        return days.reduce(Decimal(0)) { $0 + $1.calories } / Decimal(days.count)
    }

    static func averageProtein(_ days: [DaySummary]) -> Decimal {
        guard !days.isEmpty else { return 0 }
        return days.reduce(Decimal(0)) { $0 + $1.protein } / Decimal(days.count)
    }
}

/// Streaks of consecutive calendar days on which both minimums were reached.
/// A missing day (no entries at all) breaks a streak.
enum StreakCalculator {
    static func streaks(
        days: [DaySummary],
        calorieMin: Decimal,
        proteinMin: Decimal,
        today: Date = DayKey.today(),
        calendar: Calendar = .current
    ) -> (current: Int, longest: Int) {
        let hitDays = Set(
            days
                .filter { $0.bothGoalsReached(calorieMin: calorieMin, proteinMin: proteinMin) }
                .map { calendar.startOfDay(for: $0.dayKey) }
        )
        guard !hitDays.isEmpty else { return (0, 0) }

        // Longest run of consecutive hit days anywhere in history.
        var longest = 0
        for day in hitDays {
            let previous = calendar.date(byAdding: .day, value: -1, to: day)!
            guard !hitDays.contains(previous) else { continue } // only start counting at run starts
            var length = 1
            var cursor = day
            while true {
                let next = calendar.date(byAdding: .day, value: 1, to: cursor)!
                guard hitDays.contains(next) else { break }
                length += 1
                cursor = next
            }
            longest = max(longest, length)
        }

        // Current streak counts back from today; an unfinished today doesn't
        // break it — the streak then counts back from yesterday.
        var current = 0
        var cursor = calendar.startOfDay(for: today)
        if !hitDays.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        while hitDays.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }

        return (current, longest)
    }
}
