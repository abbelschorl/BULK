import SwiftData
import SwiftUI

/// Compact supplement completion summary on Today. Tapping a pill toggles it,
/// so most days never need the Supplements tab at all.
struct SupplementSummaryCard: View {
    @Environment(\.modelContext) private var context

    var supplements: [Supplement]
    var logs: [SupplementLog]
    var dayKey: Date

    private var completedIDs: Set<PersistentIdentifier> {
        SupplementDay.completedSupplementIDs(logs: logs, dayKey: dayKey)
    }

    var body: some View {
        if supplements.isEmpty {
            EmptyView()
        } else {
            BulkCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        MiniRing(
                            fraction: SupplementDay.completionFraction(
                                activeCount: supplements.count,
                                completedCount: completedIDs.count
                            ),
                            color: Theme.goalReached
                        )
                        Text("Supplements")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(completedIDs.count)/\(supplements.count)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textTertiary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(supplements) { supplement in
                                let done = completedIDs.contains(supplement.persistentModelID)
                                Button {
                                    toggle(supplement, done: done)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text(supplement.name)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(done ? Theme.goalReached.opacity(0.18) : Color.white.opacity(0.07))
                                    )
                                    .foregroundStyle(done ? Theme.goalReached : Theme.textSecondary)
                                }
                                .accessibilityLabel("\(supplement.name), \(done ? "taken" : "not taken")")
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ supplement: Supplement, done: Bool) {
        if done {
            for log in logs where log.supplement?.persistentModelID == supplement.persistentModelID
                && Calendar.current.startOfDay(for: log.dayKey) == dayKey {
                context.delete(log)
            }
        } else {
            context.insert(SupplementLog(dayKey: dayKey, supplement: supplement))
        }
        try? context.save()
    }
}
