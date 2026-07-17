import Foundation
import SwiftData

/// Orchestrates food search across sources in the required order:
/// personal library first, then recent foods, then public databases.
/// Local results are always available offline; public search failures are
/// reported without hiding local results.
@MainActor
struct FoodSearchService {
    var openFoodFacts = OpenFoodFactsService()
    var usda = USDAService()

    struct Results {
        var local: [FoodSearchResult] = []
        var publicResults: [FoodSearchResult] = []
        /// User-facing notes about degraded public search (offline, bad key, …).
        var publicSearchNotes: [String] = []
    }

    /// Local-library and recent matches, ranked My Foods → Recent.
    static func localMatches(query: String, foods: [FoodItem]) -> [FoodSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let matches = foods.filter { food in
            food.name.localizedCaseInsensitiveContains(trimmed)
                || (food.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }

        let myFoods = matches
            .filter { $0.source == .myFood }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let recents = matches
            .filter { $0.source != .myFood && $0.lastLoggedAt != nil }
            .sorted { ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast) }

        return myFoods.map { Self.result(for: $0, origin: .myFood($0.persistentModelID)) }
            + recents.map { Self.result(for: $0, origin: .recent($0.persistentModelID)) }
    }

    static func result(for food: FoodItem, origin: FoodSearchResult.Origin) -> FoodSearchResult {
        FoodSearchResult(
            id: "local-\(food.persistentModelID.hashValue)-\(origin.label)",
            name: food.name,
            brand: food.brand,
            per100g: food.per100g,
            origin: origin,
            barcode: food.barcode,
            defaultServingGrams: food.defaultServingGrams,
            hasIncompleteNutrition: false,
            missingFields: []
        )
    }

    /// Queries both public sources, tolerating individual failures.
    func searchPublic(query: String, usdaAPIKey: String) async -> (results: [FoodSearchResult], notes: [String]) {
        var results: [FoodSearchResult] = []
        var notes: [String] = []

        async let offTask: Result<[FoodSearchResult], Error> = {
            do { return .success(try await openFoodFacts.search(query: query)) }
            catch { return .failure(error) }
        }()
        async let usdaTask: Result<[FoodSearchResult], Error> = {
            do { return .success(try await usda.search(query: query, apiKey: usdaAPIKey)) }
            catch { return .failure(error) }
        }()

        switch await usdaTask {
        case .success(let usdaResults):
            results.append(contentsOf: usdaResults)
        case .failure(let error):
            if let serviceError = error as? USDAService.ServiceError, serviceError == .missingAPIKey {
                notes.append("USDA search is off — add a free API key in Settings.")
            } else {
                notes.append(error.localizedDescription)
            }
        }

        switch await offTask {
        case .success(let offResults):
            results.append(contentsOf: offResults)
        case .failure(let error):
            notes.append("Open Food Facts: \(error.localizedDescription)")
        }

        return (results, notes)
    }
}

extension USDAService.ServiceError: Equatable {}
