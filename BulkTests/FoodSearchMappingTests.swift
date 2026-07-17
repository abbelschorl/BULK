import Foundation
import SwiftData
import Testing
@testable import Bulk

@Suite("Open Food Facts mapping")
struct OFFMappingTests {
    private let productJSON = """
    {
      "status": 1,
      "product": {
        "code": "4000521006112",
        "product_name": "Haferflocken Kernig",
        "brands": "Kölln, Some Other Brand",
        "serving_quantity": "40",
        "serving_quantity_unit": "g",
        "nutriments": {
          "energy-kcal_100g": 372,
          "energy_100g": 1577,
          "proteins_100g": 13.5,
          "carbohydrates_100g": 58.7,
          "fat_100g": 7.0
        }
      }
    }
    """

    @Test("Maps a complete product with string serving quantity")
    func completeProduct() throws {
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(productJSON.utf8))
        let result = try #require(OpenFoodFactsService.mapProduct(try #require(response.product)))
        #expect(result.name == "Haferflocken Kernig")
        #expect(result.brand == "Kölln")
        #expect(result.barcode == "4000521006112")
        #expect(result.per100g.calories == 372)
        #expect(result.per100g.protein == Decimal(string: "13.5"))
        #expect(result.defaultServingGrams == 40)
        #expect(result.origin == .openFoodFacts)
        #expect(!result.hasIncompleteNutrition)
    }

    @Test("Falls back from kJ when kcal is missing and flags missing macros")
    func incompleteProduct() throws {
        let json = """
        {
          "products": [
            { "code": "123", "product_name": "Mystery Snack",
              "nutriments": { "energy_100g": 2092 } },
            { "code": "456", "product_name": "" }
          ]
        }
        """
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: Data(json.utf8))
        let results = OpenFoodFactsService.mapSearchResponse(response)
        // Nameless product is dropped entirely.
        #expect(results.count == 1)
        let snack = results[0]
        // 2092 kJ ≈ 500 kcal.
        #expect(abs(snack.per100g.calories.doubleValue - 500) < 0.1)
        #expect(snack.hasIncompleteNutrition)
        #expect(snack.missingFields.contains("protein"))
        #expect(snack.missingFields.contains("carbs"))
        #expect(snack.missingFields.contains("fat"))
        #expect(!snack.missingFields.contains("calories"))
    }

    @Test("Numeric serving quantity also decodes")
    func numericServing() throws {
        let json = """
        { "status": 1, "product": { "code": "1", "product_name": "Bar",
          "serving_quantity": 45.5,
          "nutriments": { "energy-kcal_100g": 400, "proteins_100g": 30, "carbohydrates_100g": 40, "fat_100g": 10 } } }
        """
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(json.utf8))
        let result = try #require(OpenFoodFactsService.mapProduct(try #require(response.product)))
        #expect(result.defaultServingGrams == Decimal(string: "45.5"))
    }
}

@Suite("USDA mapping")
struct USDAMappingTests {
    private let searchJSON = """
    {
      "foods": [
        {
          "fdcId": 171077,
          "description": "Chicken, broilers or fryers, breast, meat only, cooked, roasted",
          "foodNutrients": [
            { "nutrientNumber": "208", "unitName": "KCAL", "value": 165.0 },
            { "nutrientNumber": "203", "unitName": "G", "value": 31.02 },
            { "nutrientNumber": "205", "unitName": "G", "value": 0.0 },
            { "nutrientNumber": "204", "unitName": "G", "value": 3.57 }
          ]
        },
        {
          "fdcId": 999999,
          "description": "Incomplete Food",
          "foodNutrients": [
            { "nutrientNumber": "203", "unitName": "G", "value": 20.0 }
          ]
        },
        { "fdcId": 111, "description": "   " }
      ]
    }
    """

    @Test("Maps cooked chicken breast per 100 g")
    func chickenBreast() throws {
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: Data(searchJSON.utf8))
        let results = USDAService.mapSearchResponse(response)
        #expect(results.count == 2) // blank-name food dropped

        let chicken = results[0]
        #expect(chicken.name.hasPrefix("Chicken"))
        #expect(chicken.per100g.calories == 165)
        #expect(chicken.per100g.protein == Decimal(string: "31.02"))
        #expect(chicken.per100g.carbs == 0)
        #expect(chicken.origin == .usda)
        #expect(!chicken.hasIncompleteNutrition)
    }

    @Test("Missing nutrients are flagged, not silently zeroed")
    func incompleteFood() throws {
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: Data(searchJSON.utf8))
        let incomplete = USDAService.mapSearchResponse(response)[1]
        #expect(incomplete.hasIncompleteNutrition)
        #expect(incomplete.missingFields.contains("calories"))
        #expect(incomplete.missingFields.contains("carbs"))
        #expect(!incomplete.missingFields.contains("protein"))
    }

    @Test("Nested nutrient shape (amount + nutrient.number) also maps")
    func nestedNutrientShape() throws {
        let json = """
        { "foods": [ { "fdcId": 5, "description": "Rice, white, cooked",
          "foodNutrients": [
            { "nutrient": { "number": "208", "unitName": "kcal" }, "amount": 130 },
            { "nutrient": { "number": "203", "unitName": "g" }, "amount": 2.7 },
            { "nutrient": { "number": "205", "unitName": "g" }, "amount": 28.2 },
            { "nutrient": { "number": "204", "unitName": "g" }, "amount": 0.3 }
          ] } ] }
        """
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: Data(json.utf8))
        let results = USDAService.mapSearchResponse(response)
        #expect(results.count == 1)
        #expect(results[0].per100g.calories == 130)
        #expect(results[0].per100g.protein == Decimal(string: "2.7"))
        #expect(!results[0].hasIncompleteNutrition)
    }
}

@Suite("Local search ordering")
@MainActor
struct LocalSearchTests {
    @Test("My Foods rank before recent public foods and match by name or brand")
    func ordering() throws {
        let oats = FoodItem(name: "Oats", caloriesPer100g: 380, proteinPer100g: 13, carbsPer100g: 60, fatPer100g: 7)
        let publicOats = FoodItem(
            name: "Oat Flakes", brand: "Kölln",
            caloriesPer100g: 372, proteinPer100g: 13.5, carbsPer100g: 58.7, fatPer100g: 7,
            source: .openFoodFacts
        )
        publicOats.lastLoggedAt = Date()
        let unrelated = FoodItem(name: "Chicken breast", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6)

        // persistentModelID access requires insertion into a context.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FoodItem.self, LogEntry.self, configurations: config)
        let context = container.mainContext
        context.insert(oats)
        context.insert(publicOats)
        context.insert(unrelated)

        let results = FoodSearchService.localMatches(query: "oat", foods: [publicOats, oats, unrelated])
        #expect(results.count == 2)
        #expect(results[0].name == "Oats")
        #expect(results[0].origin.label == "My Food")
        #expect(results[1].name == "Oat Flakes")
        #expect(results[1].origin.label == "Recent")

        let brandResults = FoodSearchService.localMatches(query: "kölln", foods: [publicOats, oats])
        #expect(brandResults.count == 1)
        #expect(brandResults[0].name == "Oat Flakes")

        #expect(FoodSearchService.localMatches(query: "   ", foods: [oats]).isEmpty)
    }
}
