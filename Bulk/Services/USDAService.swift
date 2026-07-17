import Foundation

/// Client for USDA FoodData Central search — best for raw/cooked ingredients
/// like "chicken breast, cooked" or "rice, dry". Requires the user's own free
/// API key, entered in Settings and stored only on-device.
struct USDAService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidAPIKey
        case offline
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Add your free USDA FoodData Central API key in Settings to search ingredients."
            case .invalidAPIKey: "USDA rejected the API key. Check it in Settings."
            case .offline: "You appear to be offline. Your foods and recent items still work."
            case .badResponse: "USDA returned an unexpected response. Try again in a moment."
            }
        }
    }

    var session: URLSession = .shared

    func search(query: String, apiKey: String, pageSize: Int = 15) async throws -> [FoodSearchResult] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
        ]
        guard let url = components.url else { throw ServiceError.badResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 || http.statusCode == 403 { throw ServiceError.invalidAPIKey }
                guard (200...299).contains(http.statusCode) else { throw ServiceError.badResponse }
            }
            data = body
        } catch let error as ServiceError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost || error.code == .dataNotAllowed {
            throw ServiceError.offline
        } catch {
            throw ServiceError.badResponse
        }

        let decoded: USDASearchResponse
        do {
            decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        } catch {
            throw ServiceError.badResponse
        }
        return Self.mapSearchResponse(decoded)
    }

    // MARK: - Mapping (pure, testable)

    static func mapSearchResponse(_ response: USDASearchResponse) -> [FoodSearchResult] {
        (response.foods ?? []).compactMap(mapFood)
    }

    static func mapFood(_ food: USDAFood) -> FoodSearchResult? {
        let name = (food.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let fdcId = food.fdcId else { return nil }

        // Foundation / SR Legacy nutrient values are per 100 g.
        func nutrient(_ numbers: Set<String>, unit: String? = nil) -> Double? {
            food.foodNutrients?.first { item in
                guard let number = item.nutrientNumber ?? item.nutrient?.number else { return false }
                guard numbers.contains(number) else { return false }
                if let unit, let itemUnit = item.unitName ?? item.nutrient?.unitName {
                    return itemUnit.caseInsensitiveCompare(unit) == .orderedSame
                }
                return true
            }?.resolvedValue
        }

        var missing: [String] = []
        // 208 = Energy (kcal); 957 = Atwater specific energy used by Foundation foods.
        let calories = nutrient(["208", "957", "1008", "2047", "2048"], unit: "kcal")
        let protein = nutrient(["203", "1003"])
        let carbs = nutrient(["205", "1005"])
        let fat = nutrient(["204", "1004"])
        if calories == nil { missing.append("calories") }
        if protein == nil { missing.append("protein") }
        if carbs == nil { missing.append("carbs") }
        if fat == nil { missing.append("fat") }

        return FoodSearchResult(
            id: "usda-\(fdcId)",
            name: name,
            brand: food.brandOwner,
            per100g: NutritionValues(
                calories: Decimal(calories ?? 0).rounded(1),
                protein: Decimal(protein ?? 0).rounded(2),
                carbs: Decimal(carbs ?? 0).rounded(2),
                fat: Decimal(fat ?? 0).rounded(2)
            ),
            origin: .usda,
            barcode: nil,
            defaultServingGrams: nil,
            hasIncompleteNutrition: !missing.isEmpty,
            missingFields: missing
        )
    }
}

// MARK: - Wire types

struct USDASearchResponse: Decodable {
    var foods: [USDAFood]?
}

struct USDAFood: Decodable {
    var fdcId: Int?
    var description: String?
    var brandOwner: String?
    var foodNutrients: [USDAFoodNutrient]?
}

struct USDAFoodNutrient: Decodable {
    var nutrientNumber: String?
    var unitName: String?
    var value: Double?
    var amount: Double?
    var nutrient: USDANutrientDetail?

    var resolvedValue: Double? { value ?? amount }
}

struct USDANutrientDetail: Decodable {
    var number: String?
    var unitName: String?
}
