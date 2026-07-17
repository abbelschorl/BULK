import SwiftData
import SwiftUI

/// The logging sheet: pick grams (fast), pick a meal, see live totals, add.
/// Also lets the user edit an existing entry (same UI, prefilled).
struct LogFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pending: PendingFood
    var dayKey: Date
    var initialMeal: MealType = .snack
    /// When set, the sheet edits this existing entry instead of adding.
    var editingEntry: LogEntry?

    @State private var grams: Decimal = 100
    @State private var gramsText: String = "100"
    @State private var meal: MealType = .snack
    @State private var savedToLibrary = false
    @FocusState private var gramsFocused: Bool

    private var totals: NutritionValues {
        NutritionCalculator.scale(per100g: pending.per100g, grams: grams)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if pending.hasIncompleteNutrition {
                        incompleteWarning
                    }

                    BulkCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Amount")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)

                            HStack(spacing: 10) {
                                TextField("Grams", text: $gramsText)
                                    .keyboardType(.decimalPad)
                                    .focused($gramsFocused)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: 140)
                                    .onChange(of: gramsText) { _, newValue in
                                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                                        if let value = Decimal(string: normalized), value >= 0 {
                                            grams = value
                                        }
                                    }
                                    .accessibilityLabel("Gram amount")
                                Text("g")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }

                            GramChips(grams: $grams)
                                .onChange(of: grams) { _, newValue in
                                    let asText = newValue.doubleValue.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
                                    if Decimal(string: gramsText.replacingOccurrences(of: ",", with: ".")) != newValue {
                                        gramsText = asText
                                    }
                                }
                        }
                    }

                    BulkCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Meal")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Picker("Meal", selection: $meal) {
                                ForEach(MealType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    BulkCard {
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(Format.kcal(totals.calories))
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textPrimary)
                                Text("kcal")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }
                            HStack {
                                MacroStat(label: "Protein", value: "\(Format.macroGrams(totals.protein)) g")
                                MacroStat(label: "Carbs", value: "\(Format.macroGrams(totals.carbs)) g")
                                MacroStat(label: "Fat", value: "\(Format.macroGrams(totals.fat)) g")
                            }
                        }
                    }

                    if pending.isPublicResult && editingEntry == nil {
                        Button {
                            FoodLogger.saveToLibrary(pending, context: context, favorite: false)
                            savedToLibrary = true
                        } label: {
                            Label(
                                savedToLibrary ? "Saved to My Foods" : "Save to My Foods",
                                systemImage: savedToLibrary ? "checkmark" : "plus.square.on.square"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                        .disabled(savedToLibrary)
                        .foregroundStyle(Theme.accentBlue)
                    }
                }
                .padding(16)
            }
            .bulkScreen()
            .navigationTitle(editingEntry == nil ? "Log Food" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingEntry == nil ? "Add" : "Save") { commit() }
                        .font(.body.weight(.semibold))
                        .disabled(grams <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { gramsFocused = false }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: prefill)
    }

    private var header: some View {
        BulkCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(pending.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    if let brand = pending.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    SourceBadge(label: pending.sourceLabel)
                }
                Text("Per 100 g: \(Format.kcal(pending.per100g.calories)) kcal · \(Format.macroGrams(pending.per100g.protein)) g protein")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var incompleteWarning: some View {
        BulkCard(padding: 14) {
            Label {
                Text("Incomplete data: missing \(pending.missingFields.joined(separator: ", ")). Values shown may understate what you're eating.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.belowGoal)
            }
        }
    }

    private func prefill() {
        if let entry = editingEntry {
            grams = entry.grams
            meal = entry.mealType
        } else {
            grams = pending.defaultServingGrams ?? 100
            meal = initialMeal
        }
        gramsText = grams.doubleValue.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    private func commit() {
        if let entry = editingEntry {
            entry.grams = grams
            entry.mealType = meal
            try? context.save()
        } else {
            FoodLogger.log(pending, grams: grams, meal: meal, dayKey: dayKey, context: context)
        }
        dismiss()
    }
}

/// Small pill identifying where a food's data came from.
struct SourceBadge: View {
    var label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .foregroundStyle(Theme.textSecondary)
    }
}
