import Foundation
import SwiftData

/// One logged food in the diary. Nutrition values are snapshotted at log time
/// so editing a library food later never changes history. The optional
/// `foodItem` reference exists only to power "recent foods" suggestions.
@Model
final class LogEntry {
    var loggedAt: Date = Date()
    /// Local-timezone start of day the entry belongs to; the diary groups by this.
    var dayKey: Date = Date()
    var mealTypeRaw: String = MealType.snack.rawValue
    var grams: Decimal = 0

    // Snapshot of the food at log time — immutable history.
    var foodName: String = ""
    var foodBrand: String?
    var caloriesPer100g: Decimal = 0
    var proteinPer100g: Decimal = 0
    var carbsPer100g: Decimal = 0
    var fatPer100g: Decimal = 0
    var sourceLabel: String = FoodSource.myFood.displayLabel

    var foodItem: FoodItem?

    init(
        loggedAt: Date = Date(),
        dayKey: Date,
        mealType: MealType,
        grams: Decimal,
        foodName: String,
        foodBrand: String? = nil,
        per100g: NutritionValues,
        sourceLabel: String,
        foodItem: FoodItem? = nil
    ) {
        self.loggedAt = loggedAt
        self.dayKey = dayKey
        self.mealTypeRaw = mealType.rawValue
        self.grams = grams
        self.foodName = foodName
        self.foodBrand = foodBrand
        self.caloriesPer100g = per100g.calories
        self.proteinPer100g = per100g.protein
        self.carbsPer100g = per100g.carbs
        self.fatPer100g = per100g.fat
        self.sourceLabel = sourceLabel
        self.foodItem = foodItem
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var per100g: NutritionValues {
        NutritionValues(
            calories: caloriesPer100g,
            protein: proteinPer100g,
            carbs: carbsPer100g,
            fat: fatPer100g
        )
    }

    /// Totals for the logged gram amount, scaled from per-100 g values.
    var totals: NutritionValues {
        NutritionCalculator.scale(per100g: per100g, grams: grams)
    }
}
