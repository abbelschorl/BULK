import Foundation
import SwiftData

/// A food the user is about to log, regardless of where it came from
/// (library, recent, public search, barcode). Carries everything the logging
/// sheet needs plus the optional library reference for recents/favorites.
struct PendingFood: Identifiable {
    let id = UUID()
    var name: String
    var brand: String?
    var per100g: NutritionValues
    var sourceLabel: String
    var defaultServingGrams: Decimal?
    var barcode: String?
    var hasIncompleteNutrition: Bool = false
    var missingFields: [String] = []
    /// Set when this food already exists in the local library.
    var foodItemID: PersistentIdentifier?
    /// Origin kind, used to offer "save to My Foods" for public results.
    var isPublicResult: Bool = false

    init(food: FoodItem) {
        name = food.name
        brand = food.brand
        per100g = food.per100g
        sourceLabel = food.source == .myFood ? FoodSource.myFood.displayLabel : food.source.displayLabel
        defaultServingGrams = food.defaultServingGrams
        barcode = food.barcode
        foodItemID = food.persistentModelID
    }

    init(result: FoodSearchResult) {
        name = result.name
        brand = result.brand
        per100g = result.per100g
        sourceLabel = result.origin.label
        defaultServingGrams = result.defaultServingGrams
        barcode = result.barcode
        hasIncompleteNutrition = result.hasIncompleteNutrition
        missingFields = result.missingFields
        switch result.origin {
        case .myFood(let id), .recent(let id):
            foodItemID = id
            sourceLabel = FoodSource.myFood.displayLabel
        case .openFoodFacts, .usda:
            isPublicResult = true
        }
    }
}

/// Central mutation: inserts an immutable LogEntry snapshot for a pending food
/// and touches the linked FoodItem's lastLoggedAt for "recent" suggestions.
@MainActor
enum FoodLogger {
    static func log(
        _ pending: PendingFood,
        grams: Decimal,
        meal: MealType,
        dayKey: Date,
        context: ModelContext
    ) {
        var linkedFood: FoodItem?
        if let id = pending.foodItemID {
            linkedFood = context.model(for: id) as? FoodItem
        }
        let entry = LogEntry(
            dayKey: dayKey,
            mealType: meal,
            grams: grams,
            foodName: pending.name,
            foodBrand: pending.brand,
            per100g: pending.per100g,
            sourceLabel: pending.sourceLabel,
            foodItem: linkedFood
        )
        context.insert(entry)
        linkedFood?.lastLoggedAt = Date()
        try? context.save()
    }

    /// Saves a public result into the personal library so it works offline
    /// and appears under My Foods from now on.
    @discardableResult
    static func saveToLibrary(_ pending: PendingFood, context: ModelContext, favorite: Bool = false) -> FoodItem {
        let food = FoodItem(
            name: pending.name,
            brand: pending.brand,
            caloriesPer100g: pending.per100g.calories,
            proteinPer100g: pending.per100g.protein,
            carbsPer100g: pending.per100g.carbs,
            fatPer100g: pending.per100g.fat,
            defaultServingGrams: pending.defaultServingGrams,
            barcode: pending.barcode,
            isFavorite: favorite,
            source: pending.sourceLabel == FoodSource.usda.displayLabel ? .usda : .openFoodFacts
        )
        food.lastLoggedAt = Date()
        context.insert(food)
        try? context.save()
        return food
    }
}
