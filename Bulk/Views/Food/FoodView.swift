import SwiftData
import SwiftUI

/// Food tab: fastest possible path from "I ate something" to "it's logged".
struct FoodView: View {
    var body: some View {
        NavigationStack {
            FoodCatalogView(dayKey: DayKey.today(), initialMeal: nil)
                .navigationTitle("Food")
        }
    }
}

/// Sheet wrapper used from Today so foods land on the selected day.
struct FoodCatalogSheet: View {
    var dayKey: Date
    var initialMeal: MealType?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FoodCatalogView(dayKey: dayKey, initialMeal: initialMeal, dismissAfterLog: true)
                .navigationTitle("Add Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// The shared search-and-log surface: local library instantly, public
/// databases behind a short debounce, sources clearly labeled.
struct FoodCatalogView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var dayKey: Date
    var initialMeal: MealType?
    var dismissAfterLog = false

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    @State private var query = ""
    @State private var publicResults: [FoodSearchResult] = []
    @State private var publicNotes: [String] = []
    @State private var isSearchingPublic = false
    @State private var searchTask: Task<Void, Never>?

    @State private var pendingFood: PendingFood?
    @State private var showScanner = false
    @State private var showCustomFoodEditor = false
    @State private var mealToLog: SavedMeal?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                searchBar

                if trimmedQuery.isEmpty {
                    browseSections
                } else {
                    searchResults
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .bulkScreen()
        .sheet(item: $pendingFood) { pending in
            LogFoodSheet(
                pending: pending,
                dayKey: dayKey,
                initialMeal: initialMeal ?? .snack
            )
            .onDisappear {
                if dismissAfterLog { dismiss() }
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScanView(dayKey: dayKey, initialMeal: initialMeal ?? .snack)
        }
        .sheet(isPresented: $showCustomFoodEditor) {
            CustomFoodEditor(prefillName: trimmedQuery)
        }
        .sheet(item: $mealToLog) { meal in
            LogSavedMealSheet(meal: meal, dayKey: dayKey, initialMeal: initialMeal ?? .snack)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textTertiary)
                TextField("Search foods", text: $query)
                    .foregroundStyle(Theme.textPrimary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityLabel("Search foods")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )

            Button {
                showScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityLabel("Scan barcode")
        }
        .padding(.top, 6)
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
    }

    // MARK: - Browse (no query)

    @ViewBuilder
    private var browseSections: some View {
        let favorites = allFoods.filter { $0.isFavorite }
        let recents = allFoods
            .filter { $0.lastLoggedAt != nil }
            .sorted { ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast) }
            .prefix(8)
        let myFoods = allFoods.filter { $0.source == .myFood }

        if favorites.isEmpty && recents.isEmpty && myFoods.isEmpty && savedMeals.isEmpty {
            BulkCard {
                VStack(spacing: 10) {
                    Image(systemName: "carrot")
                        .font(.title)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Your food library is empty")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Search a food, scan a barcode, or create a custom food. Everything you log builds your personal library.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }

        if !favorites.isEmpty {
            foodSection(title: "Favorites", systemImage: "star.fill", foods: favorites)
        }
        if !recents.isEmpty {
            foodSection(title: "Recent", systemImage: "clock", foods: Array(recents))
        }
        if !savedMeals.isEmpty {
            savedMealsSection
        }
        if !myFoods.isEmpty {
            foodSection(title: "My Foods", systemImage: "person.crop.square", foods: myFoods)
        }

        Button {
            showCustomFoodEditor = true
        } label: {
            Label("Create custom food", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    private func foodSection(title: String, systemImage: String, foods: [FoodItem]) -> some View {
        VStack(spacing: 8) {
            SectionHeader(title: title, systemImage: systemImage)
            BulkCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(foods) { food in
                        FoodRow(
                            name: food.name,
                            brand: food.brand,
                            sourceLabel: nil,
                            per100g: food.per100g,
                            incomplete: false
                        ) {
                            pendingFood = PendingFood(food: food)
                        }
                        if food.persistentModelID != foods.last?.persistentModelID {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    private var savedMealsSection: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Saved Meals", systemImage: "square.stack.3d.up")
            BulkCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(savedMeals) { meal in
                        Button {
                            mealToLog = meal
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(meal.sortedComponents.count) foods · \(Format.kcal(meal.totals.calories)) kcal · \(Format.macroGrams(meal.totals.protein)) g protein")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Saved meal \(meal.name), \(Format.kcal(meal.totals.calories)) calories")
                        if meal.persistentModelID != savedMeals.last?.persistentModelID {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResults: some View {
        let localResults = FoodSearchService.localMatches(query: trimmedQuery, foods: allFoods)

        if !localResults.isEmpty {
            resultsSection(title: "Your Library", results: localResults)
        }

        if isSearchingPublic {
            HStack(spacing: 8) {
                SwiftUI.ProgressView()
                Text("Searching Open Food Facts and USDA…")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 10)
        }

        ForEach(publicNotes, id: \.self) { note in
            BulkCard(padding: 12) {
                Label {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }

        if !publicResults.isEmpty {
            resultsSection(title: "Public Databases", results: publicResults)
        }

        if localResults.isEmpty && publicResults.isEmpty && !isSearchingPublic {
            BulkCard {
                VStack(spacing: 8) {
                    Text("No results for “\(trimmedQuery)”")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("You can create it once and reuse it forever.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }

        Button {
            showCustomFoodEditor = true
        } label: {
            Label("Create custom food", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    private func resultsSection(title: String, results: [FoodSearchResult]) -> some View {
        VStack(spacing: 8) {
            SectionHeader(title: title)
            BulkCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        FoodRow(
                            name: result.name,
                            brand: result.brand,
                            sourceLabel: result.origin.label,
                            per100g: result.per100g,
                            incomplete: result.hasIncompleteNutrition
                        ) {
                            pendingFood = PendingFood(result: result)
                        }
                        if result.id != results.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        publicResults = []
        publicNotes = []
        let current = trimmedQuery
        guard current.count >= 2 else {
            isSearchingPublic = false
            return
        }
        isSearchingPublic = true
        let apiKey = settings.usdaAPIKey
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let service = FoodSearchService()
            let (results, notes) = await service.searchPublic(query: current, usdaAPIKey: apiKey)
            guard !Task.isCancelled, current == trimmedQuery else { return }
            publicResults = results
            publicNotes = notes
            isSearchingPublic = false
        }
    }
}

/// One food row: name, source, kcal & protein per 100 g, subdued carbs/fat.
struct FoodRow: View {
    var name: String
    var brand: String?
    var sourceLabel: String?
    var per100g: NutritionValues
    var incomplete: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        if incomplete {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.belowGoal)
                                .accessibilityLabel("Incomplete nutrition data")
                        }
                    }
                    HStack(spacing: 6) {
                        if let brand, !brand.isEmpty {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                        if let sourceLabel {
                            SourceBadge(label: sourceLabel)
                        }
                    }
                    Text("C \(Format.macroGrams(per100g.carbs)) g · F \(Format.macroGrams(per100g.fat)) g per 100 g")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Format.kcal(per100g.calories)) kcal")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(Format.macroGrams(per100g.protein)) g protein")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)\(brand.map { ", \($0)" } ?? ""). \(Format.kcal(per100g.calories)) calories and \(Format.macroGrams(per100g.protein)) grams protein per 100 grams.\(incomplete ? " Warning: incomplete nutrition data." : "")")
    }
}
