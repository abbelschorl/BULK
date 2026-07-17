import SwiftData
import SwiftUI

@main
struct BulkApp: App {
    let container: ModelContainer
    @State private var settings = AppSettings.shared
    @State private var healthKit = HealthKitService()

    init() {
        do {
            container = try ModelContainer(
                for: FoodItem.self, LogEntry.self, SavedMeal.self, SavedMealComponent.self,
                WeightEntry.self, WaterEntry.self, Supplement.self, SupplementLog.self
            )
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
        Self.seedDefaultSupplements(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(settings)
                .environment(healthKit)
                .preferredColorScheme(settings.followSystemAppearance ? nil : .dark)
                .tint(Theme.textPrimary)
        }
        .modelContainer(container)
    }

    /// Preloads the common bulking supplements once, on first launch.
    @MainActor
    private static func seedDefaultSupplements(container: ModelContainer) {
        let seededKey = "seed.defaultSupplements.v1"
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        let context = container.mainContext
        let defaults: [(String, String?, String?)] = [
            ("Creatine", "5 g", nil),
            ("Omega-3", "1,000 mg", "With a meal"),
            ("Magnesium", "400 mg", "Evening"),
            ("Protein powder", "30 g", nil),
        ]
        for (index, item) in defaults.enumerated() {
            context.insert(
                Supplement(name: item.0, dose: item.1, timeOfDayLabel: item.2, sortOrder: index)
            )
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
