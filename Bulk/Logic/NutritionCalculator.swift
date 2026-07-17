import Foundation

/// Calories and macros as one value bundle. Uses Decimal throughout so scaled
/// amounts (e.g. 150 g of 20 g/100 g protein = exactly 30 g) never pick up
/// binary floating-point drift.
struct NutritionValues: Equatable, Codable {
    var calories: Decimal
    var protein: Decimal
    var carbs: Decimal
    var fat: Decimal

    static let zero = NutritionValues(calories: 0, protein: 0, carbs: 0, fat: 0)

    static func + (lhs: NutritionValues, rhs: NutritionValues) -> NutritionValues {
        NutritionValues(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

enum NutritionCalculator {
    /// Scales per-100 g values to an arbitrary gram amount.
    static func scale(per100g: NutritionValues, grams: Decimal) -> NutritionValues {
        let factor = grams / 100
        return NutritionValues(
            calories: per100g.calories * factor,
            protein: per100g.protein * factor,
            carbs: per100g.carbs * factor,
            fat: per100g.fat * factor
        )
    }

    /// Sums the scaled totals of a day's log entries.
    static func dayTotals(entries: [LogEntry]) -> NutritionValues {
        entries.reduce(.zero) { $0 + $1.totals }
    }
}

extension Decimal {
    /// Rounds to the given number of fraction digits (plain rounding).
    func rounded(_ scale: Int = 0) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    var doubleValue: Double {
        (self as NSDecimalNumber).doubleValue
    }

    var intValue: Int {
        (self.rounded() as NSDecimalNumber).intValue
    }
}
