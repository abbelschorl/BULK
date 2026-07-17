import SwiftUI

/// Bulk's design language: near-black base, translucent charcoal glass
/// surfaces, and a restrained accent palette. Green means a minimum is
/// reached; muted red-orange means "not yet" — never failure.
enum Theme {
    // MARK: Backgrounds

    /// Near-black, slightly warm — deliberately not pure black.
    static let background = Color(red: 0.055, green: 0.055, blue: 0.07)
    static let backgroundElevated = Color(red: 0.09, green: 0.09, blue: 0.11)
    /// Opaque card fill used when Reduce Transparency is on.
    static let opaqueCard = Color(red: 0.11, green: 0.11, blue: 0.135)

    // MARK: Accents

    /// Goal reached.
    static let goalReached = Color(red: 0.30, green: 0.85, blue: 0.45)
    /// Below minimum — warm, muted, encouraging rather than alarming.
    static let belowGoal = Color(red: 0.98, green: 0.45, blue: 0.30)
    /// Subdued secondary accent (water, links).
    static let accentBlue = Color(red: 0.35, green: 0.67, blue: 0.95)

    // MARK: Text

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.4)

    // MARK: Metrics

    static let cardCornerRadius: CGFloat = 24
    static let controlCornerRadius: CGFloat = 12

    static func goalColor(reached: Bool) -> Color {
        reached ? goalReached : belowGoal
    }
}

/// The standard Bulk surface: Liquid Glass on capable settings, an opaque
/// dark card when Reduce Transparency is enabled, and a higher-contrast
/// border when Increase Contrast is enabled.
struct BulkCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var cornerRadius: CGFloat = Theme.cardCornerRadius
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    shape.fill(Theme.opaqueCard)
                } else {
                    shape
                        .fill(Color.black.opacity(0.28))
                        .background(.ultraThinMaterial.opacity(0.9), in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(contrast == .increased ? 0.45 : 0.14),
                            .white.opacity(contrast == .increased ? 0.30 : 0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

/// Section header used across screens.
struct SectionHeader: View {
    var title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Full-screen background used behind every tab.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            // A single extremely subtle radial glow adds depth without a gradient wash.
            RadialGradient(
                colors: [Color.white.opacity(0.045), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the standard screen background and dark scheme.
    func bulkScreen() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
            .scrollContentBackground(.hidden)
    }
}
