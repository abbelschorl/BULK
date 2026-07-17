import AVFoundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HealthKitService.self) private var healthKit
    @Environment(\.modelContext) private var context

    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importCandidate: ExportImportService.Backup?
    @State private var statusMessage: String?

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                nutritionGoalsSection(settings: settings)
                unitsSection(settings: settings)
                foodAndDataSection
                supplementsSection
                integrationsSection(settings: settings)
                appearanceSection(settings: settings)
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Bulk-backup-\(Date().formatted(.iso8601.year().month().day()))"
            ) { result in
                if case .success = result {
                    statusMessage = "Backup exported."
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Replace all data?", isPresented: Binding(
                get: { importCandidate != nil },
                set: { if !$0 { importCandidate = nil } }
            )) {
                Button("Cancel", role: .cancel) { importCandidate = nil }
                Button("Import & Replace", role: .destructive) {
                    if let backup = importCandidate {
                        try? ExportImportService.restore(backup, context: context, settings: settings)
                        statusMessage = "Backup imported."
                    }
                    importCandidate = nil
                }
            } message: {
                Text("Importing a backup replaces everything currently in Bulk with the backup's contents.")
            }
            .alert("Delete all data?", isPresented: $showDeleteConfirmation) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) { deleteConfirmationText = "" }
                Button("Delete Everything", role: .destructive) {
                    if deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" {
                        try? ExportImportService.deleteAllData(context: context)
                        statusMessage = "All data deleted."
                    }
                    deleteConfirmationText = ""
                }
            } message: {
                Text("This permanently erases every food, log entry, meal, weigh-in, water entry, and supplement on this device. There is no undo. Type DELETE to confirm.")
            }
            .alert(statusMessage ?? "", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK") { statusMessage = nil }
            }
        }
    }

    // MARK: - Sections

    private func nutritionGoalsSection(settings: Bindable<AppSettings>) -> some View {
        Section {
            Stepper(value: settings.calorieMinimum, in: 1000...8000, step: 50) {
                LabeledContent("Calorie minimum", value: "\(settings.wrappedValue.calorieMinimum) kcal")
            }
            Stepper(value: settings.proteinMinimum, in: 40...400, step: 5) {
                LabeledContent("Protein minimum", value: "\(settings.wrappedValue.proteinMinimum) g")
            }
            Stepper(
                value: settings.desiredWeeklyGainKg,
                in: 0...1,
                step: 0.05
            ) {
                LabeledContent(
                    "Desired weekly gain",
                    value: Format.weeklyRate(kgPerWeek: settings.wrappedValue.desiredWeeklyGainKg, unit: settings.wrappedValue.weightUnit)
                )
            }
        } header: {
            Text("Nutrition Goals")
        } footer: {
            Text("Both goals are minimums. Progress shows red until you reach them, then green. There is no upper limit or warning range.")
        }
    }

    private func unitsSection(settings: Bindable<AppSettings>) -> some View {
        Section("Units & Water") {
            Picker("Weight unit", selection: settings.weightUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            Picker("Water unit", selection: settings.waterUnit) {
                ForEach(WaterUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            Stepper(value: settings.waterGoalML, in: 500...8000, step: 250) {
                LabeledContent(
                    "Daily water goal",
                    value: WaterMath.displayString(ml: settings.wrappedValue.waterGoalML, unit: settings.wrappedValue.waterUnit)
                )
            }
        }
    }

    private var foodAndDataSection: some View {
        Section {
            NavigationLink("Manage custom foods") { ManageFoodsView() }
            NavigationLink("Manage saved meals") { ManageMealsView() }
            NavigationLink("USDA API key") { USDAKeyView() }
            Button("Export backup (JSON)") { exportBackup() }
            Button("Import backup") { showImporter = true }
            Button("Delete all data", role: .destructive) { showDeleteConfirmation = true }
        } header: {
            Text("Food & Data")
        } footer: {
            Text("Everything Bulk stores lives on this iPhone. Food search uses Open Food Facts (openfoodfacts.org, ODbL) and USDA FoodData Central (public domain); only your search text or a barcode is sent to them, never your diary. Public data can be incomplete or out of date — check labels for foods you eat often.")
        }
    }

    private var supplementsSection: some View {
        Section("Supplements") {
            NavigationLink("Manage supplements") { ManageSupplementsView() }
        }
    }

    private func integrationsSection(settings: Bindable<AppSettings>) -> some View {
        Section {
            Toggle("Sync weight with Apple Health", isOn: Binding(
                get: { settings.wrappedValue.healthKitSyncEnabled },
                set: { enabled in
                    if enabled {
                        Task {
                            let granted = await healthKit.requestAuthorization()
                            settings.wrappedValue.healthKitSyncEnabled = granted
                            if granted {
                                let existing = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
                                let imported = await healthKit.importNewWeights(into: context, existing: existing)
                                try? context.save()
                                if imported > 0 {
                                    statusMessage = "Imported \(imported) weigh-in\(imported == 1 ? "" : "s") from Apple Health."
                                }
                            }
                        }
                    } else {
                        settings.wrappedValue.healthKitSyncEnabled = false
                    }
                }
            ))
            .disabled(!healthKit.isAvailable)

            LabeledContent("Health access", value: healthAccessDescription)
            LabeledContent("Camera access", value: cameraAccessDescription)
        } header: {
            Text("Integrations")
        } footer: {
            Text("Weight sync writes your weigh-ins to Apple Health and imports weigh-ins from other apps. Camera is used only for barcode scanning. Both are optional — Bulk works fully without them.")
        }
    }

    private func appearanceSection(settings: Bindable<AppSettings>) -> some View {
        Section {
            Toggle("Follow system appearance", isOn: settings.followSystemAppearance)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Bulk is designed dark-first. Leave this off for the intended look.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        } footer: {
            Text("Bulk is private by design: no accounts, no analytics, no cloud. Food data © Open Food Facts contributors (ODbL) and USDA FoodData Central.")
        }
    }

    // MARK: - Helpers

    private var healthAccessDescription: String {
        if !healthKit.isAvailable { return "Unavailable" }
        if !settings.healthKitSyncEnabled { return "Off" }
        return healthKit.canWrite ? "Granted" : "Check Health app"
    }

    private var cameraAccessDescription: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: "Granted"
        case .notDetermined: "Not requested yet"
        default: "Denied — enable in iOS Settings"
        }
    }

    private func exportBackup() {
        do {
            let data = try ExportImportService.exportData(context: context, settings: settings)
            exportDocument = BackupDocument(data: data)
            showExporter = true
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            importCandidate = try ExportImportService.decodeBackup(from: data)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

/// FileDocument wrapper for the JSON backup.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// USDA FoodData Central API-key entry with plain-language setup steps.
struct USDAKeyView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("API key", text: $settings.usdaAPIKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body.monospaced())
            } header: {
                Text("USDA FoodData Central")
            } footer: {
                Text("""
                USDA search finds raw and cooked ingredients like "chicken breast, cooked" or "rice, dry". It needs a free API key:

                1. Open api.data.gov/signup
                2. Enter your name and email — the key arrives by email
                3. Paste it here

                The key is stored only on this iPhone. Without it, Open Food Facts search and everything local still work.
                """)
            }
            if !settings.usdaAPIKey.isEmpty {
                Section {
                    Button("Remove key", role: .destructive) {
                        settings.usdaAPIKey = ""
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("USDA API Key")
        .navigationBarTitleDisplayMode(.inline)
    }
}
