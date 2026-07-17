import Foundation
import SwiftData

/// A single weigh-in. Weight is always stored in kilograms; the display unit
/// is a settings concern.
@Model
final class WeightEntry {
    var date: Date = Date()
    var weightKg: Double = 0
    var note: String?
    /// UUID of the matching Apple Health sample, when synced, to avoid duplicates.
    var healthKitUUID: String?

    init(date: Date = Date(), weightKg: Double, note: String? = nil, healthKitUUID: String? = nil) {
        self.date = date
        self.weightKg = weightKg
        self.note = note
        self.healthKitUUID = healthKitUUID
    }
}

/// A single water intake event, stored in milliliters.
@Model
final class WaterEntry {
    var date: Date = Date()
    var dayKey: Date = Date()
    var amountML: Double = 0

    init(date: Date = Date(), dayKey: Date, amountML: Double) {
        self.date = date
        self.dayKey = dayKey
        self.amountML = amountML
    }
}

/// A supplement the user takes. Archiving hides it from the daily checklist
/// while keeping its completion history intact.
@Model
final class Supplement {
    var name: String = ""
    var dose: String?
    var timeOfDayLabel: String?
    var notes: String?
    var isActive: Bool = true
    var isArchived: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SupplementLog.supplement)
    var logs: [SupplementLog]? = []

    init(
        name: String,
        dose: String? = nil,
        timeOfDayLabel: String? = nil,
        notes: String? = nil,
        isActive: Bool = true,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.dose = dose
        self.timeOfDayLabel = timeOfDayLabel
        self.notes = notes
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

/// One "taken" checkmark for a supplement on a given day. The checklist for a
/// new day is simply the absence of logs for that dayKey — no reset job needed,
/// and history is preserved automatically.
@Model
final class SupplementLog {
    var dayKey: Date = Date()
    var completedAt: Date = Date()

    var supplement: Supplement?

    init(dayKey: Date, completedAt: Date = Date(), supplement: Supplement?) {
        self.dayKey = dayKey
        self.completedAt = completedAt
        self.supplement = supplement
    }
}
