import Foundation

/// All diary grouping uses local-timezone calendar days. Entries store a full
/// timestamp plus this normalized "start of day" key.
enum DayKey {
    static func of(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func today(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date())
    }

    static func shifted(_ dayKey: Date, by days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: dayKey) ?? dayKey
    }

    static func isToday(_ dayKey: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(dayKey)
    }

    /// "Today", "Yesterday", "Tomorrow", or a medium formatted date.
    static func displayName(for dayKey: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(dayKey) { return "Today" }
        if calendar.isDateInYesterday(dayKey) { return "Yesterday" }
        if calendar.isDateInTomorrow(dayKey) { return "Tomorrow" }
        return dayKey.formatted(date: .abbreviated, time: .omitted)
    }
}
