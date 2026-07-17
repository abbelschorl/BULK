import Foundation

/// State of a minimum-style goal (calories or protein). There is deliberately
/// no upper warning range: below the minimum reads red/orange, at or above
/// reads green, nothing else.
enum GoalState: Equatable {
    case below(remaining: Decimal)
    case reached

    static func evaluate(consumed: Decimal, minimum: Decimal) -> GoalState {
        if consumed >= minimum {
            return .reached
        }
        return .below(remaining: minimum - consumed)
    }

    var isReached: Bool {
        if case .reached = self { return true }
        return false
    }

    var remaining: Decimal {
        if case .below(let remaining) = self { return remaining }
        return 0
    }

    /// Progress fraction toward the minimum, clamped to 0...1 for display.
    static func progressFraction(consumed: Decimal, minimum: Decimal) -> Double {
        guard minimum > 0 else { return consumed > 0 ? 1 : 0 }
        let fraction = (consumed / minimum).doubleValue
        return min(max(fraction, 0), 1)
    }
}
