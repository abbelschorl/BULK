/* Port of BulkTests/FoodSearchMappingTests.swift. */

import { describe, expect, test } from "vitest";
import { mapOFFProduct, mapOFFSearchResponse } from "../src/services/openFoodFacts";
import { mapUSDASearchResponse } from "../src/services/usda";
import { localMatches } from "../src/services/foodSearch";
import type { FoodItem } from "../src/models/types";

describe("Open Food Facts mapping", () => {
  const product = {
    code: "4000521006112",
    product_name: "Haferflocken Kernig",
    brands: "Kölln, Some Other Brand",
    serving_quantity: "40",
    serving_quantity_unit: "g",
    nutriments: {
      "energy-kcal_100g": 372,
      energy_100g: 1577,
      proteins_100g: 13.5,
      carbohydrates_100g: 58.7,
      fat_100g: 7.0,
    },
  };

  test("maps a complete product with string serving quantity", () => {
    const result = mapOFFProduct(product)!;
    expect(result.name).toBe("Haferflocken Kernig");
    expect(result.brand).toBe("Kölln");
    expect(result.barcode).toBe("4000521006112");
    expect(result.per100g.calories).toBe(372);
    expect(result.per100g.protein).toBe(13.5);
    expect(result.defaultServingGrams).toBe(40);
    expect(result.origin).toBe("openFoodFacts");
    expect(result.hasIncompleteNutrition).toBe(false);
  });

  test("falls back from kJ when kcal is missing and flags missing macros", () => {
    const response = {
      products: [
        { code: "123", product_name: "Mystery Snack", nutriments: { energy_100g: 2092 } },
        { code: "456", product_name: "" },
      ],
    };
    const results = mapOFFSearchResponse(response);
    // Nameless product is dropped entirely.
    expect(results).toHaveLength(1);
    const snack = results[0];
    // 2092 kJ ≈ 500 kcal.
    expect(Math.abs(snack.per100g.calories - 500)).toBeLessThan(0.1);
    expect(snack.hasIncompleteNutrition).toBe(true);
    expect(snack.missingFields).toContain("protein");
    expect(snack.missingFields).toContain("carbs");
    expect(snack.missingFields).toContain("fat");
    expect(snack.missingFields).not.toContain("calories");
  });

  test("numeric serving quantity also maps", () => {
    const result = mapOFFProduct({
      code: "1",
      product_name: "Bar",
      serving_quantity: 45.5,
      nutriments: {
        "energy-kcal_100g": 400,
        proteins_100g: 30,
        carbohydrates_100g: 40,
        fat_100g: 10,
      },
    })!;
    expect(result.defaultServingGrams).toBe(45.5);
  });

  test("non-gram serving units are ignored", () => {
    const result = mapOFFProduct({
      code: "2",
      product_name: "Juice",
      serving_quantity: 1,
      serving_quantity_unit: "portion",
      nutriments: { "energy-kcal_100g": 50, proteins_100g: 0, carbohydrates_100g: 12, fat_100g: 0 },
    })!;
    expect(result.defaultServingGrams).toBeUndefined();
  });
});

describe("USDA mapping", () => {
  const searchResponse = {
    foods: [
      {
        fdcId: 171077,
        description: "Chicken, broilers or fryers, breast, meat only, cooked, roasted",
        foodNutrients: [
          { nutrientNumber: "208", unitName: "KCAL", value: 165.0 },
          { nutrientNumber: "203", unitName: "G", value: 31.02 },
          { nutrientNumber: "205", unitName: "G", value: 0.0 },
          { nutrientNumber: "204", unitName: "G", value: 3.57 },
        ],
      },
      {
        fdcId: 999999,
        description: "Incomplete Food",
        foodNutrients: [{ nutrientNumber: "203", unitName: "G", value: 20.0 }],
      },
      { fdcId: 111, description: "   " },
    ],
  };

  test("maps cooked chicken breast per 100 g", () => {
    const results = mapUSDASearchResponse(searchResponse);
    expect(results).toHaveLength(2); // blank-name food dropped

    const chicken = results[0];
    expect(chicken.name.startsWith("Chicken")).toBe(true);
    expect(chicken.per100g.calories).toBe(165);
    expect(chicken.per100g.protein).toBe(31.02);
    expect(chicken.per100g.carbs).toBe(0);
    expect(chicken.origin).toBe("usda");
    expect(chicken.hasIncompleteNutrition).toBe(false);
  });

  test("missing nutrients are flagged, not silently zeroed", () => {
    const incomplete = mapUSDASearchResponse(searchResponse)[1];
    expect(incomplete.hasIncompleteNutrition).toBe(true);
    expect(incomplete.missingFields).toContain("calories");
    expect(incomplete.missingFields).toContain("carbs");
    expect(incomplete.missingFields).not.toContain("protein");
  });

  test("nested nutrient shape (amount + nutrient.number) also maps", () => {
    const results = mapUSDASearchResponse({
      foods: [
        {
          fdcId: 5,
          description: "Rice, white, cooked",
          foodNutrients: [
            { nutrient: { number: "208", unitName: "kcal" }, amount: 130 },
            { nutrient: { number: "203", unitName: "g" }, amount: 2.7 },
            { nutrient: { number: "205", unitName: "g" }, amount: 28.2 },
            { nutrient: { number: "204", unitName: "g" }, amount: 0.3 },
          ],
        },
      ],
    });
    expect(results).toHaveLength(1);
    expect(results[0].per100g.calories).toBe(130);
    expect(results[0].per100g.protein).toBe(2.7);
    expect(results[0].hasIncompleteNutrition).toBe(false);
  });
});

describe("local search ordering", () => {
  test("My Foods rank before recent public foods and match by name or brand", () => {
    const oats: FoodItem = {
      id: "1",
      name: "Oats",
      per100g: { calories: 380, protein: 13, carbs: 60, fat: 7 },
      isFavorite: false,
      source: "myFood",
      createdAt: new Date().toISOString(),
    };
    const publicOats: FoodItem = {
      id: "2",
      name: "Oat Flakes",
      brand: "Kölln",
      per100g: { calories: 372, protein: 13.5, carbs: 58.7, fat: 7 },
      isFavorite: false,
      source: "openFoodFacts",
      createdAt: new Date().toISOString(),
      lastLoggedAt: new Date().toISOString(),
    };
    const unrelated: FoodItem = {
      id: "3",
      name: "Chicken breast",
      per100g: { calories: 165, protein: 31, carbs: 0, fat: 3.6 },
      isFavorite: false,
      source: "myFood",
      createdAt: new Date().toISOString(),
    };

    const results = localMatches("oat", [publicOats, oats, unrelated]);
    expect(results).toHaveLength(2);
    expect(results[0].name).toBe("Oats");
    expect(results[0].origin).toBe("myFood");
    expect(results[1].name).toBe("Oat Flakes");
    expect(results[1].origin).toBe("recent");

    const brandResults = localMatches("kölln", [publicOats, oats]);
    expect(brandResults).toHaveLength(1);
    expect(brandResults[0].name).toBe("Oat Flakes");

    expect(localMatches("   ", [oats])).toHaveLength(0);
  });
});
