import Foundation
import SwiftUI

/// User-configurable settings, backed by UserDefaults. Goals are minimums —
/// the app never defines an upper warning range.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        calorieMinimum = Self.readInt(defaults, Keys.calorieMinimum, fallback: 3000)
        proteinMinimum = Self.readInt(defaults, Keys.proteinMinimum, fallback: 150)
        waterGoalML = Self.readDouble(defaults, Keys.waterGoalML, fallback: 3000)
        desiredWeeklyGainKg = Self.readDouble(defaults, Keys.desiredWeeklyGainKg, fallback: 0.25)
        weightUnit = WeightUnit(rawValue: defaults.string(forKey: Keys.weightUnit) ?? "") ?? .kilograms
        waterUnit = WaterUnit(rawValue: defaults.string(forKey: Keys.waterUnit) ?? "") ?? .milliliters
        usdaAPIKey = defaults.string(forKey: Keys.usdaAPIKey) ?? ""
        healthKitSyncEnabled = defaults.bool(forKey: Keys.healthKitSyncEnabled)
        followSystemAppearance = defaults.bool(forKey: Keys.followSystemAppearance)
    }

    var calorieMinimum: Int { didSet { defaults.set(calorieMinimum, forKey: Keys.calorieMinimum) } }
    var proteinMinimum: Int { didSet { defaults.set(proteinMinimum, forKey: Keys.proteinMinimum) } }
    var waterGoalML: Double { didSet { defaults.set(waterGoalML, forKey: Keys.waterGoalML) } }
    var desiredWeeklyGainKg: Double { didSet { defaults.set(desiredWeeklyGainKg, forKey: Keys.desiredWeeklyGainKg) } }
    var weightUnit: WeightUnit { didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) } }
    var waterUnit: WaterUnit { didSet { defaults.set(waterUnit.rawValue, forKey: Keys.waterUnit) } }
    /// Stored locally on-device only; never shipped with the app.
    var usdaAPIKey: String { didSet { defaults.set(usdaAPIKey, forKey: Keys.usdaAPIKey) } }
    var healthKitSyncEnabled: Bool { didSet { defaults.set(healthKitSyncEnabled, forKey: Keys.healthKitSyncEnabled) } }
    /// Off by default: the app is designed dark-first.
    var followSystemAppearance: Bool { didSet { defaults.set(followSystemAppearance, forKey: Keys.followSystemAppearance) } }

    var calorieMinimumDecimal: Decimal { Decimal(calorieMinimum) }
    var proteinMinimumDecimal: Decimal { Decimal(proteinMinimum) }

    private enum Keys {
        static let calorieMinimum = "settings.calorieMinimum"
        static let proteinMinimum = "settings.proteinMinimum"
        static let waterGoalML = "settings.waterGoalML"
        static let desiredWeeklyGainKg = "settings.desiredWeeklyGainKg"
        static let weightUnit = "settings.weightUnit"
        static let waterUnit = "settings.waterUnit"
        static let usdaAPIKey = "settings.usdaAPIKey"
        static let healthKitSyncEnabled = "settings.healthKitSyncEnabled"
        static let followSystemAppearance = "settings.followSystemAppearance"
    }

    private static func readInt(_ defaults: UserDefaults, _ key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    private static func readDouble(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
