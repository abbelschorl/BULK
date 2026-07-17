/* Orchestrates food search across sources in the required order: personal
   library first, then recent foods, then public databases. Local results are
   always available offline; public failures are reported without hiding
   local results. Ported from Bulk/Services/FoodSearchService.swift. */

import type { FoodItem } from "../models/types";
import { searchOpenFoodFacts } from "./openFoodFacts";
import { MissingAPIKeyError, searchUSDA } from "./usda";
import type { FoodSearchResult, SearchOrigin } from "./searchResult";

export function resultForFood(food: FoodItem, origin: SearchOrigin): FoodSearchResult {
  return {
    id: `local-${food.id}-${origin}`,
    name: food.name,
    brand: food.brand,
    per100g: food.per100g,
    origin,
    barcode: food.barcode,
    defaultServingGrams: food.defaultServingGrams,
    hasIncompleteNutrition: false,
    missingFields: [],
    foodId: food.id,
  };
}

/** Local-library and recent matches, ranked My Foods → Recent. */
export function localMatches(query: string, foods: FoodItem[]): FoodSearchResult[] {
  const trimmed = query.trim().toLowerCase();
  if (!trimmed) return [];

  const matches = foods.filter(
    (food) =>
      food.name.toLowerCase().includes(trimmed) ||
      (food.brand?.toLowerCase().includes(trimmed) ?? false),
  );

  const myFoods = matches
    .filter((f) => f.source === "myFood")
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
  const recents = matches
    .filter((f) => f.source !== "myFood" && f.lastLoggedAt != null)
    .sort((a, b) => (b.lastLoggedAt ?? "").localeCompare(a.lastLoggedAt ?? ""));

  return [
    ...myFoods.map((f) => resultForFood(f, "myFood")),
    ...recents.map((f) => resultForFood(f, "recent")),
  ];
}

/** Queries both public sources in parallel, tolerating individual failures. */
export async function searchPublic(
  query: string,
  usdaAPIKey: string,
): Promise<{ results: FoodSearchResult[]; notes: string[] }> {
  const results: FoodSearchResult[] = [];
  const notes: string[] = [];

  const [usdaOutcome, offOutcome] = await Promise.allSettled([
    searchUSDA(query, usdaAPIKey),
    searchOpenFoodFacts(query),
  ]);

  if (usdaOutcome.status === "fulfilled") {
    results.push(...usdaOutcome.value);
  } else if (usdaOutcome.reason instanceof MissingAPIKeyError) {
    notes.push("USDA search is off — add a free API key in Settings.");
  } else {
    notes.push(String(usdaOutcome.reason?.message ?? usdaOutcome.reason));
  }

  if (offOutcome.status === "fulfilled") {
    results.push(...offOutcome.value);
  } else {
    notes.push(`Open Food Facts: ${offOutcome.reason?.message ?? offOutcome.reason}`);
  }

  return { results, notes };
}
