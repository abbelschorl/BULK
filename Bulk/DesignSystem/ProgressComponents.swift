import SwiftUI

/// Slim rounded progress bar used in the calorie/protein goal cards.
struct GoalProgressBar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geometry.size.width * fraction))
                    .animation(.spring(duration: 0.5), value: fraction)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Compact circular progress ring (water, supplements).
struct MiniRing: View {
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat = 4
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: fraction)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Quick-select gram chips (50–300 g) for fast portion entry.
struct GramChips: View {
    @Binding var grams: Decimal
    var options: [Int] = [50, 100, 150, 200, 250, 300]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = grams == Decimal(option)
                Button {
                    grams = Decimal(option)
                } label: {
                    Text("\(option)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.07))
                        )
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option) grams")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A labeled macro value used in the neutral carbs/fat row.
struct MacroStat: View {
    var label: String
    var value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
