import SwiftData
import SwiftUI

/// Manage the personal food library: edit, favorite, delete. Deleting a food
/// never touches past log entries — they carry their own snapshots.
struct ManageFoodsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var editingFood: FoodItem?
    @State private var showNewFood = false

    var body: some View {
        List {
            if foods.isEmpty {
                ContentUnavailableView(
                    "No foods yet",
                    systemImage: "carrot",
                    description: Text("Foods you create or save from search appear here.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(foods) { food in
                Button {
                    editingFood = food
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name)
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(Format.kcal(food.caloriesPer100g)) kcal · \(Format.macroGrams(food.proteinPer100g)) g protein / 100 g · \(food.source.displayLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if food.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.8))
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        context.delete(food)
                        try? context.save()
                    }
                    Button(food.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star") {
                        food.isFavorite.toggle()
                        try? context.save()
                    }
                    .tint(.yellow)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("My Foods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewFood = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create custom food")
            }
        }
        .sheet(item: $editingFood) { food in
            CustomFoodEditor(editingFood: food)
        }
        .sheet(isPresented: $showNewFood) {
            CustomFoodEditor()
        }
    }
}

/// Manage saved meals: create, edit (history stays untouched), delete.
struct ManageMealsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]

    @State private var editingMeal: SavedMeal?
    @State private var showNewMeal = false

    var body: some View {
        List {
            if meals.isEmpty {
                ContentUnavailableView(
                    "No saved meals",
                    systemImage: "square.stack.3d.up",
                    description: Text("Save combinations you eat often, like “Morning oats”, and log them in one tap.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(meals) { meal in
                Button {
                    editingMeal = meal
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(meal.sortedComponents.count) foods · \(Format.kcal(meal.totals.calories)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        context.delete(meal)
                        try? context.save()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Saved Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewMeal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create saved meal")
            }
        }
        .sheet(item: $editingMeal) { meal in
            SavedMealEditor(editingMeal: meal)
        }
        .sheet(isPresented: $showNewMeal) {
            SavedMealEditor()
        }
    }
}

/// Manage supplements: add, edit, reorder, archive (keeps history), delete.
struct ManageSupplementsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.sortOrder) private var supplements: [Supplement]

    @State private var editingSupplement: Supplement?
    @State private var showNewSupplement = false

    private var active: [Supplement] { supplements.filter { !$0.isArchived } }
    private var archived: [Supplement] { supplements.filter { $0.isArchived } }

    var body: some View {
        List {
            Section {
                ForEach(active) { supplement in
                    row(for: supplement)
                }
                .onMove { source, destination in
                    var reordered = active
                    reordered.move(fromOffsets: source, toOffset: destination)
                    for (index, item) in reordered.enumerated() {
                        item.sortOrder = index
                    }
                    try? context.save()
                }
            } footer: {
                Text("Drag to reorder. Archiving hides a supplement but keeps its history.")
            }

            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { supplement in
                        row(for: supplement)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    EditButton()
                    Button {
                        showNewSupplement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add supplement")
                }
            }
        }
        .sheet(item: $editingSupplement) { supplement in
            SupplementEditor(editingSupplement: supplement)
        }
        .sheet(isPresented: $showNewSupplement) {
            SupplementEditor(nextSortOrder: (supplements.map(\.sortOrder).max() ?? -1) + 1)
        }
    }

    private func row(for supplement: Supplement) -> some View {
        Button {
            editingSupplement = supplement
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplement.name)
                        .foregroundStyle(supplement.isArchived ? .secondary : Theme.textPrimary)
                    HStack(spacing: 6) {
                        if let dose = supplement.dose, !dose.isEmpty { Text(dose) }
                        if let time = supplement.timeOfDayLabel, !time.isEmpty { Text("· \(time)") }
                        if !supplement.isActive && !supplement.isArchived { Text("· inactive") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                context.delete(supplement)
                try? context.save()
            }
            Button(supplement.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                supplement.isArchived.toggle()
                try? context.save()
            }
            .tint(.orange)
        }
    }
}

struct SupplementEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editingSupplement: Supplement?
    var nextSortOrder: Int = 0

    @State private var name = ""
    @State private var dose = ""
    @State private var timeOfDay = ""
    @State private var notes = ""
    @State private var isActive = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Supplement") {
                    TextField("Name", text: $name)
                    TextField("Dose, e.g. 5 g or 2 capsules", text: $dose)
                    TextField("Time of day, e.g. Morning", text: $timeOfDay)
                    Toggle("Active", isOn: $isActive)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(editingSupplement == nil ? "New Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard let supplement = editingSupplement else { return }
            name = supplement.name
            dose = supplement.dose ?? ""
            timeOfDay = supplement.timeOfDayLabel ?? ""
            notes = supplement.notes ?? ""
            isActive = supplement.isActive
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDose = dose.trimmingCharacters(in: .whitespaces)
        let trimmedTime = timeOfDay.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let supplement = editingSupplement {
            supplement.name = trimmedName
            supplement.dose = trimmedDose.isEmpty ? nil : trimmedDose
            supplement.timeOfDayLabel = trimmedTime.isEmpty ? nil : trimmedTime
            supplement.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            supplement.isActive = isActive
        } else {
            context.insert(
                Supplement(
                    name: trimmedName,
                    dose: trimmedDose.isEmpty ? nil : trimmedDose,
                    timeOfDayLabel: trimmedTime.isEmpty ? nil : trimmedTime,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    isActive: isActive,
                    sortOrder: nextSortOrder
                )
            )
        }
        try? context.save()
        dismiss()
    }
}
