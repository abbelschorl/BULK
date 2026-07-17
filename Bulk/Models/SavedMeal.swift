import Foundation
import SwiftData

/// A reusable group of foods (e.g. "Morning oats"). Components carry their own
/// per-100 g snapshots, so a saved meal is self-contained: logging it copies
/// values into LogEntries, and editing it never rewrites past diary entries.
@Model
final class SavedMeal {
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SavedMealComponent.meal)
    var components: [SavedMealComponent]? = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    var sortedComponents: [SavedMealComponent] {
        (components ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var totals: NutritionValues {
        sortedComponents.reduce(.zero) { partial, component in
            partial + NutritionCalculator.scale(per100g: component.per100g, grams: component.grams)
        }
    }
}

@Model
final class SavedMealComponent {
    var foodName: String = ""
    var foodBrand: String?
    var grams: Decimal = 0
    var caloriesPer100g: Decimal = 0
    var proteinPer100g: Decimal = 0
    var carbsPer100g: Decimal = 0
    var fatPer100g: Decimal = 0
    var sourceLabel: String = FoodSource.myFood.displayLabel
    var sortOrder: Int = 0

    var meal: SavedMeal?

    init(
        foodName: String,
        foodBrand: String? = nil,
        grams: Decimal,
        per100g: NutritionValues,
        sourceLabel: String,
        sortOrder: Int
    ) {
        self.foodName = foodName
        self.foodBrand = foodBrand
        self.grams = grams
        self.caloriesPer100g = per100g.calories
        self.proteinPer100g = per100g.protein
        self.carbsPer100g = per100g.carbs
        self.fatPer100g = per100g.fat
        self.sourceLabel = sourceLabel
        self.sortOrder = sortOrder
    }

    var per100g: NutritionValues {
        NutritionValues(
            calories: caloriesPer100g,
            protein: proteinPer100g,
            carbs: carbsPer100g,
            fat: fatPer100g
        )
    }
}
