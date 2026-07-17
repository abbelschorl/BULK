import SwiftData
import SwiftUI

/// Logs every component of a saved meal into the diary in one tap.
struct LogSavedMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let meal: SavedMeal
    var dayKey: Date
    var initialMeal: MealType = .snack

    @State private var mealType: MealType = .snack

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    BulkCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(meal.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(Format.kcal(meal.totals.calories)) kcal · \(Format.macroGrams(meal.totals.protein)) g protein · \(Format.macroGrams(meal.totals.carbs)) g carbs · \(Format.macroGrams(meal.totals.fat)) g fat")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    BulkCard(padding: 6) {
                        VStack(spacing: 0) {
                            ForEach(meal.sortedComponents) { component in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(component.foodName)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(Format.portionGrams(component.grams))
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    Spacer()
                                    let totals = NutritionCalculator.scale(per100g: component.per100g, grams: component.grams)
                                    Text("\(Format.kcal(totals.calories)) kcal")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                if component.persistentModelID != meal.sortedComponents.last?.persistentModelID {
                                    Divider().overlay(Color.white.opacity(0.06))
                                }
                            }
                        }
                    }

                    BulkCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Log as")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Picker("Meal", selection: $mealType) {
                                ForEach(MealType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(16)
            }
            .bulkScreen()
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add All") { logAll() }
                        .font(.body.weight(.semibold))
                        .disabled(meal.sortedComponents.isEmpty)
                }
            }
        }
        .onAppear { mealType = initialMeal }
    }

    private func logAll() {
        for component in meal.sortedComponents {
            context.insert(
                LogEntry(
                    dayKey: dayKey,
                    mealType: mealType,
                    grams: component.grams,
                    foodName: component.foodName,
                    foodBrand: component.foodBrand,
                    per100g: component.per100g,
                    sourceLabel: component.sourceLabel
                )
            )
        }
        try? context.save()
        dismiss()
    }
}

/// Create or edit a reusable meal. Components snapshot their nutrition, so
/// changing a meal here never rewrites past diary entries.
struct SavedMealEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// When set, edits an existing meal in place.
    var editingMeal: SavedMeal?

    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]

    struct DraftComponent: Identifiable {
        let id = UUID()
        var foodName: String
        var foodBrand: String?
        var grams: Decimal
        var per100g: NutritionValues
        var sourceLabel: String
    }

    @State private var name = ""
    @State private var components: [DraftComponent] = []
    @State private var showFoodPicker = false

    private var totals: NutritionValues {
        components.reduce(.zero) { $0 + NutritionCalculator.scale(per100g: $1.per100g, grams: $1.grams) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name, e.g. Morning oats", text: $name)
                }

                Section {
                    ForEach($components) { $component in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(component.foodName)
                                    .font(.subheadline)
                                Text("\(Format.kcal(NutritionCalculator.scale(per100g: component.per100g, grams: component.grams).calories)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField(
                                "g",
                                value: Binding(
                                    get: { component.grams.doubleValue },
                                    set: { component.grams = Decimal($0) }
                                ),
                                format: .number.precision(.fractionLength(0...1))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .accessibilityLabel("Grams of \(component.foodName)")
                            Text("g").foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { components.remove(atOffsets: $0) }

                    Button {
                        showFoodPicker = true
                    } label: {
                        Label("Add food from library", systemImage: "plus")
                    }
                } header: {
                    Text("Foods")
                } footer: {
                    if !components.isEmpty {
                        Text("Total: \(Format.kcal(totals.calories)) kcal · \(Format.macroGrams(totals.protein)) g protein")
                            .monospacedDigit()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editingMeal == nil ? "New Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || components.isEmpty)
                }
            }
            .sheet(isPresented: $showFoodPicker) {
                NavigationStack {
                    List(allFoods) { food in
                        Button {
                            components.append(
                                DraftComponent(
                                    foodName: food.name,
                                    foodBrand: food.brand,
                                    grams: food.defaultServingGrams ?? 100,
                                    per100g: food.per100g,
                                    sourceLabel: food.source.displayLabel
                                )
                            )
                            showFoodPicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name)
                                Text("\(Format.kcal(food.caloriesPer100g)) kcal / 100 g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Pick Food")
                    .navigationBarTitleDisplayMode(.inline)
                    .overlay {
                        if allFoods.isEmpty {
                            ContentUnavailableView(
                                "No foods yet",
                                systemImage: "carrot",
                                description: Text("Create custom foods or save public foods to your library first.")
                            )
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let meal = editingMeal else { return }
        name = meal.name
        components = meal.sortedComponents.map {
            DraftComponent(
                foodName: $0.foodName,
                foodBrand: $0.foodBrand,
                grams: $0.grams,
                per100g: $0.per100g,
                sourceLabel: $0.sourceLabel
            )
        }
    }

    private func save() {
        let meal: SavedMeal
        if let editingMeal {
            meal = editingMeal
            for component in editingMeal.components ?? [] {
                context.delete(component)
            }
        } else {
            meal = SavedMeal(name: name.trimmingCharacters(in: .whitespaces))
            context.insert(meal)
        }
        meal.name = name.trimmingCharacters(in: .whitespaces)
        for (index, draft) in components.enumerated() {
            let component = SavedMealComponent(
                foodName: draft.foodName,
                foodBrand: draft.foodBrand,
                grams: draft.grams,
                per100g: draft.per100g,
                sourceLabel: draft.sourceLabel,
                sortOrder: index
            )
            component.meal = meal
            context.insert(component)
        }
        try? context.save()
        dismiss()
    }
}
