/* Client for the free Open Food Facts API. No key required. Mapping is
   separated from fetching so it is unit-testable with fixture JSON.
   Ported from Bulk/Services/OpenFoodFactsService.swift. */

import type { FoodSearchResult } from "./searchResult";

const FIELDS = "code,product_name,brands,nutriments,serving_quantity,serving_quantity_unit";

export interface OFFProduct {
  code?: string;
  product_name?: string;
  brands?: string;
  nutriments?: {
    "energy-kcal_100g"?: number;
    energy_100g?: number;
    proteins_100g?: number;
    carbohydrates_100g?: number;
    fat_100g?: number;
  };
  serving_quantity?: number | string;
  serving_quantity_unit?: string;
}

export interface OFFSearchResponse {
  products?: OFFProduct[];
}

export class ServiceError extends Error {}

export function mapOFFProduct(product: OFFProduct): FoodSearchResult | null {
  const name = (product.product_name ?? "").trim();
  if (!name) return null;

  const nutriments = product.nutriments;
  const missing: string[] = [];

  // OFF reports energy per 100 g in kJ under "energy_100g"; kcal is separate.
  let calories = 0;
  if (nutriments?.["energy-kcal_100g"] != null) {
    calories = nutriments["energy-kcal_100g"];
  } else if (nutriments?.energy_100g != null) {
    calories = nutriments.energy_100g / 4.184;
  } else {
    missing.push("calories");
  }

  const protein = nutriments?.proteins_100g;
  const carbs = nutriments?.carbohydrates_100g;
  const fat = nutriments?.fat_100g;
  if (protein == null) missing.push("protein");
  if (carbs == null) missing.push("carbs");
  if (fat == null) missing.push("fat");

  // OFF sometimes returns serving_quantity as a string ("40").
  let serving: number | undefined;
  const rawQuantity = Number(product.serving_quantity);
  if (product.serving_quantity != null && Number.isFinite(rawQuantity) && rawQuantity > 0) {
    const unit = product.serving_quantity_unit?.toLowerCase();
    if (unit == null || unit === "g" || unit === "ml") serving = rawQuantity;
  }

  const brand = product.brands?.split(",")[0]?.trim() || undefined;

  return {
    id: `off-${product.code ?? crypto.randomUUID()}`,
    name,
    brand,
    per100g: {
      calories: Math.round(calories * 10) / 10,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fat: fat ?? 0,
    },
    origin: "openFoodFacts",
    barcode: product.code,
    defaultServingGrams: serving,
    hasIncompleteNutrition: missing.length > 0,
    missingFields: missing,
  };
}

export function mapOFFSearchResponse(response: OFFSearchResponse): FoodSearchResult[] {
  return (response.products ?? [])
    .map(mapOFFProduct)
    .filter((r): r is FoodSearchResult => r !== null);
}

export async function searchOpenFoodFacts(
  query: string,
  pageSize = 20,
): Promise<FoodSearchResult[]> {
  const url = new URL("https://world.openfoodfacts.org/api/v2/search");
  url.searchParams.set("search_terms", query);
  url.searchParams.set("fields", FIELDS);
  url.searchParams.set("page_size", String(pageSize));
  url.searchParams.set("sort_by", "unique_scans_n");

  let response: Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  } catch {
    throw new ServiceError("You appear to be offline. Your foods and recent items still work.");
  }
  if (!response.ok) {
    throw new ServiceError("Open Food Facts returned an unexpected response. Try again in a moment.");
  }
  return mapOFFSearchResponse((await response.json()) as OFFSearchResponse);
}
