import Foundation

enum Format {
    /// Whole-number kcal, e.g. "2,340".
    static func kcal(_ value: Decimal) -> String {
        value.doubleValue.formatted(.number.precision(.fractionLength(0)))
    }

    /// Grams of macro with at most one decimal, e.g. "32.5" or "40".
    static func macroGrams(_ value: Decimal) -> String {
        value.doubleValue.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Portion grams, e.g. "150 g".
    static func portionGrams(_ value: Decimal) -> String {
        "\(value.doubleValue.formatted(.number.precision(.fractionLength(0...1)))) g"
    }

    /// Weight in the user's unit with one decimal, e.g. "82.4 kg".
    static func weight(kg: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kg)
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit.displayName)"
    }

    /// Signed weekly rate, e.g. "+0.3 kg/week".
    static func weeklyRate(kgPerWeek: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kgPerWeek)
        let formatted = value.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)))
        return "\(formatted) \(unit.displayName)/week"
    }
}
