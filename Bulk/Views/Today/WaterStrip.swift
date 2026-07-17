import SwiftData
import SwiftUI

/// Deliberately understated water tracker: one compact row with quick-adds.
struct WaterStrip: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    var dayKey: Date
    var totalML: Double

    @State private var showCustomAmount = false
    @State private var customAmountText = ""

    var body: some View {
        BulkCard(padding: 14) {
            HStack(spacing: 12) {
                MiniRing(
                    fraction: WaterMath.progressFraction(totalML: totalML, goalML: settings.waterGoalML),
                    color: Theme.accentBlue
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(WaterMath.displayString(ml: totalML, unit: settings.waterUnit)) of \(WaterMath.displayString(ml: settings.waterGoalML, unit: settings.waterUnit))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                quickAddButton(ml: 250)
                quickAddButton(ml: 500)
                Button {
                    showCustomAmount = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Add custom water amount")
            }
        }
        .accessibilityElement(children: .contain)
        .alert("Add Water", isPresented: $showCustomAmount) {
            TextField("Amount in \(settings.waterUnit.displayName)", text: $customAmountText)
                .keyboardType(.decimalPad)
            Button("Add") {
                let normalized = customAmountText.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value > 0 {
                    add(ml: settings.waterUnit.toMilliliters(value))
                }
                customAmountText = ""
            }
            Button("Cancel", role: .cancel) { customAmountText = "" }
        }
    }

    private func quickAddButton(ml: Double) -> some View {
        let label = settings.waterUnit == .milliliters
            ? "+\(Int(ml))"
            : "+\(Int(settings.waterUnit.fromMilliliters(ml).rounded())) oz"
        return Button {
            add(ml: ml)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .foregroundStyle(Theme.accentBlue)
        }
        .accessibilityLabel("Add \(WaterMath.displayString(ml: ml, unit: settings.waterUnit)) of water")
    }

    private func add(ml: Double) {
        context.insert(WaterEntry(dayKey: dayKey, amountML: ml))
        try? context.save()
    }
}
