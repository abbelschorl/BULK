import Foundation

/// Client for the free Open Food Facts API (barcode lookup + packaged food
/// search). No API key required. Mapping is separated from networking so the
/// decoding logic is unit-testable with fixture JSON.
struct OpenFoodFactsService {
    enum ServiceError: LocalizedError {
        case offline
        case badResponse
        case productNotFound

        var errorDescription: String? {
            switch self {
            case .offline: "You appear to be offline. Your foods and recent items still work."
            case .badResponse: "Open Food Facts returned an unexpected response. Try again in a moment."
            case .productNotFound: "No product found for this barcode."
            }
        }
    }

    var session: URLSession = .shared

    private static let userAgent = "Bulk iOS - personal bulking tracker - https://github.com/local"

    func product(barcode: String) async throws -> FoodSearchResult {
        let escaped = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(escaped)?fields=code,product_name,brands,nutriments,serving_quantity,serving_quantity_unit") else {
            throw ServiceError.badResponse
        }
        let data = try await fetch(url: url)
        let decoded: OFFProductResponse
        do {
            decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        } catch {
            throw ServiceError.badResponse
        }
        guard decoded.status == 1, let product = decoded.product,
              let result = Self.mapProduct(product) else {
            throw ServiceError.productNotFound
        }
        return result
    }

    func search(query: String, pageSize: Int = 20) async throws -> [FoodSearchResult] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/search")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,serving_quantity,serving_quantity_unit"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
        ]
        guard let url = components.url else { throw ServiceError.badResponse }
        let data = try await fetch(url: url)
        let decoded: OFFSearchResponse
        do {
            decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        } catch {
            throw ServiceError.badResponse
        }
        return Self.mapSearchResponse(decoded)
    }

    private func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw ServiceError.badResponse
            }
            return data
        } catch let error as ServiceError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost || error.code == .dataNotAllowed {
            throw ServiceError.offline
        } catch {
            throw ServiceError.badResponse
        }
    }

    // MARK: - Mapping (pure, testable)

    static func mapSearchResponse(_ response: OFFSearchResponse) -> [FoodSearchResult] {
        (response.products ?? []).compactMap(mapProduct)
    }

    static func mapProduct(_ product: OFFProduct) -> FoodSearchResult? {
        let name = (product.productName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let nutriments = product.nutriments
        var missing: [String] = []

        // OFF reports energy per 100 g in kJ under "energy_100g"; kcal is separate.
        let calories: Decimal
        if let kcal = nutriments?.energyKcal100g {
            calories = Decimal(kcal)
        } else if let kj = nutriments?.energy100g {
            calories = Decimal(kj / 4.184)
        } else {
            calories = 0
            missing.append("calories")
        }

        let protein = nutriments?.proteins100g.map { Decimal($0) }
        let carbs = nutriments?.carbohydrates100g.map { Decimal($0) }
        let fat = nutriments?.fat100g.map { Decimal($0) }
        if protein == nil { missing.append("protein") }
        if carbs == nil { missing.append("carbs") }
        if fat == nil { missing.append("fat") }

        var serving: Decimal?
        if let quantity = product.servingQuantity?.doubleValue, quantity > 0 {
            let unit = product.servingQuantityUnit?.lowercased()
            if unit == nil || unit == "g" || unit == "ml" {
                serving = Decimal(quantity)
            }
        }

        let brand = product.brands?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return FoodSearchResult(
            id: "off-\(product.code ?? UUID().uuidString)",
            name: name,
            brand: brand,
            per100g: NutritionValues(
                calories: calories.rounded(1),
                protein: protein ?? 0,
                carbs: carbs ?? 0,
                fat: fat ?? 0
            ),
            origin: .openFoodFacts,
            barcode: product.code,
            defaultServingGrams: serving,
            hasIncompleteNutrition: !missing.isEmpty,
            missingFields: missing
        )
    }
}

// MARK: - Wire types

struct OFFProductResponse: Decodable {
    var status: Int?
    var product: OFFProduct?
}

struct OFFSearchResponse: Decodable {
    var products: [OFFProduct]?
}

struct OFFProduct: Decodable {
    var code: String?
    var productName: String?
    var brands: String?
    var nutriments: OFFNutriments?
    var servingQuantity: StringOrDouble?
    var servingQuantityUnit: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
    }
}

struct OFFNutriments: Decodable {
    var energyKcal100g: Double?
    var energy100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energy100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}

/// OFF sometimes returns numbers as strings ("30") and sometimes as numbers (30).
struct StringOrDouble: Decodable, Equatable {
    var doubleValue: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            doubleValue = double
        } else if let string = try? container.decode(String.self) {
            doubleValue = Double(string)
        } else {
            doubleValue = nil
        }
    }
}
