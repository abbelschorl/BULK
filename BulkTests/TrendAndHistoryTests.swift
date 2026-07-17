import Foundation
import SwiftData
import Testing
@testable import Bulk

private func day(_ offset: Int, from base: Date = Calendar.current.startOfDay(for: Date())) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: base)!
}

@Suite("Weight 7-day moving average")
struct MovingAverageTests {
    @Test("Averages a trailing 7-day window")
    func window() {
        let points = (0..<7).map { WeightTrendCalculator.Point(date: day($0), kg: 80 + Double($0)) }
        let ma = WeightTrendCalculator.movingAverage7(points: points)
        #expect(ma.count == 7)
        // First day: only itself.
        #expect(ma.first?.kg == 80)
        // Last day: average of 80...86 = 83.
        #expect(ma.last?.kg == 83)
    }

    @Test("Multiple weigh-ins on one day are averaged first")
    func sameDayAveraging() {
        let base = Calendar.current.startOfDay(for: Date())
        let points = [
            WeightTrendCalculator.Point(date: base.addingTimeInterval(3600), kg: 80),
            WeightTrendCalculator.Point(date: base.addingTimeInterval(7200), kg: 82),
        ]
        let ma = WeightTrendCalculator.movingAverage7(points: points)
        #expect(ma.count == 1)
        #expect(ma.first?.kg == 81)
    }

    @Test("Missing days are skipped, not treated as zero")
    func missingDays() {
        let points = [
            WeightTrendCalculator.Point(date: day(0), kg: 80),
            WeightTrendCalculator.Point(date: day(6), kg: 84), // 5-day gap
        ]
        let ma = WeightTrendCalculator.movingAverage7(points: points)
        #expect(ma.count == 2)
        #expect(ma.last?.kg == 82) // (80 + 84) / 2, not dragged down by zeros
    }

    @Test("Weekly rate from moving average")
    func weeklyRate() {
        // Steady 0.5 kg over 14 days = 0.25 kg/week.
        let points = (0..<15).map {
            WeightTrendCalculator.Point(date: day($0), kg: 80 + Double($0) * (0.5 / 14))
        }
        let ma = WeightTrendCalculator.movingAverage7(points: points)
        let rate = WeightTrendCalculator.weeklyRateKg(movingAverage: ma)
        #expect(rate != nil)
        #expect(abs(rate! - 0.25) < 0.01)
    }

    @Test("Rate needs at least a day of span")
    func insufficientData() {
        let single = [WeightTrendCalculator.Point(date: day(0), kg: 80)]
        #expect(WeightTrendCalculator.weeklyRateKg(movingAverage: single) == nil)
        #expect(WeightTrendCalculator.weeklyRateKg(movingAverage: []) == nil)
    }

    @Test("Trend assessment uses a neutral ±0.1 band")
    func assessment() {
        #expect(WeightTrendCalculator.assess(weeklyRateKg: 0.05, desiredWeeklyGainKg: 0.25) == .belowDesired)
        #expect(WeightTrendCalculator.assess(weeklyRateKg: 0.3, desiredWeeklyGainKg: 0.25) == .nearDesired)
        #expect(WeightTrendCalculator.assess(weeklyRateKg: 0.5, desiredWeeklyGainKg: 0.25) == .aboveDesired)
    }
}

@Suite("Streaks")
struct StreakTests {
    private func summary(_ offset: Int, kcal: Int, protein: Int) -> DaySummary {
        DaySummary(dayKey: day(offset), calories: Decimal(kcal), protein: Decimal(protein))
    }

    @Test("Current and longest streaks for both goals")
    func streaks() {
        // Days -5...-4 hit, -3 missed protein, -2...-1 hit, today hit.
        let days = [
            summary(-5, kcal: 3200, protein: 160),
            summary(-4, kcal: 3100, protein: 155),
            summary(-3, kcal: 3300, protein: 120),
            summary(-2, kcal: 3050, protein: 150),
            summary(-1, kcal: 3500, protein: 170),
            summary(0, kcal: 3000, protein: 150),
        ]
        let result = StreakCalculator.streaks(days: days, calorieMin: 3000, proteinMin: 150)
        #expect(result.current == 3)
        #expect(result.longest == 3)
    }

    @Test("An unfinished today does not break the streak")
    func todayInProgress() {
        let days = [
            summary(-2, kcal: 3200, protein: 160),
            summary(-1, kcal: 3100, protein: 155),
            summary(0, kcal: 500, protein: 20), // today, still eating
        ]
        let result = StreakCalculator.streaks(days: days, calorieMin: 3000, proteinMin: 150)
        #expect(result.current == 2)
    }

    @Test("A skipped calendar day breaks the streak")
    func gapBreaks() {
        let days = [
            summary(-4, kcal: 3200, protein: 160),
            summary(-3, kcal: 3200, protein: 160),
            // -2 missing entirely
            summary(-1, kcal: 3200, protein: 160),
        ]
        let result = StreakCalculator.streaks(days: days, calorieMin: 3000, proteinMin: 150)
        #expect(result.current == 1)
        #expect(result.longest == 2)
    }
}

@Suite("Immutable history & supplements", .serialized)
@MainActor
struct PersistenceTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FoodItem.self, LogEntry.self, SavedMeal.self, SavedMealComponent.self,
            WeightEntry.self, WaterEntry.self, Supplement.self, SupplementLog.self,
            configurations: config
        )
    }

    @Test("Editing a food does not change logged history")
    func immutableHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let food = FoodItem(name: "Oats", caloriesPer100g: 380, proteinPer100g: 13, carbsPer100g: 60, fatPer100g: 7)
        context.insert(food)

        var pending = PendingFood(food: food)
        FoodLogger.log(pending, grams: 100, meal: .breakfast, dayKey: DayKey.today(), context: context)

        // User later "fixes" the food to different values.
        food.caloriesPer100g = 400
        food.proteinPer100g = 15
        food.name = "Oats (updated)"
        try context.save()

        let entries = try context.fetch(FetchDescriptor<LogEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].foodName == "Oats")
        #expect(entries[0].totals.calories == 380)
        #expect(entries[0].totals.protein == 13)

        // Deleting the food also leaves history intact (nullify).
        context.delete(food)
        try context.save()
        let after = try context.fetch(FetchDescriptor<LogEntry>())
        #expect(after.count == 1)
        #expect(after[0].totals.calories == 380)

        pending = PendingFood(entry: after[0])
        #expect(pending.per100g.calories == 380)
    }

    @Test("Editing a saved meal does not change past logs")
    func savedMealEditIsolation() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let meal = SavedMeal(name: "Morning oats")
        context.insert(meal)
        let component = SavedMealComponent(
            foodName: "Oats", grams: 100,
            per100g: NutritionValues(calories: 380, protein: 13, carbs: 60, fat: 7),
            sourceLabel: "My Food", sortOrder: 0
        )
        component.meal = meal
        context.insert(component)

        // Log the meal (what LogSavedMealSheet does).
        for item in meal.sortedComponents {
            context.insert(
                LogEntry(
                    dayKey: DayKey.today(), mealType: .breakfast, grams: item.grams,
                    foodName: item.foodName, per100g: item.per100g, sourceLabel: item.sourceLabel
                )
            )
        }
        try context.save()

        // Edit the meal afterwards.
        component.grams = 150
        component.caloriesPer100g = 999
        try context.save()

        let entries = try context.fetch(FetchDescriptor<LogEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].grams == 100)
        #expect(entries[0].totals.calories == 380)
    }

    @Test("Supplement checklist resets per day while history persists")
    func supplementDailyReset() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let creatine = Supplement(name: "Creatine", dose: "5 g", sortOrder: 0)
        context.insert(creatine)

        let yesterday = day(-1)
        let today = day(0)
        context.insert(SupplementLog(dayKey: yesterday, supplement: creatine))
        try context.save()

        let logs = try context.fetch(FetchDescriptor<SupplementLog>())

        // Yesterday shows completed; today starts fresh.
        let doneYesterday = SupplementDay.completedSupplementIDs(logs: logs, dayKey: yesterday)
        let doneToday = SupplementDay.completedSupplementIDs(logs: logs, dayKey: today)
        #expect(doneYesterday.contains(creatine.persistentModelID))
        #expect(doneToday.isEmpty)

        // Completing today keeps yesterday's history intact.
        context.insert(SupplementLog(dayKey: today, supplement: creatine))
        try context.save()
        let allLogs = try context.fetch(FetchDescriptor<SupplementLog>())
        #expect(allLogs.count == 2)
        #expect(SupplementDay.completedSupplementIDs(logs: allLogs, dayKey: today).contains(creatine.persistentModelID))

        #expect(SupplementDay.completionFraction(activeCount: 4, completedCount: 2) == 0.5)
        #expect(SupplementDay.completionFraction(activeCount: 0, completedCount: 0) == 0)
    }
}
