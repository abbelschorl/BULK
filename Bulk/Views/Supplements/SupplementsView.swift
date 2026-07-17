import SwiftData
import SwiftUI

/// Daily supplement checklist. Simple and satisfying: tap to check off,
/// completion ring up top, management lives in Settings.
struct SupplementsView: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<Supplement> { $0.isActive && !$0.isArchived },
        sort: \Supplement.sortOrder
    ) private var activeSupplements: [Supplement]
    @Query private var logs: [SupplementLog]

    private var today: Date { DayKey.today() }

    private var completedIDs: Set<PersistentIdentifier> {
        SupplementDay.completedSupplementIDs(logs: logs, dayKey: today)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if activeSupplements.isEmpty {
                        emptyState
                    } else {
                        completionCard
                        checklist
                    }
                    Spacer(minLength: 30)
                }
                .padding(16)
            }
            .bulkScreen()
            .navigationTitle("Supplements")
        }
    }

    private var emptyState: some View {
        BulkCard {
            VStack(spacing: 10) {
                Image(systemName: "pills")
                    .font(.title)
                    .foregroundStyle(Theme.textTertiary)
                Text("No active supplements")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Add or re-activate supplements in Settings → Supplements.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private var completionCard: some View {
        let fraction = SupplementDay.completionFraction(
            activeCount: activeSupplements.count,
            completedCount: completedIDs.count
        )
        let allDone = completedIDs.count == activeSupplements.count && !activeSupplements.isEmpty
        return BulkCard {
            HStack(spacing: 16) {
                MiniRing(
                    fraction: fraction,
                    color: allDone ? Theme.goalReached : Theme.textSecondary,
                    lineWidth: 6,
                    size: 54
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(allDone ? "All done for today" : "\(completedIDs.count) of \(activeSupplements.count) taken")
                        .font(.headline)
                        .foregroundStyle(allDone ? Theme.goalReached : Theme.textPrimary)
                    Text("\(Int((fraction * 100).rounded()))% complete")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(completedIDs.count) of \(activeSupplements.count) supplements taken today")
    }

    private var checklist: some View {
        BulkCard(padding: 8) {
            VStack(spacing: 0) {
                ForEach(activeSupplements) { supplement in
                    let done = completedIDs.contains(supplement.persistentModelID)
                    Button {
                        withAnimation(.snappy) { toggle(supplement, done: done) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done ? Theme.goalReached : Theme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(supplement.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Theme.textPrimary)
                                    .strikethrough(done, color: Theme.textTertiary)
                                HStack(spacing: 6) {
                                    if let dose = supplement.dose, !dose.isEmpty {
                                        Text(dose)
                                    }
                                    if let time = supplement.timeOfDayLabel, !time.isEmpty {
                                        Text("· \(time)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(supplement.name)\(supplement.dose.map { ", \($0)" } ?? ""), \(done ? "taken" : "not taken"). Double tap to toggle.")

                    if supplement.persistentModelID != activeSupplements.last?.persistentModelID {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
    }

    private func toggle(_ supplement: Supplement, done: Bool) {
        if done {
            for log in logs where log.supplement?.persistentModelID == supplement.persistentModelID
                && Calendar.current.startOfDay(for: log.dayKey) == today {
                context.delete(log)
            }
        } else {
            context.insert(SupplementLog(dayKey: today, supplement: supplement))
        }
        try? context.save()
    }
}
