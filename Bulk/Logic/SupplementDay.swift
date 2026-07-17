import Foundation
import SwiftData

/// Pure logic for the daily supplement checklist: which active supplements are
/// done on a given day, and the completion fraction. History lives in
/// SupplementLog rows, so "resetting" for a new day is just querying a new
/// dayKey — past days keep their logs untouched.
enum SupplementDay {
    static func completedSupplementIDs(logs: [SupplementLog], dayKey: Date, calendar: Calendar = .current) -> Set<PersistentIdentifier> {
        let day = calendar.startOfDay(for: dayKey)
        return Set(
            logs
                .filter { calendar.startOfDay(for: $0.dayKey) == day }
                .compactMap { $0.supplement?.persistentModelID }
        )
    }

    static func completionFraction(activeCount: Int, completedCount: Int) -> Double {
        guard activeCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(activeCount), 0), 1)
    }
}
