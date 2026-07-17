import Foundation
import SwiftData

/// A normalized food search result from any source, always per 100 g.
/// Public-database rows with unusable nutrition data are flagged so the UI can
/// show "incomplete data" before the user logs anything.
struct FoodSearchResult: Identifiable, Equatable {
    enum Origin: Equatable {
        case myFood(PersistentIdentifier)
        case recent(PersistentIdentifier)
        case openFoodFacts
        case usda

        var label: String {
            switch self {
            case .myFood: "My Food"
            case .recent: "Recent"
            case .openFoodFacts: "Open Food Facts"
            case .usda: "USDA"
            }
        }
    }

    let id: String
    var name: String
    var brand: String?
    var per100g: NutritionValues
    var origin: Origin
    var barcode: String?
    var defaultServingGrams: Decimal?
    /// True when calories or protein were missing in the source data.
    var hasIncompleteNutrition: Bool

    /// Names of nutrition fields the source did not provide.
    var missingFields: [String]
}
