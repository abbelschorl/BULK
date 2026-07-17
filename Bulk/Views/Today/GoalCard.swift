import SwiftUI

/// Large minimum-goal card for calories or protein. Red-orange while below
/// the minimum, green once reached — no upper range, ever.
struct GoalCard: View {
    var title: String
    var unit: String
    var consumed: Decimal
    var minimum: Decimal
    var remainingText: (Decimal) -> String
    var reachedText: String
    var valueText: String

    private var state: GoalState {
        GoalState.evaluate(consumed: consumed, minimum: minimum)
    }

    private var color: Color {
        Theme.goalColor(reached: state.isReached)
    }

    var body: some View {
        BulkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if state.isReached {
                        Label(reachedText, systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.goalReached)
                    } else {
                        Text(remainingText(state.remaining))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.belowGoal)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(valueText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.headline)
                        .foregroundStyle(Theme.textTertiary)
                }

                GoalProgressBar(
                    fraction: GoalState.progressFraction(consumed: consumed, minimum: minimum),
                    color: color
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let status = state.isReached
            ? reachedText
            : remainingText(state.remaining)
        return "\(title): \(valueText) \(unit). \(status)"
    }
}
