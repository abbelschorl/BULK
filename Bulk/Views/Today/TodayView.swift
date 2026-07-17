import SwiftData
import SwiftUI

/// Home screen: answers "have I eaten enough today?" at a glance.
struct TodayView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: \LogEntry.loggedAt) private var allEntries: [LogEntry]
    @Query(sort: \WaterEntry.date) private var allWater: [WaterEntry]
    @Query(
        filter: #Predicate<Supplement> { $0.isActive && !$0.isArchived },
        sort: \Supplement.sortOrder
    ) private var activeSupplements: [Supplement]
    @Query private var supplementLogs: [SupplementLog]

    @State private var selectedDay = DayKey.today()
    @State private var showAddFood = false
    @State private var addFoodMeal: MealType = .breakfast
    @State private var editingEntry: LogEntry?
    @State private var showWeighIn = false

    private var dayEntries: [LogEntry] {
        allEntries.filter { $0.dayKey == selectedDay }
    }

    private var totals: NutritionValues {
        NutritionCalculator.dayTotals(entries: dayEntries)
    }

    private var dayWaterML: Double {
        WaterMath.totalML(entries: allWater.filter { $0.dayKey == selectedDay })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 14) {
                        dayHeader

                        GoalCard(
                            title: "Calories",
                            unit: "kcal",
                            consumed: totals.calories,
                            minimum: settings.calorieMinimumDecimal,
                            remainingText: { "\(Format.kcal($0)) kcal remaining" },
                            reachedText: "Calorie goal reached",
                            valueText: "\(Format.kcal(totals.calories)) / \(settings.calorieMinimum)"
                        )

                        GoalCard(
                            title: "Protein",
                            unit: "g",
                            consumed: totals.protein,
                            minimum: settings.proteinMinimumDecimal,
                            remainingText: { "\(Format.macroGrams($0)) g remaining" },
                            reachedText: "Protein goal reached",
                            valueText: "\(Format.macroGrams(totals.protein)) / \(settings.proteinMinimum) g"
                        )

                        BulkCard(padding: 14) {
                            HStack {
                                MacroStat(label: "Carbs", value: "\(Format.macroGrams(totals.carbs)) g")
                                Divider().frame(height: 28).overlay(Color.white.opacity(0.1))
                                MacroStat(label: "Fat", value: "\(Format.macroGrams(totals.fat)) g")
                            }
                        }

                        WaterStrip(dayKey: selectedDay, totalML: dayWaterML)

                        SupplementSummaryCard(
                            supplements: activeSupplements,
                            logs: supplementLogs,
                            dayKey: selectedDay
                        )

                        DiarySection(
                            entries: dayEntries,
                            onAdd: { meal in
                                addFoodMeal = meal
                                showAddFood = true
                            },
                            onEdit: { editingEntry = $0 },
                            onDelete: { entry in
                                context.delete(entry)
                                try? context.save()
                            }
                        )

                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 16)
                }
                addFoodButton
            }
            .bulkScreen()
            .navigationTitle("Bulk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWeighIn = true
                    } label: {
                        Image(systemName: "scalemass")
                    }
                    .accessibilityLabel("Add weigh-in")
                }
            }
            .sheet(isPresented: $showAddFood) {
                FoodCatalogSheet(dayKey: selectedDay, initialMeal: addFoodMeal)
            }
            .sheet(item: $editingEntry) { entry in
                LogFoodSheet(
                    pending: PendingFood(entry: entry),
                    dayKey: entry.dayKey,
                    editingEntry: entry
                )
            }
            .sheet(isPresented: $showWeighIn) {
                AddWeightSheet()
            }
        }
    }

    private var dayHeader: some View {
        HStack {
            Button {
                withAnimation { selectedDay = DayKey.shifted(selectedDay, by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 1) {
                Text(DayKey.displayName(for: selectedDay))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if !DayKey.isToday(selectedDay) {
                    Button("Back to today") {
                        withAnimation { selectedDay = DayKey.today() }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.accentBlue)
                } else {
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()

            Button {
                withAnimation { selectedDay = DayKey.shifted(selectedDay, by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next day")
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.top, 4)
    }

    private var addFoodButton: some View {
        Button {
            addFoodMeal = suggestedMeal()
            showAddFood = true
        } label: {
            Label("Add Food", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.white.opacity(0.16))
        .foregroundStyle(Theme.textPrimary)
        .padding(.bottom, 8)
        .accessibilityLabel("Add food to \(DayKey.displayName(for: selectedDay))")
    }

    /// Picks a sensible default meal from the current time of day.
    private func suggestedMeal() -> MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

extension PendingFood {
    /// Builds a pending food from an existing log entry (for editing).
    init(entry: LogEntry) {
        self.init(
            name: entry.foodName,
            brand: entry.foodBrand,
            per100g: entry.per100g,
            sourceLabel: entry.sourceLabel
        )
    }

    init(name: String, brand: String?, per100g: NutritionValues, sourceLabel: String) {
        self.name = name
        self.brand = brand
        self.per100g = per100g
        self.sourceLabel = sourceLabel
        self.defaultServingGrams = nil
        self.barcode = nil
    }
}
