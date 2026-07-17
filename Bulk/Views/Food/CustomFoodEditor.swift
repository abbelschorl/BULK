import SwiftData
import SwiftUI

/// Create or edit a custom food. All nutrition is entered per 100 g.
struct CustomFoodEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var prefillName: String = ""
    var prefillBarcode: String?
    /// When set, edits an existing food (past log entries stay untouched).
    var editingFood: FoodItem?

    @State private var name = ""
    @State private var brand = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var defaultServing = ""
    @State private var barcode = ""
    @State private var notes = ""
    @State private var isFavorite = false

    private var parsedCalories: Decimal? { parse(calories) }
    private var parsedProtein: Decimal? { parse(protein) }
    private var parsedCarbs: Decimal? { parse(carbs) }
    private var parsedFat: Decimal? { parse(fat) }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedCalories != nil && parsedProtein != nil
            && parsedCarbs != nil && parsedFat != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                Section {
                    nutritionField("Calories", text: $calories, unit: "kcal")
                    nutritionField("Protein", text: $protein, unit: "g")
                    nutritionField("Carbs", text: $carbs, unit: "g")
                    nutritionField("Fat", text: $fat, unit: "g")
                } header: {
                    Text("Nutrition per 100 g")
                } footer: {
                    Text("Values come straight from the label. Raw and cooked versions of the same food should be separate entries — they are not interchangeable.")
                }

                Section("Options") {
                    HStack {
                        TextField("Default serving (optional)", text: $defaultServing)
                            .keyboardType(.decimalPad)
                        Text("g").foregroundStyle(.secondary)
                    }
                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                    Toggle("Favorite", isOn: $isFavorite)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editingFood == nil ? "New Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: prefill)
    }

    private func nutritionField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .accessibilityLabel("\(label) per 100 grams")
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func parse(_ text: String) -> Decimal? {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, let value = Decimal(string: normalized), value >= 0 else { return nil }
        return value
    }

    private func prefill() {
        if let food = editingFood {
            name = food.name
            brand = food.brand ?? ""
            calories = Format.macroGrams(food.caloriesPer100g)
            protein = Format.macroGrams(food.proteinPer100g)
            carbs = Format.macroGrams(food.carbsPer100g)
            fat = Format.macroGrams(food.fatPer100g)
            defaultServing = food.defaultServingGrams.map { Format.macroGrams($0) } ?? ""
            barcode = food.barcode ?? ""
            notes = food.notes ?? ""
            isFavorite = food.isFavorite
        } else {
            name = prefillName
            barcode = prefillBarcode ?? ""
        }
    }

    private func save() {
        guard let kcal = parsedCalories, let proteinValue = parsedProtein,
              let carbsValue = parsedCarbs, let fatValue = parsedFat else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let serving = parse(defaultServing)

        if let food = editingFood {
            food.name = trimmedName
            food.brand = trimmedBrand.isEmpty ? nil : trimmedBrand
            food.caloriesPer100g = kcal
            food.proteinPer100g = proteinValue
            food.carbsPer100g = carbsValue
            food.fatPer100g = fatValue
            food.defaultServingGrams = serving
            food.barcode = trimmedBarcode.isEmpty ? nil : trimmedBarcode
            food.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            food.isFavorite = isFavorite
        } else {
            context.insert(
                FoodItem(
                    name: trimmedName,
                    brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
                    caloriesPer100g: kcal,
                    proteinPer100g: proteinValue,
                    carbsPer100g: carbsValue,
                    fatPer100g: fatValue,
                    defaultServingGrams: serving,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode,
                    isFavorite: isFavorite,
                    source: .myFood
                )
            )
        }
        try? context.save()
        dismiss()
    }
}
