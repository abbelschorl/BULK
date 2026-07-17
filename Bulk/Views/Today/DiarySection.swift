import SwiftUI

/// The food diary grouped by meal, with per-meal calorie/protein totals and
/// swipe-free edit/delete controls (context menu + buttons stay discoverable).
struct DiarySection: View {
    var entries: [LogEntry]
    var onAdd: (MealType) -> Void
    var onEdit: (LogEntry) -> Void
    var onDelete: (LogEntry) -> Void

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Diary", systemImage: "book.closed")

            if entries.isEmpty {
                BulkCard {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(Theme.textTertiary)
                        Text("Nothing logged yet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Add your first food to start filling today's goals.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(MealType.allCases) { meal in
                    let mealEntries = entries
                        .filter { $0.mealType == meal }
                        .sorted { $0.loggedAt < $1.loggedAt }
                    if !mealEntries.isEmpty {
                        MealGroupCard(
                            meal: meal,
                            entries: mealEntries,
                            onAdd: { onAdd(meal) },
                            onEdit: onEdit,
                            onDelete: onDelete
                        )
                    }
                }
            }
        }
    }
}

struct MealGroupCard: View {
    var meal: MealType
    var entries: [LogEntry]
    var onAdd: () -> Void
    var onEdit: (LogEntry) -> Void
    var onDelete: (LogEntry) -> Void

    @State private var expanded = true

    private var totals: NutritionValues {
        NutritionCalculator.dayTotals(entries: entries)
    }

    var body: some View {
        BulkCard(padding: 14) {
            VStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: meal.symbolName)
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 18)
                        Text(meal.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Format.kcal(totals.calories)) kcal · \(Format.macroGrams(totals.protein)) g protein")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textTertiary)
                            .rotationEffect(.degrees(expanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(meal.displayName): \(Format.kcal(totals.calories)) calories, \(Format.macroGrams(totals.protein)) grams protein. \(expanded ? "Expanded" : "Collapsed")")

                if expanded {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            DiaryRow(entry: entry, onEdit: { onEdit(entry) }, onDelete: { onDelete(entry) })
                            if entry.persistentModelID != entries.last?.persistentModelID {
                                Divider().overlay(Color.white.opacity(0.06))
                            }
                        }
                    }

                    Button(action: onAdd) {
                        Label("Add to \(meal.displayName)", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accentBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            }
        }
    }
}

struct DiaryRow: View {
    var entry: LogEntry
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.foodName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(Format.portionGrams(entry.grams)) · \(Format.macroGrams(entry.totals.protein)) g protein")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Text("\(Format.kcal(entry.totals.calories)) kcal")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(entry.foodName), \(Format.portionGrams(entry.grams)), \(Format.kcal(entry.totals.calories)) calories. Double tap to edit.")
    }
}
