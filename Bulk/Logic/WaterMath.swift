import Foundation

enum WaterMath {
    /// Total milliliters for one day's entries.
    static func totalML(entries: [WaterEntry]) -> Double {
        entries.reduce(0) { $0 + $1.amountML }
    }

    /// Progress fraction toward the daily goal, clamped to 0...1.
    static func progressFraction(totalML: Double, goalML: Double) -> Double {
        guard goalML > 0 else { return totalML > 0 ? 1 : 0 }
        return min(max(totalML / goalML, 0), 1)
    }

    /// Display string like "1,250 ml" or "42 fl oz" in the user's unit.
    static func displayString(ml: Double, unit: WaterUnit) -> String {
        let value = unit.fromMilliliters(ml)
        let formatted = value.formatted(.number.precision(.fractionLength(0)))
        return "\(formatted) \(unit.displayName)"
    }
}
