import SwiftData
import SwiftUI

/// Barcode scanning flow: camera scan (or manual entry on simulator/denied),
/// Open Food Facts lookup, preview with grams, and a create-custom fallback.
struct BarcodeScanView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var dayKey: Date
    var initialMeal: MealType = .snack

    @Query private var allFoods: [FoodItem]

    @State private var permission = CameraPermission()
    @State private var manualCode = ""
    @State private var lookupState: LookupState = .idle
    @State private var pendingFood: PendingFood?
    @State private var notFoundBarcode: String?
    @State private var showCustomEditor = false

    enum LookupState: Equatable {
        case idle
        case looking(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                scannerArea
                manualEntry
                Spacer()
            }
            .padding(16)
            .bulkScreen()
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $pendingFood, onDismiss: { dismiss() }) { pending in
                LogFoodSheet(pending: pending, dayKey: dayKey, initialMeal: initialMeal)
            }
            .sheet(isPresented: $showCustomEditor, onDismiss: { dismiss() }) {
                CustomFoodEditor(prefillBarcode: notFoundBarcode)
            }
            .task {
                permission.refresh()
                if permission.status == .notDetermined {
                    await permission.request()
                }
            }
        }
    }

    // MARK: - Scanner / permission states

    @ViewBuilder
    private var scannerArea: some View {
        switch permission.status {
        case .authorized:
            ZStack {
                BarcodeCameraView { code in
                    handle(code: code)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))

                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)

                if case .looking(let code) = lookupState {
                    VStack(spacing: 10) {
                        SwiftUI.ProgressView()
                        Text("Looking up \(code)…")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.7)))
                }

                if let code = notFoundBarcode {
                    notFoundOverlay(code: code)
                }
            }
            .frame(height: 340)
            .accessibilityLabel("Camera viewfinder. Point at a food barcode.")

        case .denied:
            BulkCard {
                VStack(spacing: 10) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.title)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Camera access is off")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Bulk only uses the camera to read food barcodes. You can allow it in Settings, or type the barcode below instead.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentBlue)
                }
                .frame(maxWidth: .infinity)
            }

        case .notDetermined:
            BulkCard {
                VStack(spacing: 10) {
                    SwiftUI.ProgressView()
                    Text("Waiting for camera permission…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func notFoundOverlay(code: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.title)
                .foregroundStyle(Theme.textTertiary)
            Text("No product found for \(code)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            Button {
                showCustomEditor = true
            } label: {
                Label("Create custom food from this barcode", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentBlue)
            Button("Scan again") {
                notFoundBarcode = nil
                lookupState = .idle
            }
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.8)))
        .padding(12)
    }

    // MARK: - Manual entry (simulator-friendly fallback)

    private var manualEntry: some View {
        BulkCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enter barcode manually")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    TextField("e.g. 4000521006112", text: $manualCode)
                        .keyboardType(.numberPad)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlCornerRadius)
                                .fill(Color.white.opacity(0.07))
                        )
                        .accessibilityLabel("Barcode number")
                    Button("Look up") {
                        handle(code: manualCode.trimmingCharacters(in: .whitespaces))
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(manualCode.trimmingCharacters(in: .whitespaces).count < 6 || lookupState != .idle)
                    .foregroundStyle(Theme.accentBlue)
                }
                if case .looking(let code) = lookupState, permission.status != .authorized {
                    HStack(spacing: 8) {
                        SwiftUI.ProgressView()
                        Text("Looking up \(code)…")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                if let code = notFoundBarcode, permission.status != .authorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No product found for \(code).")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Button("Create custom food from this barcode") {
                            showCustomEditor = true
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentBlue)
                    }
                }
            }
        }
    }

    // MARK: - Lookup

    private func handle(code: String) {
        guard lookupState == .idle, !code.isEmpty else { return }
        notFoundBarcode = nil

        // Local barcode match wins: works offline and reflects user's edits.
        if let localFood = allFoods.first(where: { $0.barcode == code }) {
            pendingFood = PendingFood(food: localFood)
            return
        }

        lookupState = .looking(code)
        Task {
            defer { lookupState = .idle }
            do {
                let result = try await OpenFoodFactsService().product(barcode: code)
                pendingFood = PendingFood(result: result)
            } catch OpenFoodFactsService.ServiceError.productNotFound {
                notFoundBarcode = code
            } catch {
                notFoundBarcode = code
            }
        }
    }
}
