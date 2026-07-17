import Foundation
import SwiftData

/// A food in the user's personal library: custom foods plus foods saved from
/// public database results. All nutrition values are per 100 g.
@Model
final class FoodItem {
    var name: String = ""
    var brand: String?
    var caloriesPer100g: Decimal = 0
    var proteinPer100g: Decimal = 0
    var carbsPer100g: Decimal = 0
    var fatPer100g: Decimal = 0
    var defaultServingGrams: Decimal?
    var notes: String?
    var barcode: String?
    var isFavorite: Bool = false
    var sourceRaw: String = FoodSource.myFood.rawValue
    var createdAt: Date = Date()
    var lastLoggedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \LogEntry.foodItem)
    var logEntries: [LogEntry]? = []

    init(
        name: String,
        brand: String? = nil,
        caloriesPer100g: Decimal,
        proteinPer100g: Decimal,
        carbsPer100g: Decimal,
        fatPer100g: Decimal,
        defaultServingGrams: Decimal? = nil,
        notes: String? = nil,
        barcode: String? = nil,
        isFavorite: Bool = false,
        source: FoodSource = .myFood
    ) {
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.defaultServingGrams = defaultServingGrams
        self.notes = notes
        self.barcode = barcode
        self.isFavorite = isFavorite
        self.sourceRaw = source.rawValue
        self.createdAt = Date()
    }

    var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .myFood }
        set { sourceRaw = newValue.rawValue }
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
