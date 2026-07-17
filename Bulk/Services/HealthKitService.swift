import Foundation
import HealthKit
import SwiftData

/// Optional Apple Health integration for body mass. Fully isolated: the app's
/// local weight tracking never depends on this. Permission is requested only
/// when the user turns on "Sync weight with Apple Health" in Settings.
@MainActor
@Observable
final class HealthKitService {
    enum AuthState {
        case unavailable
        case notRequested
        case requested
    }

    private let store = HKHealthStore()
    private let bodyMassType = HKQuantityType(.bodyMass)

    var authState: AuthState = .notRequested
    var lastError: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init() {
        if !HKHealthStore.isHealthDataAvailable() {
            authState = .unavailable
        }
    }

    /// Requests read+write for body mass. HealthKit intentionally hides read
    /// grant status, so we only track that the prompt has been shown.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [bodyMassType], read: [bodyMassType])
            authState = .requested
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    var canWrite: Bool {
        isAvailable && store.authorizationStatus(for: bodyMassType) == .sharingAuthorized
    }

    /// Writes a weigh-in to Health and returns the sample UUID for dedup.
    func saveWeight(kg: Double, date: Date) async -> String? {
        guard canWrite else { return nil }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
        do {
            try await store.save(sample)
            return sample.uuid.uuidString
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Reads recent body-mass samples from Health (excluding ones this app wrote).
    func fetchWeights(since: Date) async -> [(uuid: String, date: Date, kg: Double)] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: predicate,
                limit: 500,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let ownBundleID = Bundle.main.bundleIdentifier ?? ""
                let mapped = (samples as? [HKQuantitySample] ?? [])
                    .filter { $0.sourceRevision.source.bundleIdentifier != ownBundleID }
                    .map { sample in
                        (
                            uuid: sample.uuid.uuidString,
                            date: sample.startDate,
                            kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        )
                    }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    /// Imports Health samples that aren't in the local store yet.
    func importNewWeights(into context: ModelContext, existing: [WeightEntry]) async -> Int {
        let since = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let samples = await fetchWeights(since: since)
        let knownUUIDs = Set(existing.compactMap(\.healthKitUUID))
        var imported = 0
        for sample in samples where !knownUUIDs.contains(sample.uuid) {
            context.insert(WeightEntry(date: sample.date, weightKg: sample.kg, healthKitUUID: sample.uuid))
            imported += 1
        }
        return imported
    }
}
