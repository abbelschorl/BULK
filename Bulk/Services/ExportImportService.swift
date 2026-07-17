import Foundation
import SwiftData

/// JSON backup of every user-created record plus settings. Import merges by
/// inserting fresh records after the user confirms (import replaces all data
/// so restore is deterministic).
enum ExportImportService {
    struct Backup: Codable {
        var version: Int = 1
        var exportedAt: Date = Date()
        var settings: SettingsBackup
        var foods: [FoodBackup] = []
        var logEntries: [LogEntryBackup] = []
        var savedMeals: [SavedMealBackup] = []
        var weightEntries: [WeightBackup] = []
        var waterEntries: [WaterBackup] = []
        var supplements: [SupplementBackup] = []
    }

    struct SettingsBackup: Codable {
        var calorieMinimum: Int
        var proteinMinimum: Int
        var waterGoalML: Double
        var desiredWeeklyGainKg: Double
        var weightUnit: String
        var waterUnit: String
    }

    struct FoodBackup: Codable {
        var name: String
        var brand: String?
        var caloriesPer100g: Decimal
        var proteinPer100g: Decimal
        var carbsPer100g: Decimal
        var fatPer100g: Decimal
        var defaultServingGrams: Decimal?
        var notes: String?
        var barcode: String?
        var isFavorite: Bool
        var source: String
        var createdAt: Date
        var lastLoggedAt: Date?
    }

    struct LogEntryBackup: Codable {
        var loggedAt: Date
        var dayKey: Date
        var mealType: String
        var grams: Decimal
        var foodName: String
        var foodBrand: String?
        var caloriesPer100g: Decimal
        var proteinPer100g: Decimal
        var carbsPer100g: Decimal
        var fatPer100g: Decimal
        var sourceLabel: String
    }

    struct SavedMealBackup: Codable {
        struct Component: Codable {
            var foodName: String
            var foodBrand: String?
            var grams: Decimal
            var caloriesPer100g: Decimal
            var proteinPer100g: Decimal
            var carbsPer100g: Decimal
            var fatPer100g: Decimal
            var sourceLabel: String
            var sortOrder: Int
        }

        var name: String
        var createdAt: Date
        var components: [Component]
    }

    struct WeightBackup: Codable {
        var date: Date
        var weightKg: Double
        var note: String?
        var healthKitUUID: String?
    }

    struct WaterBackup: Codable {
        var date: Date
        var dayKey: Date
        var amountML: Double
    }

    struct SupplementBackup: Codable {
        var name: String
        var dose: String?
        var timeOfDayLabel: String?
        var notes: String?
        var isActive: Bool
        var isArchived: Bool
        var sortOrder: Int
        var createdAt: Date
        var completedDayKeys: [Date]
    }

    enum ImportError: LocalizedError {
        case unreadable

        var errorDescription: String? {
            "This file doesn't look like a Bulk backup. Nothing was changed."
        }
    }

    // MARK: - Export

    @MainActor
    static func makeBackup(context: ModelContext, settings: AppSettings) throws -> Backup {
        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let entries = try context.fetch(FetchDescriptor<LogEntry>())
        let meals = try context.fetch(FetchDescriptor<SavedMeal>())
        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        let water = try context.fetch(FetchDescriptor<WaterEntry>())
        let supplements = try context.fetch(FetchDescriptor<Supplement>())

        return Backup(
            settings: SettingsBackup(
                calorieMinimum: settings.calorieMinimum,
                proteinMinimum: settings.proteinMinimum,
                waterGoalML: settings.waterGoalML,
                desiredWeeklyGainKg: settings.desiredWeeklyGainKg,
                weightUnit: settings.weightUnit.rawValue,
                waterUnit: settings.waterUnit.rawValue
            ),
            foods: foods.map {
                FoodBackup(
                    name: $0.name, brand: $0.brand,
                    caloriesPer100g: $0.caloriesPer100g, proteinPer100g: $0.proteinPer100g,
                    carbsPer100g: $0.carbsPer100g, fatPer100g: $0.fatPer100g,
                    defaultServingGrams: $0.defaultServingGrams, notes: $0.notes,
                    barcode: $0.barcode, isFavorite: $0.isFavorite,
                    source: $0.sourceRaw, createdAt: $0.createdAt, lastLoggedAt: $0.lastLoggedAt
                )
            },
            logEntries: entries.map {
                LogEntryBackup(
                    loggedAt: $0.loggedAt, dayKey: $0.dayKey, mealType: $0.mealTypeRaw,
                    grams: $0.grams, foodName: $0.foodName, foodBrand: $0.foodBrand,
                    caloriesPer100g: $0.caloriesPer100g, proteinPer100g: $0.proteinPer100g,
                    carbsPer100g: $0.carbsPer100g, fatPer100g: $0.fatPer100g,
                    sourceLabel: $0.sourceLabel
                )
            },
            savedMeals: meals.map { meal in
                SavedMealBackup(
                    name: meal.name,
                    createdAt: meal.createdAt,
                    components: meal.sortedComponents.map {
                        SavedMealBackup.Component(
                            foodName: $0.foodName, foodBrand: $0.foodBrand, grams: $0.grams,
                            caloriesPer100g: $0.caloriesPer100g, proteinPer100g: $0.proteinPer100g,
                            carbsPer100g: $0.carbsPer100g, fatPer100g: $0.fatPer100g,
                            sourceLabel: $0.sourceLabel, sortOrder: $0.sortOrder
                        )
                    }
                )
            },
            weightEntries: weights.map {
                WeightBackup(date: $0.date, weightKg: $0.weightKg, note: $0.note, healthKitUUID: $0.healthKitUUID)
            },
            waterEntries: water.map {
                WaterBackup(date: $0.date, dayKey: $0.dayKey, amountML: $0.amountML)
            },
            supplements: supplements.map { supplement in
                SupplementBackup(
                    name: supplement.name, dose: supplement.dose,
                    timeOfDayLabel: supplement.timeOfDayLabel, notes: supplement.notes,
                    isActive: supplement.isActive, isArchived: supplement.isArchived,
                    sortOrder: supplement.sortOrder, createdAt: supplement.createdAt,
                    completedDayKeys: (supplement.logs ?? []).map(\.dayKey)
                )
            }
        )
    }

    @MainActor
    static func exportData(context: ModelContext, settings: AppSettings) throws -> Data {
        let backup = try makeBackup(context: context, settings: settings)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    // MARK: - Import

    static func decodeBackup(from data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Backup.self, from: data)
        } catch {
            throw ImportError.unreadable
        }
    }

    /// Replaces all stored data with the backup's contents.
    @MainActor
    static func restore(_ backup: Backup, context: ModelContext, settings: AppSettings) throws {
        try deleteAllData(context: context)

        for food in backup.foods {
            let item = FoodItem(
                name: food.name, brand: food.brand,
                caloriesPer100g: food.caloriesPer100g, proteinPer100g: food.proteinPer100g,
                carbsPer100g: food.carbsPer100g, fatPer100g: food.fatPer100g,
                defaultServingGrams: food.defaultServingGrams, notes: food.notes,
                barcode: food.barcode, isFavorite: food.isFavorite,
                source: FoodSource(rawValue: food.source) ?? .myFood
            )
            item.createdAt = food.createdAt
            item.lastLoggedAt = food.lastLoggedAt
            context.insert(item)
        }

        for entry in backup.logEntries {
            context.insert(
                LogEntry(
                    loggedAt: entry.loggedAt,
                    dayKey: entry.dayKey,
                    mealType: MealType(rawValue: entry.mealType) ?? .snack,
                    grams: entry.grams,
                    foodName: entry.foodName,
                    foodBrand: entry.foodBrand,
                    per100g: NutritionValues(
                        calories: entry.caloriesPer100g, protein: entry.proteinPer100g,
                        carbs: entry.carbsPer100g, fat: entry.fatPer100g
                    ),
                    sourceLabel: entry.sourceLabel
                )
            )
        }

        for mealBackup in backup.savedMeals {
            let meal = SavedMeal(name: mealBackup.name)
            meal.createdAt = mealBackup.createdAt
            context.insert(meal)
            for component in mealBackup.components {
                let modelComponent = SavedMealComponent(
                    foodName: component.foodName,
                    foodBrand: component.foodBrand,
                    grams: component.grams,
                    per100g: NutritionValues(
                        calories: component.caloriesPer100g, protein: component.proteinPer100g,
                        carbs: component.carbsPer100g, fat: component.fatPer100g
                    ),
                    sourceLabel: component.sourceLabel,
                    sortOrder: component.sortOrder
                )
                modelComponent.meal = meal
                context.insert(modelComponent)
            }
        }

        for weight in backup.weightEntries {
            context.insert(
                WeightEntry(date: weight.date, weightKg: weight.weightKg, note: weight.note, healthKitUUID: weight.healthKitUUID)
            )
        }

        for water in backup.waterEntries {
            context.insert(WaterEntry(date: water.date, dayKey: water.dayKey, amountML: water.amountML))
        }

        for supplementBackup in backup.supplements {
            let supplement = Supplement(
                name: supplementBackup.name,
                dose: supplementBackup.dose,
                timeOfDayLabel: supplementBackup.timeOfDayLabel,
                notes: supplementBackup.notes,
                isActive: supplementBackup.isActive,
                sortOrder: supplementBackup.sortOrder
            )
            supplement.isArchived = supplementBackup.isArchived
            supplement.createdAt = supplementBackup.createdAt
            context.insert(supplement)
            for dayKey in supplementBackup.completedDayKeys {
                context.insert(SupplementLog(dayKey: dayKey, supplement: supplement))
            }
        }

        settings.calorieMinimum = backup.settings.calorieMinimum
        settings.proteinMinimum = backup.settings.proteinMinimum
        settings.waterGoalML = backup.settings.waterGoalML
        settings.desiredWeeklyGainKg = backup.settings.desiredWeeklyGainKg
        settings.weightUnit = WeightUnit(rawValue: backup.settings.weightUnit) ?? .kilograms
        settings.waterUnit = WaterUnit(rawValue: backup.settings.waterUnit) ?? .milliliters

        try context.save()
    }

    @MainActor
    static func deleteAllData(context: ModelContext) throws {
        try context.delete(model: SupplementLog.self)
        try context.delete(model: Supplement.self)
        try context.delete(model: WaterEntry.self)
        try context.delete(model: WeightEntry.self)
        try context.delete(model: SavedMealComponent.self)
        try context.delete(model: SavedMeal.self)
        try context.delete(model: LogEntry.self)
        try context.delete(model: FoodItem.self)
        try context.save()
    }
}
