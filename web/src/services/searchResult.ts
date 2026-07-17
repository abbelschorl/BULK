/* Normalized food search result from any source, always per 100 g. Rows with
   unusable nutrition data are flagged so the UI can show "incomplete data"
   before the user logs anything. Ported from Bulk/Services/FoodSearchResult. */

import type { NutritionValues } from "../models/types";

export type SearchOrigin = "myFood" | "recent" | "openFoodFacts" | "usda";

export const ORIGIN_LABELS: Record<SearchOrigin, string> = {
  myFood: "My Food",
  recent: "Recent",
  openFoodFacts: "Open Food Facts",
  usda: "USDA",
};

export interface FoodSearchResult {
  id: string;
  name: string;
  brand?: string;
  per100g: NutritionValues;
  origin: SearchOrigin;
  barcode?: string;
  defaultServingGrams?: number;
  hasIncompleteNutrition: boolean;
  missingFields: string[];
  /** Set for local results, to update lastLoggedAt after logging. */
  foodId?: string;
}
