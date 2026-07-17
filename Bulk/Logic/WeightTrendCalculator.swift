import Foundation

/// Pure weight-trend math: 7-day moving average and weekly rate of change.
/// Works on (date, kg) points so it is trivially unit-testable.
enum WeightTrendCalculator {
    struct Point: Equatable {
        var date: Date
        var kg: Double
    }

    /// For each day that has at least one weigh-in, averages that day's
    /// weigh-ins, then averages over a trailing 7-calendar-day window ending
    /// on that day. Missing days are simply absent from the window.
    static func movingAverage7(entries: [WeightEntry], calendar: Calendar = .current) -> [Point] {
        movingAverage7(points: entries.map { Point(date: $0.date, kg: $0.weightKg) }, calendar: calendar)
    }

    static func movingAverage7(points: [Point], calendar: Calendar = .current) -> [Point] {
        let byDay = Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
        let dailyAverages = byDay
            .map { day, dayPoints in
                Point(date: day, kg: dayPoints.map(\.kg).reduce(0, +) / Double(dayPoints.count))
            }
            .sorted { $0.date < $1.date }

        return dailyAverages.map { current in
            guard let windowStart = calendar.date(byAdding: .day, value: -6, to: current.date) else {
                return current
            }
            let window = dailyAverages.filter { $0.date >= windowStart && $0.date <= current.date }
            let avg = window.map(\.kg).reduce(0, +) / Double(window.count)
            return Point(date: current.date, kg: avg)
        }
    }

    /// Weekly rate of change in kg/week, derived from the first and last
    /// moving-average points. Returns nil when there is less than a day of
    /// trend data to compare.
    static func weeklyRateKg(movingAverage: [Point]) -> Double? {
        guard let first = movingAverage.first, let last = movingAverage.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86_400
        guard days >= 1 else { return nil }
        return (last.kg - first.kg) / days * 7
    }

    enum TrendAssessment: Equatable {
        case belowDesired
        case nearDesired
        case aboveDesired
    }

    /// Compares the observed weekly rate with the desired rate using a
    /// ±0.1 kg/week "near" band, so the wording can stay neutral.
    static func assess(weeklyRateKg: Double, desiredWeeklyGainKg: Double) -> TrendAssessment {
        let tolerance = 0.1
        if weeklyRateKg < desiredWeeklyGainKg - tolerance { return .belowDesired }
        if weeklyRateKg > desiredWeeklyGainKg + tolerance { return .aboveDesired }
        return .nearDesired
    }
}
