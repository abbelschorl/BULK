import Foundation

/// Meal categories a log entry can belong to.
enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "sparkles"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }
}

/// Where a food's nutrition data originally came from.
enum FoodSource: String, Codable {
    case myFood
    case openFoodFacts
    case usda

    var displayLabel: String {
        switch self {
        case .myFood: "My Food"
        case .openFoodFacts: "Open Food Facts"
        case .usda: "USDA"
        }
    }
}

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }

    /// Converts a canonical kilogram value into this unit for display.
    func fromKilograms(_ kg: Double) -> Double {
        switch self {
        case .kilograms: kg
        case .pounds: kg * 2.20462262185
        }
    }

    /// Converts a value entered in this unit into canonical kilograms for storage.
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / 2.20462262185
        }
    }
}

enum WaterUnit: String, CaseIterable, Codable, Identifiable {
    case milliliters
    case fluidOunces

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .milliliters: "ml"
        case .fluidOunces: "fl oz"
        }
    }

    /// Converts canonical milliliters into this unit for display.
    func fromMilliliters(_ ml: Double) -> Double {
        switch self {
        case .milliliters: ml
        case .fluidOunces: ml / 29.5735295625
        }
    }

    /// Converts a value entered in this unit into canonical milliliters for storage.
    func toMilliliters(_ value: Double) -> Double {
        switch self {
        case .milliliters: value
        case .fluidOunces: value * 29.5735295625
        }
    }
}
