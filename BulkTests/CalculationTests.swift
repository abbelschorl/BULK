import Foundation
import Testing
@testable import Bulk

@Suite("Nutrition scaling")
struct NutritionScalingTests {
    @Test("150 g of a 20 g/100 g protein food is exactly 30 g protein")
    func scalesProteinExactly() {
        let per100 = NutritionValues(calories: 165, protein: 20, carbs: 0, fat: 3.6)
        let totals = NutritionCalculator.scale(per100g: per100, grams: 150)
        #expect(totals.protein == 30)
        #expect(totals.calories == Decimal(string: "247.5"))
        #expect(totals.fat == Decimal(string: "5.4"))
    }

    @Test("Zero grams gives zero everything")
    func zeroGrams() {
        let per100 = NutritionValues(calories: 380, protein: 13, carbs: 60, fat: 7)
        #expect(NutritionCalculator.scale(per100g: per100, grams: 0) == .zero)
    }

    @Test("Decimal math avoids binary floating point drift")
    func decimalPrecision() {
        // 0.1 + 0.2 style pitfall: 110 g of 0.3/100g must be exactly 0.33.
        let per100 = NutritionValues(calories: 0, protein: Decimal(string: "0.3")!, carbs: 0, fat: 0)
        let totals = NutritionCalculator.scale(per100g: per100, grams: 110)
        #expect(totals.protein == Decimal(string: "0.33"))
    }

    @Test("Day totals sum entries")
    func dayTotals() {
        let a = LogEntry(
            dayKey: Date(), mealType: .breakfast, grams: 100,
            foodName: "Oats", per100g: NutritionValues(calories: 380, protein: 13, carbs: 60, fat: 7),
            sourceLabel: "My Food"
        )
        let b = LogEntry(
            dayKey: Date(), mealType: .lunch, grams: 200,
            foodName: "Chicken", per100g: NutritionValues(calories: 165, protein: 31, carbs: 0, fat: 3.6),
            sourceLabel: "My Food"
        )
        let totals = NutritionCalculator.dayTotals(entries: [a, b])
        #expect(totals.calories == 380 + 330)
        #expect(totals.protein == 13 + 62)
    }
}

@Suite("Goal state")
struct GoalStateTests {
    @Test("Below minimum reports remaining")
    func belowMinimum() {
        let state = GoalState.evaluate(consumed: 2400, minimum: 3000)
        #expect(state == .below(remaining: 600))
        #expect(!state.isReached)
        #expect(state.remaining == 600)
    }

    @Test("Exactly at minimum counts as reached")
    func atMinimum() {
        #expect(GoalState.evaluate(consumed: 3000, minimum: 3000).isReached)
    }

    @Test("Above minimum stays reached — no upper warning range")
    func aboveMinimum() {
        let state = GoalState.evaluate(consumed: 5200, minimum: 3000)
        #expect(state == .reached)
        #expect(state.remaining == 0)
    }

    @Test("Progress fraction clamps to 0...1")
    func progressFraction() {
        #expect(GoalState.progressFraction(consumed: 1500, minimum: 3000) == 0.5)
        #expect(GoalState.progressFraction(consumed: 4500, minimum: 3000) == 1.0)
        #expect(GoalState.progressFraction(consumed: 0, minimum: 3000) == 0)
        #expect(GoalState.progressFraction(consumed: 100, minimum: 0) == 1)
    }
}

@Suite("Water math")
struct WaterTests {
    @Test("Totals sum a day's entries")
    func totals() {
        let day = Calendar.current.startOfDay(for: Date())
        let entries = [
            WaterEntry(dayKey: day, amountML: 250),
            WaterEntry(dayKey: day, amountML: 500),
            WaterEntry(dayKey: day, amountML: 330),
        ]
        #expect(WaterMath.totalML(entries: entries) == 1080)
    }

    @Test("Progress clamps and handles zero goal")
    func progress() {
        #expect(WaterMath.progressFraction(totalML: 1500, goalML: 3000) == 0.5)
        #expect(WaterMath.progressFraction(totalML: 4000, goalML: 3000) == 1)
        #expect(WaterMath.progressFraction(totalML: 100, goalML: 0) == 1)
        #expect(WaterMath.progressFraction(totalML: 0, goalML: 0) == 0)
    }

    @Test("Unit conversion round-trips")
    func unitConversion() {
        let ml = WaterUnit.fluidOunces.toMilliliters(12)
        #expect(abs(WaterUnit.fluidOunces.fromMilliliters(ml) - 12) < 0.0001)
        #expect(abs(ml - 354.88) < 0.01)
    }
}
