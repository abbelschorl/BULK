/* Client for USDA FoodData Central search — best for raw/cooked ingredients.
   Requires the user's own free API key, stored only in this browser.
   Ported from Bulk/Services/USDAService.swift. */

import type { FoodSearchResult } from "./searchResult";
import { ServiceError } from "./openFoodFacts";

export class MissingAPIKeyError extends ServiceError {}

export interface USDAFoodNutrient {
  nutrientNumber?: string;
  unitName?: string;
  value?: number;
  amount?: number;
  nutrient?: { number?: string; unitName?: string };
}

export interface USDAFood {
  fdcId?: number;
  description?: string;
  brandOwner?: string;
  foodNutrients?: USDAFoodNutrient[];
}

export interface USDASearchResponse {
  foods?: USDAFood[];
}

const round = (v: number, places: number) => {
  const f = 10 ** places;
  return Math.round(v * f) / f;
};

export function mapUSDAFood(food: USDAFood): FoodSearchResult | null {
  const name = (food.description ?? "").trim();
  if (!name || food.fdcId == null) return null;

  // Foundation / SR Legacy nutrient values are per 100 g.
  const nutrient = (numbers: string[], unit?: string): number | undefined => {
    const match = food.foodNutrients?.find((item) => {
      const number = item.nutrientNumber ?? item.nutrient?.number;
      if (!number || !numbers.includes(number)) return false;
      const itemUnit = item.unitName ?? item.nutrient?.unitName;
      if (unit && itemUnit) return itemUnit.toLowerCase() === unit.toLowerCase();
      return true;
    });
    return match?.value ?? match?.amount;
  };

  const missing: string[] = [];
  // 208 = Energy (kcal); 957 = Atwater specific energy used by Foundation foods.
  const calories = nutrient(["208", "957", "1008", "2047", "2048"], "kcal");
  const protein = nutrient(["203", "1003"]);
  const carbs = nutrient(["205", "1005"]);
  const fat = nutrient(["204", "1004"]);
  if (calories == null) missing.push("calories");
  if (protein == null) missing.push("protein");
  if (carbs == null) missing.push("carbs");
  if (fat == null) missing.push("fat");

  return {
    id: `usda-${food.fdcId}`,
    name,
    brand: food.brandOwner,
    per100g: {
      calories: round(calories ?? 0, 1),
      protein: round(protein ?? 0, 2),
      carbs: round(carbs ?? 0, 2),
      fat: round(fat ?? 0, 2),
    },
    origin: "usda",
    hasIncompleteNutrition: missing.length > 0,
    missingFields: missing,
  };
}

export function mapUSDASearchResponse(response: USDASearchResponse): FoodSearchResult[] {
  return (response.foods ?? [])
    .map(mapUSDAFood)
    .filter((r): r is FoodSearchResult => r !== null);
}

export async function searchUSDA(
  query: string,
  apiKey: string,
  pageSize = 15,
): Promise<FoodSearchResult[]> {
  const key = apiKey.trim();
  if (!key) {
    throw new MissingAPIKeyError(
      "Add your free USDA FoodData Central API key in Settings to search ingredients.",
    );
  }

  const url = new URL("https://api.nal.usda.gov/fdc/v1/foods/search");
  url.searchParams.set("api_key", key);
  url.searchParams.set("query", query);
  url.searchParams.set("dataType", "Foundation,SR Legacy");
  url.searchParams.set("pageSize", String(pageSize));

  let response: Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  } catch {
    throw new ServiceError("You appear to be offline. Your foods and recent items still work.");
  }
  if (response.status === 401 || response.status === 403) {
    throw new ServiceError("USDA rejected the API key. Check it in Settings.");
  }
  if (!response.ok) {
    throw new ServiceError("USDA returned an unexpected response. Try again in a moment.");
  }
  return mapUSDASearchResponse((await response.json()) as USDASearchResponse);
}
